import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_korea/services/local_region_service.dart';
import 'package:safe_korea/services/location_service.dart';

Position point(double lat, double lon, {double accuracy = 5}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'local region resolves Jamsil and Jongno without external geocoding',
    () async {
      final data = jsonDecode(
        await rootBundle.loadString('assets/regions.json'),
      );
      final provinces = (data['provinces'] as List)
          .cast<Map<String, dynamic>>();
      final service = LocalRegionService();
      expect(
        (await service.suggest(
          point(37.5133, 127.1001),
          provinces,
        ))?.districtCode,
        '11710',
      );
      expect(
        (await service.suggest(point(37.58, 126.98), provinces))?.districtCode,
        '11110',
      );
      expect(
        (await service.suggest(
          point(37.378, 127.115),
          provinces,
        ))?.districtCode,
        '41135',
      );
      expect(await service.suggest(point(0, 0), provinces), isNull);
      // This point's uncertainty circle crosses the Jongno/Jung boundary.
      expect(await service.suggest(point(37.57, 126.98), provinces), isNull);
      expect(await service.suggest(point(37.5133, 127.1001), []), isNull);
      await expectLater(
        service.suggest(point(37.5133, 127.1001, accuracy: 1200), provinces),
        throwsA(isA<LocationFailure>()),
      );
    },
  );
}
