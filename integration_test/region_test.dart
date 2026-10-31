import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/services/region_suggestion_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native geocoder resolves Seoul and does not guess a missing district',
    (tester) async {
      // Public synthetic test coordinate, never the user's GPS position.
      final position = Position(
        latitude: 37.581,
        longitude: 126.984,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      final json =
          jsonDecode(await rootBundle.loadString('assets/regions.json')) as Map;
      final provinces = (json['provinces'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final service = RegionSuggestionService(
        lookup: (lat, lon) async {
          final places = await Geocoding(locale: const Locale('ko', 'KR'))
              .placemarkFromCoordinates(lat, lon);
          debugPrint('PUBLIC_FIXTURE_REGION_COUNT: ${places.length}');
          for (final p in places) {
            debugPrint(
              'PUBLIC_FIXTURE_REGION: ${p.isoCountryCode}|${p.administrativeArea}|${p.subAdministrativeArea}|${p.locality}|${p.subLocality}|street=${p.street}|name=${p.name}|road=${p.thoroughfare}',
            );
          }
          return places;
        },
      );
      final result = await service.suggest(position, provinces);
      expect(result, isNotNull);
      expect(result!.districtCode, anyOf(isNull, '11110'));
      debugPrint(
        'REGION_RESULT: ${result.provinceCode}/${result.districtCode ?? 'manual district required'}',
      );
      expect(result.provinceCode, '11');
    },
  );
}
