import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/widgets/alert_actions.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  test('all settings have offline instructions, chemical never recommends shelter map', () {
    for (final kind in AlertKind.values) {
      for (final setting in UserSetting.values) {
        expect(immediateActions(kind, setting), hasLength(3));
        expect(
          immediateActions(kind, setting).every((s) => s.isNotEmpty),
          isTrue,
        );
      }
    }
    expect(AlertKind.chemical.offersShelters, isFalse);
    expect(AlertKind.cbrn.offersShelters, isFalse);
    expect(
      immediateActions(AlertKind.nuclear, UserSetting.unknown).first,
      contains('이미 봤다면'),
    );
  });
  testWidgets(
    'manual situation switches advice and resets when alert changes',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AlertGuideScreen()));
      expect(find.text('가까운 대피소로 이동'), findsOneWidget);
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      await tester.tap(find.text('실외'));
      await tester.pumpAndSettle();
      expect(find.text('가까운 건물로 대피'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: AlertGuideScreen(
            initialKind: AlertKind.cbrn,
            key: ValueKey('cbrn'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('대피시설 확인'), findsNothing);
      await tester.ensureVisible(find.text('화학 공격 안내'));
      await tester.tap(find.text('화학 공격 안내'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('실내'));
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('문·창문 닫기'), findsOneWidget);
      expect(find.text('대피시설 확인'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('all drill types support large text and do not auto-play sound', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final kind in AlertKind.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: DrillScreen(key: ValueKey(kind), kind: kind),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byType(AlertActions));
      expect(find.text('훈련 / 테스트'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
