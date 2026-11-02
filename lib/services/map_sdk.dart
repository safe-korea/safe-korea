import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// Both map flows share initialization; a failed attempt can be retried.
Future<void>? _initialization;
Future<void> initializeMapSdk(String key) => _initialization ??= KakaoMapSdk
    .instance
    .initialize(key)
    .timeout(const Duration(seconds: 15))
    .catchError((Object error) {
      _initialization = null;
      throw error;
    });
