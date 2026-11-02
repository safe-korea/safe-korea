import 'package:flutter/material.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/drill_notifications.dart';
import 'package:safe_korea/screens/notification_test_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool permission = true;
  bool fail = false;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    permission = true;
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (fail) throw PlatformException(code: 'unavailable');
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          if (call.method == 'requestNotificationsPermission') {
            return permission;
          }
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'startup does not request permission or send; denied request never sends',
    () async {
      final service = DrillNotifications();
      await service.initialize();
      expect(calls.map((e) => e.method), [
        'initialize',
        'getNotificationAppLaunchDetails',
      ]);
      permission = false;
      expect(await service.send(sound: false, vibration: false), isFalse);
      expect(calls.where((e) => e.method == 'show'), isEmpty);
    },
  );
  test(
    'silent and audible modes use separate channels with drill payload',
    () async {
      final service = DrillNotifications();
      await service.send(sound: false, vibration: false);
      await service.send(sound: true, vibration: true);
      final shows = calls.where((e) => e.method == 'show').toList();
      expect(shows, hasLength(2));
      expect(shows.first.arguments['payload'], DrillNotifications.payload);
      expect(shows.first.arguments['platformSpecifics']['playSound'], false);
      expect(
        shows.first.arguments['platformSpecifics']['enableVibration'],
        false,
      );
      expect(shows.last.arguments['platformSpecifics']['playSound'], true);
      expect(shows.last.arguments['platformSpecifics']['sound'], 'drill_siren');
      expect(shows.first.arguments['platformSpecifics']['sound'], isNull);
      expect(
        shows.first.arguments['platformSpecifics']['channelId'],
        isNot(shows.last.arguments['platformSpecifics']['channelId']),
      );
      await service.cancel();
      expect(calls.last.method, 'cancel');
      expect(calls.last.arguments['id'], DrillNotifications.notificationId);
    },
  );
  test('iOS uses the bundled siren only when sound is selected', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final service = DrillNotifications();
    await service.send(sound: true, vibration: false);
    final audible = calls.lastWhere((call) => call.method == 'show');
    expect(audible.arguments['platformSpecifics']['sound'], 'drill_siren.wav');
    expect(audible.arguments['platformSpecifics']['presentSound'], true);
    await service.send(sound: false, vibration: false);
    final silent = calls.lastWhere((call) => call.method == 'show');
    expect(silent.arguments['platformSpecifics']['sound'], isNull);
    expect(silent.arguments['platformSpecifics']['presentSound'], false);
  });
  test(
    'cold-start payload waits for navigator; unknown payload is ignored',
    () {
      final service = DrillNotifications();
      int opened = 0;
      service.handlePayload('unknown');
      service.attach(() => opened++);
      expect(opened, 0);
      final cold = DrillNotifications();
      cold.handlePayload(DrillNotifications.payload);
      cold.attach(() => opened++);
      expect(opened, 1);
      cold.attach(() => opened++);
      expect(opened, 1);
      cold.handlePayload(DrillNotifications.payload);
      expect(opened, 2);
    },
  );
  test(
    'every alert routes only its allowlisted type and correct sound',
    () async {
      final service = DrillNotifications();
      AlertKind? opened;
      service.attach(() => opened = service.openedKind);
      for (final kind in AlertKind.values) {
        await service.send(sound: true, vibration: false, kind: kind);
        final call = calls.lastWhere((call) => call.method == 'show');
        expect(call.arguments['platformSpecifics']['sound'], kind.soundAsset);
        service.handlePayload(call.arguments['payload'] as String);
        expect(opened, kind);
      }
      expect(AlertKind.air.soundAsset, AlertKind.nuclear.soundAsset);
      expect(AlertKind.watch.hasSiren, isFalse);
      final before = opened;
      service.handlePayload('safe_korea:drill:v2:unknown');
      expect(opened, before);
    },
  );
  test('iOS voice-only alert uses bundled speech rather than siren', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    IOSFlutterLocalNotificationsPlugin.registerWith();
    await DrillNotifications().send(
      sound: true,
      vibration: false,
      kind: AlertKind.cbrn,
    );
    final call = calls.lastWhere((call) => call.method == 'show');
    expect(
      call.arguments['platformSpecifics']['sound'],
      'drill_cbrn_voice.wav',
    );
  });
  testWidgets('screen defaults silent and recovers from platform error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationTestScreen(notifications: DrillNotifications()),
      ),
    );
    expect(calls, isEmpty);
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).every((s) => !s.value),
      isTrue,
    );
    fail = true;
    await tester.ensureVisible(find.text('알림 보내기'));
    await tester.tap(find.text('알림 보내기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('알림을 처리하지 못했습니다'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('알림 보내기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('알림 센터에서 테스트 알림을 눌러'), findsOneWidget);
  });
}
