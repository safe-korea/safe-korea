import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

class LocationService {
  Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        '기기의 위치 서비스가 꺼져 있습니다. 위치 없이 목록과 행동강령을 이용할 수 있어요.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('위치 권한이 차단되어 있습니다. 원하면 기기 설정에서 허용해 주세요.');
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationFailure('위치 권한 없이도 시설 검색과 행동강령을 이용할 수 있어요.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              // Use Android's location manager without prompting to enable
              // Google's device-wide network accuracy/crowdsourcing setting.
              forceLocationManager: true,
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
    );
  }
}
