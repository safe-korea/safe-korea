import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'civil_alert_ingress.dart';

import '../models/alert_guidance.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local, manually triggered drills only. No government alert receiver.
class DrillNotifications {
  DrillNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    CivilAlertIngress? responseIngress,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _responseIngress = responseIngress ?? CivilAlertIngress.shared;
  static final instance = DrillNotifications();
  static const payload = 'safe_korea:drill:v1';
  static const notificationId = 7001;
  final FlutterLocalNotificationsPlugin _plugin;
  final CivilAlertIngress _responseIngress;
  static const _responsePrefix = 'safe_korea:response_test:v1:';
  Future<void>? _initialization;
  VoidCallback? onOpenDrill;
  bool _pendingOpen = false;
  AlertKind openedKind = AlertKind.air;
  static String payloadFor(AlertKind kind) =>
      kind == AlertKind.air ? payload : 'safe_korea:drill:v2:${kind.name}';

  void handlePayload(String? value) {
    if (value?.startsWith(_responsePrefix) == true) {
      final parts = value!.substring(_responsePrefix.length).split(':');
      if (parts.length != 2) return;
      final kind = AlertKind.fromName(parts[0]);
      final timestamp = int.tryParse(parts[1]);
      if (kind == null ||
          timestamp == null ||
          timestamp < 0 ||
          timestamp > 8640000000000000) {
        return;
      }
      final issued = DateTime.fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      );
      _responseIngress.acceptResponseTest(
        id: value,
        kind: kind,
        issuedAt: issued,
        expiresAt: issued.add(const Duration(minutes: 2)),
      );
      return;
    }
    final kind = value == payload
        ? AlertKind.air
        : value?.startsWith('safe_korea:drill:v2:') == true
        ? AlertKind.fromName(value!.substring('safe_korea:drill:v2:'.length))
        : null;
    if (kind == null) return;
    openedKind = kind;
    if (onOpenDrill case final callback?) {
      callback();
    } else {
      _pendingOpen = true;
    }
  }

  void attach(VoidCallback callback) {
    onOpenDrill = callback;
    if (_pendingOpen) {
      _pendingOpen = false;
      callback();
    }
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            handlePayload(response.payload),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        handlePayload(launch?.notificationResponse?.payload);
      }
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<bool> send({
    required bool sound,
    required bool vibration,
    AlertKind kind = AlertKind.air,
    bool responseTest = false,
    Duration responseDelay = const Duration(seconds: 5),
  }) async {
    await initialize();
    bool granted = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: sound) ??
          false;
    }
    if (!granted) return false;
    // A short in-process test delay lets the user put the app in the background.
    // This is not a persistent alarm and is not guaranteed after process termination.
    if (responseTest) await Future<void>.delayed(responseDelay);
    final responsePayload =
        '$_responsePrefix${kind.name}:${DateTime.now().millisecondsSinceEpoch}';
    await _plugin.show(
      id: notificationId,
      title: '[훈련 / 테스트] ${kind.label}',
      body: responseTest
          ? '실제 경보가 아닙니다. 눌러서 빨간 대피 안내 화면을 확인하세요.'
          : '실제 경보가 아닙니다. 눌러서 경보 대응을 연습하세요.',
      payload: responseTest ? responsePayload : payloadFor(kind),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'drill_signal_v3_${kind.name}_s${sound ? 1 : 0}_v${vibration ? 1 : 0}',
          '${kind.label} 연습 · 소리 ${sound ? "켜짐" : "꺼짐"} · 진동 ${vibration ? "켜짐" : "꺼짐"}',
          channelDescription: '사용자가 직접 실행하는 모의 알림',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          sound: sound
              ? RawResourceAndroidNotificationSound(kind.soundAsset)
              : null,
          enableVibration: vibration,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: sound,
          sound: sound ? '${kind.soundAsset}.wav' : null,
          presentBadge: false,
        ),
      ),
    );
    if (responseTest &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      handlePayload(responsePayload);
    }
    return true;
  }

  Future<void> cancel() async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }
}
