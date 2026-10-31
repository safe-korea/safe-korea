import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_korea/services/location_service.dart';

class FakeGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission answer = LocationPermission.denied;
  int requests = 0, fixes = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return answer;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    expect(locationSettings!.timeLimit, const Duration(seconds: 15));
    return Position(
      latitude: 37.5,
      longitude: 127,
      timestamp: DateTime.now(),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late GeolocatorPlatform previous;
  late FakeGeolocator platform;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = FakeGeolocator();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = previous);
  test('disabled service never requests permission or reads GPS', () async {
    platform.enabled = false;
    await expectLater(
      LocationService().current(),
      throwsA(isA<LocationFailure>()),
    );
    expect(platform.requests, 0);
    expect(platform.fixes, 0);
  });
  test('denied and permanently denied permission never reads GPS', () async {
    await expectLater(
      LocationService().current(),
      throwsA(isA<LocationFailure>()),
    );
    expect(platform.requests, 1);
    expect(platform.fixes, 0);
    platform.permission = LocationPermission.deniedForever;
    await expectLater(
      LocationService().current(),
      throwsA(isA<LocationFailure>()),
    );
    expect(platform.requests, 1);
    expect(platform.fixes, 0);
  });
  test('explicit grant returns a one-time fix with timeout', () async {
    platform.answer = LocationPermission.whileInUse;
    expect((await LocationService().current()).latitude, 37.5);
    expect(platform.requests, 1);
    expect(platform.fixes, 1);
  });
}
