import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/data_permissions_screen.dart';
import 'package:safe_korea/widgets/common.dart';

void main() {
  test('action and warning text colors meet 4.5:1 contrast', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    for (final color in [
      AppPalette.alert,
      AppPalette.caution,
      AppPalette.green,
      AppPalette.ink,
    ]) {
      expect(ratio(color, Colors.white), greaterThanOrEqualTo(4.5));
    }
    expect(
      ratio(AppPalette.caution, AppPalette.cautionBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ratio(AppPalette.muted, AppPalette.background),
      greaterThanOrEqualTo(4.5),
    );
  });
  testWidgets(
    'training colors distinguish urgent, prepare and release without removing labels',
    (tester) async {
      for (final kind in [AlertKind.air, AlertKind.watch, AlertKind.release]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: DrillScreen(kind: kind),
          ),
        );
        await tester.pump();
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          AppPalette.forAlert(kind),
        );
        expect(find.text('훈련 / 테스트'), findsOneWidget);
        expect(find.text('${kind.label} 연습'), findsOneWidget);
        if (kind == AlertKind.air) {
          final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, '주변 대피소 보기'),
          );
          expect(button.style!.backgroundColor!.resolve({}), AppPalette.alert);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  for (final view in [
    (const Size(375, 812), 3.0),
    (const Size(568, 320), 2.0),
  ]) {
    testWidgets('data disclosures and warning notices remain readable $view', (
      tester,
    ) async {
      tester.view.physicalSize = view.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(view.$2)),
            child: child!,
          ),
          home: const DataPermissionsScreen(),
        ),
      );
      for (final title in [
        '현재 위치는 어떻게 쓰나요?',
        '사진·알림 권한은 왜 필요한가요?',
        '외부로 전달되는 정보',
        '저장한 정보를 지우려면',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.textContaining('이전 버전의 연락처'));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: PageBody(
              children: [Notice('위치가 오래되어 다시 확인이 필요합니다.', warning: true)],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
