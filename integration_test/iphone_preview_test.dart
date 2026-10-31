import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture iPhone preview of home and official shelters', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await File('${Directory.systemTemp.path}/safe-korea-iphone-home.png')
        .writeAsBytes(await binding.takeScreenshot('home'));
    await tester.ensureVisible(find.text('주변 대피시설'));
    await tester.tap(find.text('주변 대피시설'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
    await tester.tap(find.text('선택 지역 대피소 불러오기'));
    await tester.pump();
    for (
      var i = 0;
      i < 30 && find.text('공식 시설 조회 중…').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('건을 받아 기기에 저장했습니다'), findsOneWidget);
    await tester.ensureVisible(find.text('온라인 지도 열기'));
    await tester.tap(find.text('온라인 지도 열기'));
    await tester.pump(const Duration(seconds: 4));
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pump(const Duration(seconds: 2));
    await File('${Directory.systemTemp.path}/safe-korea-iphone-shelters.png')
        .writeAsBytes(await binding.takeScreenshot('shelters'));
    debugPrint('PREVIEW_DIRECTORY=${Directory.systemTemp.path}');
  });
}
