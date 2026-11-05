import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../models/shelter.dart';
import 'shelter_api_client.dart';

const mapCellsPerDegree = 20;
const mapSource = '© OpenStreetMap contributors · Geofabrik';
const mapLicense = 'ODbL 1.0';
const mapSourceDate = '2026-11-01';

/// Public map cells covering [bounds] (west, south, east, north).
List<(int, int)> mapCellsFor(List<double> bounds) => [
  for (
    var x = (bounds[0] * mapCellsPerDegree).floor();
    x <= (bounds[2] * mapCellsPerDegree).floor();
    x++
  )
    for (
      var y = (bounds[1] * mapCellsPerDegree).floor();
      y <= (bounds[3] * mapCellsPerDegree).floor();
      y++
    )
      (x, y),
];

/// Downloads public road cells and keeps features that touch [bounds].
/// Only cell numbers are requested: no device coordinates are sent.
Future<List<Map<String, dynamic>>> fetchMapFeatures(
  List<double> bounds, {
  required String baseUrl,
  http.Client? client,
  List<(int, int)>? cells,
  void Function(int done, int total)? progress,
}) async {
  if (baseUrl.isEmpty && !kIsWeb) throw StateError('지도 서버 설정 없음');
  cells ??= mapCellsFor(bounds);
  final features = <String, Map<String, dynamic>>{};
  final http_ = client ?? http.Client();
  try {
    for (final (i, (x, y)) in cells.indexed) {
      final response = await http_
          .get(
            kIsWeb
                ? Uri.base.resolve('../offline-packs/$x-$y.json')
                : Uri.parse('$baseUrl/offline-packs/$x-$y.json'),
          )
          .timeout(const Duration(seconds: 15));
      // Sea or border cells without roads are not published.
      if (response.statusCode == 404) {
        progress?.call(i + 1, cells.length);
        continue;
      }
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('지도 다운로드 실패');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['schemaVersion'] != 1 || data['license'] != mapLicense) {
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
          features[f['id'] as String] = Map<String, dynamic>.from(f as Map);
        }
      }
      progress?.call(i + 1, cells.length);
    }
  } finally {
    if (client == null) http_.close();
  }
  if (features.isEmpty) throw const FormatException('주변 도로 자료 없음');
  return features.values.toList();
}

Map<String, dynamic> mapRecord(
  List<double> bounds,
  List<Map<String, dynamic>> features,
) => {
  'schemaVersion': 1,
  'bounds': bounds,
  'features': features,
  'license': mapLicense,
  'preparedAt': DateTime.now().toUtc().toIso8601String(),
  'source': mapSource,
  'sourceDate': mapSourceDate,
};

/// Requests only public map cells around the explicitly saved facility.
class SavedMapDownloader {
  SavedMapDownloader({this.baseUrl = shelterApiBaseUrl});
  final String baseUrl;
  Future<Map<String, dynamic>> fetch(Shelter shelter) async {
    if (baseUrl.isEmpty) throw StateError('지도 서버 설정 없음');
    final lon = shelter.longitude, lat = shelter.latitude;
    final bounds = [lon - .008, lat - .007, lon + .008, lat + .007];
    return mapRecord(bounds, await fetchMapFeatures(bounds, baseUrl: baseUrl));
  }
}
