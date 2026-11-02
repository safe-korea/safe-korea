import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../models/shelter.dart';
import 'shelter_api_client.dart';

/// Requests only public map cells around the explicitly saved facility.
class SavedMapDownloader {
  SavedMapDownloader({this.baseUrl = shelterApiBaseUrl});
  final String baseUrl;
  Future<Map<String, dynamic>> fetch(Shelter shelter) async {
    if (baseUrl.isEmpty) throw StateError('지도 서버 설정 없음');
    final lon = shelter.longitude, lat = shelter.latitude;
    final bounds = [lon - .008, lat - .007, lon + .008, lat + .007];
    final features = <String, dynamic>{};
    final client = http.Client();
    try {
      for (
        var x = (bounds[0] * 20).floor();
        x <= (bounds[2] * 20).floor();
        x++
      ) {
        for (
          var y = (bounds[1] * 20).floor();
          y <= (bounds[3] * 20).floor();
          y++
        ) {
          final response = await client
              .get(
                kIsWeb
                    ? Uri.base.resolve('../offline-packs/$x-$y.json')
                    : Uri.parse('$baseUrl/offline-packs/$x-$y.json'),
              )
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200 ||
              response.bodyBytes.length > 8000000) {
            throw const FormatException('지도 다운로드 실패');
          }
          final data = jsonDecode(
            utf8.decode(response.bodyBytes),
          ) as Map<String, dynamic>;
          if (data['schemaVersion'] != 1 || data['license'] != 'ODbL 1.0') {
            throw const FormatException('지도 출처 오류');
          }
          for (final f in data['features'] as List) {
            final points = f['points'] as List;
            if (points.any(
              (p) =>
                  p[0] >= bounds[0] &&
                  p[0] <= bounds[2] &&
                  p[1] >= bounds[1] &&
                  p[1] <= bounds[3],
            )) {
              features[f['id'] as String] = f;
            }
          }
        }
      }
      if (features.isEmpty) throw const FormatException('주변 도로 자료 없음');
      return {
        'schemaVersion': 1,
        'bounds': bounds,
        'features': features.values.toList(),
        'license': 'ODbL 1.0',
        'preparedAt': DateTime.now().toUtc().toIso8601String(),
        'source': '© OpenStreetMap contributors · Geofabrik',
        'sourceDate': '2026-11-01',
      };
    } finally {
      client.close();
    }
  }
}
