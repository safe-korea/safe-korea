import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/pwa_main.dart';

void main() {
  testWidgets('web guidance opens contextual advice without native plugins', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaPwa());
    await tester.pumpAndSettle();
    expect(find.text('경보를 들었다면, 상황에 맞는 행동을 확인하세요.'), findsOneWidget);
    final externalButton = tester.element(find.text('정부 대피시설 찾기 · 인터넷 필요'));
    expect(
      DefaultTextStyle.of(externalButton).style.fontFamily,
      'SafeKoreaWeb',
    );
    await tester.tap(find.text('공습경보'));
    await tester.pumpAndSettle();
    expect(find.text('행동요령 확인 · 실제 경보가 아닙니다'), findsOneWidget);
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
