import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class RegionSuggestion {
  const RegionSuggestion(this.provinceCode, this.districtCode, this.label);
  final String provinceCode, label;
  final String? districtCode;
}

class RegionSuggestionService {
  RegionSuggestionService({this.lookup});
  final Future<List<Placemark>> Function(double, double)? lookup;

  /// Call only after a separate, explicit user action disclosing OS geocoding.
  Future<RegionSuggestion?> suggest(
    Position position,
    List<Map<String, dynamic>> provinces,
  ) async {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 1000 ||
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(minutes: 2)) {
      throw const LocationFailure('위치가 오래되었거나 오차가 큽니다. 지역을 직접 선택해 주세요.');
    }
    final places =
        await (lookup != null
                ? lookup!(position.latitude, position.longitude)
                : Geocoding(locale: const Locale('ko', 'KR'))
                      .placemarkFromCoordinates(
                        position.latitude,
                        position.longitude,
                      ))
            .timeout(const Duration(seconds: 15));
    return match(places, provinces);
  }

  /// Apply a district only when province AND full district names are unambiguous.
  /// Province-only results require manual district selection.
  /// Never guess a province from repeated district names such as 중구.
  static RegionSuggestion? match(
    List<Placemark> places,
    List<Map<String, dynamic>> provinces,
  ) {
    final matches = <String, RegionSuggestion>{};
    final provinceMatches = <String, RegionSuggestion>{};
    for (final place in places) {
      if (place.isoCountryCode?.toUpperCase() != 'KR') continue;
      final fields = [
        place.administrativeArea,
        place.subAdministrativeArea,
        place.locality,
        place.subLocality,
      ].whereType<String>().map((s) => s.trim()).toSet();
      final words = fields.expand((s) => s.split(RegExp(r'\s+'))).toSet();
      final candidates = provinces
          .where((p) => fields.contains(p['name']) || words.contains(p['name']))
          .toList();
      if (candidates.length != 1) continue;
      final province = candidates.single;
      provinceMatches[province['code'] as String] = RegionSuggestion(
        province['code'] as String,
        null,
        province['name'] as String,
      );
      for (final raw in province['districts'] as List) {
        final district = Map<String, dynamic>.from(raw as Map);
        final name = district['name'] as String;
        if (fields.contains(name) ||
            name.split(RegExp(r'\s+')).every(words.contains)) {
          final code = district['code'] as String;
          matches[code] = RegionSuggestion(
            province['code'] as String,
            code,
            '${province['name']} $name',
          );
        }
      }
    }
    if (provinceMatches.length != 1 || matches.length > 1) return null;
    return matches.isNotEmpty
        ? matches.values.single
        : provinceMatches.values.single;
  }
}
