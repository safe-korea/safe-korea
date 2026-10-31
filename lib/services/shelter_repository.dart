import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shelter.dart';
import 'local_store.dart';

/// Read-only adapter for the official website's public, undocumented list call.
/// No website API keys, authentication, proxy endpoints or GPS are used.
class ShelterRepository {
  ShelterRepository({http.Client? client, LocalStore? store})
    : _client = client ?? http.Client(),
      _store = store ?? LocalStore();
  final http.Client _client;
  final LocalStore _store;
  void close() => _client.close();

  Future<ShelterCatalog?> cached() async {
    final json = await _store.loadShelterCatalog();
    return json == null ? null : ShelterCatalog.fromJson(json);
  }

  Future<void> save(ShelterCatalog catalog) =>
      _store.saveShelterCatalog(catalog.toJson());

  Future<ShelterCatalog> fetch(String code, String regionName) async {
    if (!RegExp(r'^\d{5}$').hasMatch(code) || regionName.trim().isEmpty) {
      throw const FormatException('지역 코드를 확인해 주세요.');
    }
    final response = await _client
        .post(
          Uri.parse(
            'https://www.safekorea.go.kr/safekorea-kor/flsm/flsm/facilityDataList.do',
          ),
          body: {
            'tableNm': 'TFK_CIVIL_EMR_FACL_TEMP',
            'tableKorNm': '민방위대피소',
            'sggCd': code,
            'page': '1',
            'size': '5',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 10000000) {
      throw const FormatException('정부 시설 조회가 응답하지 않습니다.');
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return parse(
      payload,
      code: code,
      regionName: regionName,
      retrievedAt: DateTime.now().toUtc(),
    );
  }

  static double _dms(Map<String, dynamic> row, String prefix, String axis) {
    double number(String suffix) {
      final value = row['$prefix$axis$suffix'];
      if (value == null || value.toString().trim().isEmpty) {
        throw const FormatException('좌표 누락');
      }
      final n = double.parse(value.toString());
      if (!n.isFinite) throw const FormatException('좌표 오류');
      return n;
    }

    final degrees = number('de'),
        minutes = number('mi'),
        seconds = number('se');
    if (degrees != degrees.truncateToDouble() ||
        minutes < 0 ||
        minutes >= 60 ||
        seconds < 0 ||
        seconds >= 60) {
      throw const FormatException('도분초 좌표 오류');
    }
    return degrees + minutes / 60 + seconds / 3600;
  }

  static ShelterCatalog parse(
    Map<String, dynamic> payload, {
    required String code,
    required String regionName,
    required DateTime retrievedAt,
  }) {
    final meta = Map<String, dynamic>.from(payload['facilitiesVO'] as Map);
    if (meta['tableNm'] != 'TFK_CIVIL_EMR_FACL_TEMP' ||
        meta['tableKorNm'] != '민방위대피소' ||
        meta['gubun'] != '2' ||
        meta['sggCd'] != code) {
      throw const FormatException('요청한 민방위 시설 자료가 아닙니다.');
    }
    final rows = payload['mapList'] as List;
    final total = payload['totalCnt'] as int;
    // `list` contains only five paginated rows. `mapList` must contain all rows.
    if (total < 0 || total != rows.length) {
      throw const FormatException('지역 전체 시설 자료를 받지 못했습니다.');
    }
    final items = <Map<String, dynamic>>[];
    final ids = <String>{};
    var skipped = 0;
    for (final raw in rows) {
      try {
        final row = Map<String, dynamic>.from(raw as Map);
        final entrance =
            row['aot'] is String &&
            (row['aot'] as String).trim().isNotEmpty &&
            row['aot'] != '-';
        // Match the official map: use entrance coordinates when an entrance address exists.
        final prefix = entrance ? 'aot' : 'facil';
        final record = <String, dynamic>{
          'id': row['facilCode'], 'name': row['facilNm'],
          'address': entrance
              ? row['aot']
              : (row['facilRdAddr'] ?? row['facilAddr']),
          'latitude': _dms(row, prefix, 'La'),
          'longitude': _dms(row, prefix, 'Lo'),
          // The map payload does not provide a source update date. Never invent one.
          'updatedAt': null, 'status': 'official_listing',
        };
        final shelter = Shelter.fromJson(record);
        if (!ids.add(shelter.id)) throw const FormatException('중복 ID');
        items.add(record);
      } catch (_) {
        skipped++;
      }
    }
    if (total > 0 && items.isEmpty) {
      throw const FormatException('표시할 수 있는 유효한 시설 좌표가 없습니다.');
    }
    return ShelterCatalog.fromJson({
      'schemaVersion': 1,
      'sourceName': '행정안전부 국민안전24 · 민방위 대피소',
      'sourceUrl': officialMapSource,
      'retrievedAt': retrievedAt.toIso8601String(),
      'coverage': regionName,
      'areaCode': code,
      'officialCount': total,
      'skippedCount': skipped,
      'status': 'verified',
      'items': items,
    });
  }
}
