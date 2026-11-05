import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/alert_preview_onboarding.dart';
import 'package:safe_korea/screens/app_shell.dart';
import 'package:safe_korea/screens/civil_alert_screen.dart';
import 'package:safe_korea/screens/system_civil_alert_settings_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';

class FlagStore extends LocalStore {
  final flags = <String>{};
  @override
  Future<bool> loadFlag(String name) async => flags.contains(name);
  @override
  Future<void> saveFlag(String name) async => flags.add(name);
}

Future<void> pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first run shows the labelled alert preview once', (
    tester,
  ) async {
    final store = FlagStore();
    await pump(tester, AppShell(store: store));
    expect(find.byType(AlertPreviewOnboarding), findsOneWidget);
    expect(find.text('공습경보가 울리면\n이 화면이 열려요'), findsOneWidget);
    // The preview is the real response screen, marked as an example.
    expect(find.byType(CivilAlertScreen), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('예시 화면')), findsOneWidget);
    expect(find.textContaining('정부 경보를 대신 받는 앱은 아니며'), findsOneWidget);
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertPreviewOnboarding), findsNothing);
    expect(find.text('지금 필요한 안내'), findsOneWidget);
    expect(store.flags, contains('alert_preview_seen'));
    // Next launch: straight to home.
    await pump(tester, AppShell(store: store));
    expect(find.byType(AlertPreviewOnboarding), findsNothing);
  });

  testWidgets('try-it opens the silent, labelled response screen', (
    tester,
  ) async {
    await pump(tester, AppShell(store: FlagStore(), showOnboarding: true));
    await tester.tap(find.text('소리 없이 직접 눌러 보기'));
    await tester.pumpAndSettle();
    expect(find.text('훈련 / 테스트 · 실제 경보 아님'), findsOneWidget);
    await tester.tap(find.text('실내'));
    await tester.pumpAndSettle();
    expect(find.text('계단으로 이동'), findsOneWidget);
  });

  testWidgets('connect goes to the phone alert link settings', (tester) async {
    final store = FlagStore();
    await pump(tester, AppShell(store: store, showOnboarding: true));
    await tester.tap(find.text('휴대전화 경보 연결하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SystemCivilAlertSettingsScreen), findsOneWidget);
    expect(store.flags, contains('alert_preview_seen'));
    expect(tester.takeException(), isNull);
  });
}
