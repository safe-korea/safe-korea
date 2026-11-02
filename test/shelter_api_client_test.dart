import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/services/shelter_api_client.dart';
import 'package:safe_korea/services/shelter_repository.dart';

Map<String, dynamic> payload() => {
  'apiVersion': 1,
  'delivery': {'state': 'hit', 'stale': false, 'ageSeconds': 1},
  'catalog': {
    'schemaVersion': 1,
    'sourceName': '공식 출처 테스트',
    'sourceUrl': officialMapSource,
    'retrievedAt': '2026-11-01T00:00:00Z',
    'coverage': '테스트 지역',
    'areaCode': '11140',
    'officialCount': 0,
    'skippedCount': 0,
    'status': 'verified',
    'items': <dynamic>[],
  },
};
void main() {
  test('region-only request and stale metadata survive native storage serialization', () async {
    final data = payload();
    data['delivery'] = {'state': 'stale', 'stale': true, 'ageSeconds': 1000};
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://api.example.org/api/shelters?region=11140',
      );
      expect(request.body, isEmpty);
      expect(request.headers.containsKey('authorization'), false);
      return http.Response(
        jsonEncode(data),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final catalog = await ShelterRepository(
      client: client,
      apiBaseUrl: 'https://api.example.org',
    ).fetch('11140', '중구');
    expect(catalog.deliveryStatus, 'stale');
    expect(ShelterCatalog.fromJson(catalog.toJson()).deliveryStatus, 'stale');
    expect(catalog.retrievedAt, '2026-11-01T00:00:00Z');
  });
  test(
    'configured API failures never silently fall back to government',
    () async {
      var calls = 0;
      final repository = ShelterRepository(
        apiBaseUrl: 'https://api.example.org',
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'api.example.org');
          return http.Response('', 502);
        }),
      );
      await expectLater(
        repository.fetch('11140', '중구'),
        throwsA(isA<ShelterApiException>()),
      );
      expect(calls, 1);
    },
  );
  for (final mutation in [
    'version',
    'region',
    'source',
    'count',
    'age',
    'state',
    'stale',
  ]) {
    test('rejects invalid $mutation metadata', () async {
      final data = payload();
      switch (mutation) {
        case 'version':
          data['apiVersion'] = 2;
        case 'region':
          data['catalog']['areaCode'] = '11110';
        case 'source':
          data['catalog']['sourceUrl'] = 'https://example.org';
        case 'count':
          data['catalog']['officialCount'] = 1;
        case 'age':
          data['delivery']['ageSeconds'] = 900;
        case 'state':
          data['delivery']['state'] = 'unknown';
        case 'stale':
          data['delivery']['stale'] = true;
      }
      final api = ShelterApiClient(
        baseUrl: 'https://api.example.org',
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
      );
      await expectLater(
        api.fetch('11140'),
        throwsA(isA<ShelterApiException>()),
      );
    });
  }
  test(
    'rejects insecure or credential-bearing configuration before any request',
    () async {
      for (final base in [
        'http://api.example.org',
        'https://secret@api.example.org',
        'https://api.example.org?token=secret',
        'https://api.example.org/path',
      ]) {
        final api = ShelterApiClient(
          baseUrl: base,
          client: MockClient((_) async => throw StateError('must not request')),
        );
        await expectLater(
          api.fetch('11140'),
          throwsA(isA<ShelterApiException>()),
        );
      }
    },
  );
  test('rate limit and network failures have recoverable messages', () async {
    final api = ShelterApiClient(
      baseUrl: 'http://127.0.0.1:8787',
      client: MockClient((_) async => http.Response('', 429)),
    );
    await expectLater(
      api.fetch('11140'),
      throwsA(
        isA<ShelterApiException>().having(
          (e) => e.message,
          'retry hint',
          contains('1분'),
        ),
      ),
    );
    final offline = ShelterApiClient(
      baseUrl: 'https://api.example.org',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.fetch('11140'),
      throwsA(
        isA<ShelterApiException>().having(
          (e) => e.message,
          'offline hint',
          contains('인터넷'),
        ),
      ),
    );
  });
}
