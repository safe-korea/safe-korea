import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_korea/services/shelter_repository.dart';
import 'package:safe_korea/models/shelter.dart';

Map<String, dynamic> entry(String id) => {
  'facilCode': id,
  'facilNm': '테스트 시설',
  'facilRdAddr': '테스트 주소',
  'facilLade': 37,
  'facilLami': 30,
  'facilLase': 0,
  'facilLode': 127,
  'facilLomi': 0,
  'facilLose': 0,
};
Map<String, dynamic> response(List<Map<String, dynamic>> rows) => {
  'facilitiesVO': {
    'tableNm': 'TFK_CIVIL_EMR_FACL_TEMP',
    'tableKorNm': '민방위대피소',
    'gubun': '2',
    'sggCd': '11110',
  },
  'totalCnt': rows.length,
  'mapList': rows,
  'list': [],
};
ShelterCatalog parse(Map<String, dynamic> data) => ShelterRepository.parse(
  data,
  code: '11110',
  regionName: '테스트 지역',
  retrievedAt: DateTime.utc(2026, 10, 31),
);
void main() {
  test(
    'DMS uses entrance coordinates and does not invent a source update date',
    () {
      final data = parse(
        response([
          {
            ...entry('a'),
            'aot': '테스트 출입구',
            'aotLade': 37,
            'aotLami': 31,
            'aotLase': 30,
            'aotLode': 127,
            'aotLomi': 1,
            'aotLose': 0,
          },
        ]),
      );
      expect(data.shelters.single.latitude, closeTo(37.525, 0.000001));
      expect(data.shelters.single.address, '테스트 출입구');
      expect(data.shelters.single.updatedAt, isNull);
      expect(data.sourceUrl, officialMapSource);
      expect(ShelterCatalog.fromJson(data.toJson()).shelters.single.id, 'a');
    },
  );
  test('invalid or duplicate coordinates excluded with visible counts', () {
    final data = parse(
      response([
        entry('a'),
        {...entry('b'), 'facilLase': 90},
        entry('a'),
      ]),
    );
    expect(data.shelters.length, 1);
    expect(data.skippedCount, 2);
    expect(data.officialCount, 3);
  });
  test('conflicting records with the same regional ID are rejected rather than replacing a saved facility', () {
    expect(
      () => parse(
        response([
          entry('a'),
          {...entry('a'), 'facilNm': '다른 테스트 시설'},
        ]),
      ),
      throwsA(isA<ConflictingShelterIdentity>()),
    );
  });
  test('unrelated facility type, wrong region, incomplete map and all invalid fail closed', () {
    final normal = response([entry('a')]);
    for (final data in [
      {
        ...normal,
        'facilitiesVO': {...normal['facilitiesVO'], 'gubun': '1'},
      },
      {
        ...normal,
        'facilitiesVO': {...normal['facilitiesVO'], 'sggCd': '26110'},
      },
      {...normal, 'totalCnt': 5},
      response([
        {...entry('a'), 'facilLade': 0},
      ]),
    ]) {
      expect(() => parse(data), throwsFormatException);
    }
    expect(parse(response([])).shelters, isEmpty);
  });
  test('query sends only a region and fixed civil defense parameters, HTTP errors fail', () async {
    final repository = ShelterRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        final body = Uri.splitQueryString(request.body);
        expect(body, {
          'tableNm': 'TFK_CIVIL_EMR_FACL_TEMP',
          'tableKorNm': '민방위대피소',
          'sggCd': '11110',
          'page': '1',
          'size': '5',
        });
        return http.Response(
          jsonEncode(response([entry('a')])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    expect((await repository.fetch('11110', '테스트')).shelters.length, 1);
    repository.close();
    final unavailable = ShelterRepository(
      client: MockClient((_) async => http.Response('maintenance', 503)),
    );
    await expectLater(unavailable.fetch('11110', '테스트'), throwsFormatException);
    unavailable.close();
  });
}
