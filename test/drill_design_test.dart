import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  testWidgets(
    'first viewport prioritizes situational action; bag remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const DrillScreen()),
      );
      expect(find.text('대피시설 확인').hitTestable(), findsOneWidget);
      expect(find.text('실내').hitTestable(), findsOneWidget);
      expect(find.text('가까운 대피소로 이동').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('없으면 바로 대피하세요.'));
      expect(find.text('없으면 바로 대피하세요.').hitTestable(), findsOneWidget);
      expect(find.text('챙길 것 보기'), findsNothing);
      expect(find.text('준비된 배낭 · 물 · 상비약 · 손전등'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('대피시설 확인')).dy,
        lessThan(tester.getTopLeft(find.text('없으면 바로 대피하세요.')).dy),
      );
      expect(find.byType(Checkbox), findsNothing);
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('small landscape and enlarged text retain scroll access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const DrillScreen(),
      ),
    );
    await tester.ensureVisible(find.text('행동요령 보기'));
    await tester.tap(find.text('행동요령 보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('연습 체크 · 선택 사항'));
    await tester.tap(find.text('연습 체크 · 선택 사항'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정부 안내를 확인하는 방법을 익혔어요'));
    expect(find.text('정부 안내를 확인하는 방법을 익혔어요').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
