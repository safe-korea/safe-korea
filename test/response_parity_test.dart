import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/civil_alert_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';
import 'package:safe_korea/theme/app_theme.dart';

CivilAlertNotice notice(AlertKind kind, {bool test = false}) {
  final now = DateTime.now();
  return CivilAlertNotice(
    id: test ? 'response-test/p' : 'official-p',
    revision: test ? 'test' : '1',
    kind: kind,
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 2)),
    agency: '합성 검증 자료',
    area: '합성 테스트 지역',
    testOnly: test,
  );
}

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  const badge = '훈련 / 테스트 · 실제 경보 아님';

  testWidgets('drill and real response share the shelter exit and order', (
    tester,
  ) async {
    for (final screen in <Widget>[
      const DrillScreen(),
      CivilAlertScreen(notice: notice(AlertKind.air)),
    ]) {
      await pump(tester, screen);
      final exit = find.text('주변 대피소 보기');
      expect(exit, findsOneWidget, reason: '$screen');
      expect(find.text('물품을 찾느라 지체하지 마세요'), findsOneWidget);
      // The way out comes before the situation-specific steps.
      expect(
        tester.getTopLeft(exit).dy,
        lessThan(tester.getTopLeft(find.text('현재 있는 곳')).dy),
      );
    }
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('주변 대피소 보기'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('drill label is inside the red card for drills and tests only', (
    tester,
  ) async {
    await pump(tester, const DrillScreen());
    expect(find.text(badge), findsOneWidget);
    await pump(
      tester,
      CivilAlertScreen(notice: notice(AlertKind.air, test: true)),
    );
    expect(find.text(badge), findsOneWidget);
    final label = tester.widget<Text>(find.text(badge));
    expect(label.style?.color, AppPalette.forAlert(AlertKind.air));
    await pump(tester, CivilAlertScreen(notice: notice(AlertKind.air)));
    expect(find.text(badge), findsNothing);
  });

  testWidgets(
    'chemical response does not point people to underground shelters',
    (tester) async {
      await pump(tester, CivilAlertScreen(notice: notice(AlertKind.chemical)));
      expect(find.text('주변 대피소 보기'), findsNothing);
      expect(find.textContaining('저장한 대피소 보기'), findsNothing);
    },
  );
}
