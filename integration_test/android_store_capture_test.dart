import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';

// Real Android widgets only. No GPS requests, personal data, notifications or audio.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture Android store screens without private data', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('01-home');
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-offline-guidance');
    await tester.tap(find.text('내 상황에 맞는 행동 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실내'));
    await tester.pumpAndSettle();
    expect(find.text('계단으로 이동'), findsOneWidget);
    await binding.takeScreenshot('03-indoor-actions');
    await tester.tap(find.text('실외'));
    await tester.pumpAndSettle();
    expect(find.text('가까운 건물로 대피'), findsOneWidget);
    await binding.takeScreenshot('04-outdoor-actions');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
