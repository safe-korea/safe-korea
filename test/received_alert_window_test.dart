import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/civil_alert_screen.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';
import 'package:safe_korea/services/connection_monitor.dart';

CivilAlertNotice official(Duration age, {AlertKind kind = AlertKind.air}) {
  final issued = DateTime.now().subtract(age);
  return CivilAlertNotice(
    id: 'official-${issued.microsecondsSinceEpoch}',
    revision: '1',
    kind: kind,
    issuedAt: issued,
    // Android relay keeps a received alert reopenable for an hour.
    expiresAt: issued.add(CivilAlertNotice.recentWindow),
    agency: '합성 검증 자료',
    area: '합성 테스트 지역',
  );
}

void main() {
  test('ingress keeps an hour-old window but auto-open stays short', () {
    final now = DateTime.now();
    final ingress = CivilAlertIngress(clock: () => now);
    addTearDown(ingress.dispose);
    bool accept(CivilAlertNotice n) =>
        ingress.accept(n, sourceAuthenticated: true, recipientMatched: true);
    final late20 = official(const Duration(minutes: 20));
    expect(late20.freshAt(now), false);
    expect(late20.recentAt(now), true);
    expect(accept(late20), true);
    expect(accept(official(const Duration(minutes: 61))), false);
    // A drill preview must not hide a recently received real alert.
    expect(
      ingress.acceptResponseTest(
        id: 'drill',
        kind: AlertKind.air,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 2)),
      ),
      false,
    );
  });

  Future<StreamController<CivilAlertNotice>> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final events = StreamController<CivilAlertNotice>.broadcast();
    addTearDown(events.close);
    final monitor = ConnectionMonitor(
      readLink: () async => true,
      changes: const Stream<void>.empty(),
      probe: () async => true,
    );
    addTearDown(monitor.dispose);
    await tester.pumpWidget(
      SafeKoreaApp(officialAlertEvents: events.stream, monitor: monitor),
    );
    await tester.pumpAndSettle();
    return events;
  }

  testWidgets('alert opened late stays on home and can be reopened', (
    tester,
  ) async {
    final events = await boot(tester);
    events.add(official(const Duration(minutes: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsNothing);
    expect(find.text('공습경보 수신'), findsOneWidget);
    expect(find.textContaining('20분 전'), findsOneWidget);
    await tester.tap(find.text('대응 화면 다시 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsOneWidget);
    expect(find.textContaining('받은 지 시간이 지났어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back from a fresh alert keeps a way back on home', (
    tester,
  ) async {
    final events = await boot(tester);
    events.add(official(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsOneWidget);
    expect(find.textContaining('받은 지 시간이 지났어요'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsNothing);
    expect(find.text('공습경보 수신'), findsOneWidget);
    await tester.tap(find.text('대응 화면 다시 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsOneWidget);
  });

  testWidgets('alerts older than the window and releases leave no banner', (
    tester,
  ) async {
    final events = await boot(tester);
    events.add(official(const Duration(minutes: 61)));
    await tester.pumpAndSettle();
    expect(find.text('대응 화면 다시 열기'), findsNothing);
    final alert = official(const Duration(minutes: 5));
    events.add(alert);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('대응 화면 다시 열기'), findsOneWidget);
    events.add(
      CivilAlertNotice(
        id: 'release',
        revision: '1',
        kind: AlertKind.release,
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        agency: '합성 검증 자료',
        area: '합성 테스트 지역',
        relatedAlertId: alert.id,
      ),
    );
    await tester.pumpAndSettle();
    if (find.byType(CivilAlertScreen).evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(find.text('대응 화면 다시 열기'), findsNothing);
  });

  testWidgets('test preview banner is labelled as a drill', (tester) async {
    final events = await boot(tester);
    final now = DateTime.now();
    events.add(
      CivilAlertNotice(
        id: 'response-test/x',
        revision: 'test',
        kind: AlertKind.air,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 2)),
        agency: '사용자가 요청한 테스트 알림',
        area: '이 기기에서만 진행하는 화면 연결 테스트',
        testOnly: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('훈련 / 테스트 · 공습경보'), findsOneWidget);
    expect(find.text('공습경보 수신'), findsNothing);
  });

  testWidgets('received alert stays reachable while offline', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final events = StreamController<CivilAlertNotice>.broadcast();
    addTearDown(events.close);
    final monitor = ConnectionMonitor(
      readLink: () async => false,
      changes: const Stream<void>.empty(),
      probe: () async => null,
    );
    addTearDown(monitor.dispose);
    await tester.pumpWidget(
      SafeKoreaApp(officialAlertEvents: events.stream, monitor: monitor),
    );
    await monitor.refresh();
    await tester.pumpAndSettle();
    // Offline: home is replaced by the offline tools screen.
    expect(find.text('네트워크 연결이 없어요'), findsOneWidget);
    events.add(official(const Duration(minutes: 20)));
    await tester.pumpAndSettle();
    expect(find.text('공습경보 수신'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('대응 화면 다시 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CivilAlertScreen), findsOneWidget);
  });
}
