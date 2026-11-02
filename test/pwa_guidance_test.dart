import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/pwa_main.dart';
import 'package:safe_korea/models/alert_guidance.dart';

void main() {
  testWidgets('web guidance opens contextual advice without native plugins', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaPwa());
    await tester.pumpAndSettle();
    expect(find.text('지금 필요한 안내'), findsOneWidget);
    expect(find.text('저장한 대피소'), findsOneWidget);
    expect(find.text('가족 만남 장소'), findsOneWidget);
    final action = tester.element(find.text('지금 할 행동 보기'));
    expect(DefaultTextStyle.of(action).style.fontFamily, 'SafeKoreaWeb');
    await tester.tap(find.text('지금 할 행동 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공습경보').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('실내'));
    await tester.pumpAndSettle();
    expect(find.text('계단으로 이동'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(375, 812), const Size(568, 320)]) {
    testWidgets('web detail remains scrollable with large text $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const item = <String, dynamic>{
        'id': 'air',
        'title': '공습경보',
        'summary': '즉시 대피하세요',
        'steps': ['가까운 민방위 대피소로 이동하세요.', '정부 방송과 현장 안내를 따르세요.'],
      };
      await tester.pumpWidget(MaterialApp(home: PwaGuidanceDetail(item: item)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('전체 행동요령'));
      await tester.tap(find.text('전체 행동요령'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
