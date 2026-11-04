import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'region_suggestion_service.dart';

/// Bundled geometry only: no coordinates leave the device. Ambiguous/changed
/// districts require manual selection, never nearest-centroid guessing.
class LocalRegionService extends RegionSuggestionService {
  static Future<List<dynamic>>? _features;
  static Future<List<dynamic>> _load() => _features ??= rootBundle
      .loadString('assets/region_boundaries.json')
      .then((raw) => (jsonDecode(raw) as Map)['features'] as List);

  /// Bounding box (west, south, east, north) of a district from bundled data.
  static Future<List<double>?> boundsOf(String code) async {
    for (final f in await _load()) {
      if (f['code'] == code) {
        return (f['bounds'] as List).map((v) => (v as num).toDouble()).toList();
      }
    }
    return null;
  }

  @override
  Future<RegionSuggestion?> suggest(
    Position position,
    List<Map<String, dynamic>> provinces,
  ) async {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 1000 ||
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(minutes: 2)) {
      throw const LocationFailure('위치가 오래되었거나 오차가 커요. 다시 확인하거나 지역을 선택하세요.');
    }
    final allowed = <String, RegionSuggestion>{};
    final names = <String, String>{};
    for (final p in provinces) {
      for (final d in p['districts'] as List) {
        final code = d['code'] as String;
        allowed[code] = RegionSuggestion(
          p['code'] as String,
          code,
          '${p['name']} ${d['name']}',
        );
        names[code] = d['name'] as String;
      }
    }
    final data = await _load();
    String? codeAt(double x, double y) {
      final hits = <String>{};
      for (final f in data) {
        final b = f['bounds'] as List;
        if (x < b[0] || y < b[1] || x > b[2] || y > b[3]) continue;
        for (final poly in f['polygons'] as List) {
          if (_inside(x, y, poly[0] as List) &&
              !(poly as List)
                  .skip(1)
                  .any((hole) => _inside(x, y, hole as List))) {
            // Retain unknown hits too: never assign a nearby known district.
            hits.add(f['code'] as String);
          }
        }
      }
      if (hits.length != 1) return null;
      final code = hits.single;
      final feature = data.firstWhere((f) => f['code'] == code);
      return names[code] == feature['name'] ? code : null;
    }

    final lat = position.latitude, lon = position.longitude;
    final code = codeAt(lon, lat);
    if (code == null) return null;
    // Account for the GPS uncertainty and the source's simplified boundary.
    final radius = position.accuracy + 100;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final y = lat + radius * math.sin(angle) / 111320;
      final x =
          lon +
          radius * math.cos(angle) / (111320 * math.cos(lat * math.pi / 180));
      if (codeAt(x, y) != code) return null;
    }
    return allowed[code];
  }

  static bool _inside(double x, double y, List ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i] as List, b = ring[j] as List;
      if ((a[1] > y) != (b[1] > y) &&
          x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) {
        inside = !inside;
      }
    }
    return inside;
  }
}
