import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';
import 'package:safe_korea/services/drill_notifications.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CivilAlertNotice official(DateTime now) => CivilAlertNotice(
    id: 'official-fixture',
    revision: '1',
    kind: AlertKind.air,
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 2)),
    agency: '합성 검증 자료',
    area: '합성 테스트 지역',
  );

  test(
    'test entry cannot become official or replace a fresh official response',
    () async {
      final now = DateTime.now();
      final ingress = CivilAlertIngress(clock: () => now);
      addTearDown(ingress.dispose);
      bool preview(String id, {DateTime? issued, DateTime? expires}) =>
          ingress.acceptResponseTest(
            id: id,
            kind: AlertKind.air,
            issuedAt: issued ?? now,
            expiresAt: expires ?? now.add(const Duration(minutes: 2)),
          );
      expect(
        preview(
          'expired',
          issued: now.subtract(const Duration(minutes: 3)),
          expires: now.subtract(const Duration(minutes: 1)),
        ),
        false,
      );
      expect(
        preview('long', expires: now.add(const Duration(minutes: 10))),
        false,
      );
      expect(preview('valid'), true);
      expect(
        preview('valid'),
        true,
      ); // Reopening a test notification is allowed.
      expect(ingress.latestAccepted!.testOnly, true);
      expect(
        ingress.accept(
          ingress.latestAccepted!,
          sourceAuthenticated: true,
          recipientMatched: true,
        ),
        false,
      );
      expect(
        ingress.accept(
          official(now),
          sourceAuthenticated: true,
          recipientMatched: true,
        ),
        true,
      );
      expect(preview('cannot-cover-official'), false);
      expect(ingress.latestAccepted!.testOnly, false);
    },
  );

  testWidgets(
    'preview opens the red response directly, keeps test label and supports indoor actions',
    (tester) async {
      final ingress = CivilAlertIngress();
      addTearDown(ingress.dispose);
      await tester.pumpWidget(
        SafeKoreaApp(officialAlertEvents: ingress.notices),
      );
      await tester.pumpAndSettle();
      final now = DateTime.now();
      ingress.acceptResponseTest(
        id: 'widget',
        kind: AlertKind.air,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 2)),
      );
      await tester.pumpAndSettle();
      expect(find.text('훈련 / 테스트 · 공습경보'), findsOneWidget);
      expect(find.text('테스트 중 · 실제 경보 아님'), findsOneWidget);
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppPalette.forAlert(AlertKind.air),
      );
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      ingress.accept(
        official(DateTime.now()),
        sourceAuthenticated: true,
        recipientMatched: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('테스트 중 · 실제 경보 아님'), findsNothing);
      expect(find.text('훈련 / 테스트 · 공습경보'), findsNothing);
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Android response test uses local notification, validated tap payload and ignores stale or malformed input', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final ingress = CivilAlertIngress();
    addTearDown(ingress.dispose);
    final service = DrillNotifications(responseIngress: ingress);
    expect(
      await service.send(
        sound: false,
        vibration: false,
        responseTest: true,
        responseDelay: Duration.zero,
      ),
      true,
    );
    final show = calls.singleWhere((c) => c.method == 'show');
    expect(show.arguments['title'], contains('훈련 / 테스트'));
    expect(show.arguments['body'], contains('빨간 대피 안내'));
    final payload = show.arguments['payload'] as String;
    expect(payload, startsWith('safe_korea:response_test:v1:air:'));
    service.handlePayload(payload);
    expect(ingress.latestAccepted!.testOnly, true);
    expect(ingress.latestAccepted!.kind, AlertKind.air);
    final current = ingress.latestAccepted;
    for (final invalid in [
      'safe_korea:response_test:v1:unknown:1',
      'safe_korea:response_test:v1:air:1',
      'safe_korea:response_test:v1:air:999999999999999999999',
      '$payload:extra',
    ]) {
      service.handlePayload(invalid);
    }
    expect(identical(ingress.latestAccepted, current), true);
  });

  test('Android notification cold launch routes into test response without drill callback', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final payload =
        'safe_korea:response_test:v1:air:${DateTime.now().millisecondsSinceEpoch}';
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getNotificationAppLaunchDetails'
          ? {
              'notificationLaunchedApp': true,
              'notificationResponse': {
                'payload': payload,
                'notificationResponseType': 0,
                'id': 7001,
              },
            }
          : true,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final ingress = CivilAlertIngress();
    addTearDown(ingress.dispose);
    final service = DrillNotifications(responseIngress: ingress);
    int drills = 0;
    service.attach(() => drills++);
    await service.initialize();
    expect(drills, 0);
    expect(ingress.latestAccepted?.testOnly, true);
  });
}
