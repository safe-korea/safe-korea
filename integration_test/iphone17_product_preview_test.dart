import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/pwa_main.dart';
import 'package:safe_korea/models/alert_guidance.dart';

// Render the shared PWA guidance widgets on the actual iPhone 17 Pro simulator.
// This is a Flutter screen capture, not evidence of Safari installation/support.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture complete iPhone 17 Pro product screens', (tester) async {
    await tester.pumpWidget(const SafeKoreaPwa());
    await tester.pumpAndSettle();
    expect(find.text('지금 필요한 안내'), findsOneWidget);
    await tester.tap(find.text('지금 할 행동 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('product-guidance-list');
    await tester.tap(find.text('공습경보').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('실내'));
    await tester.pumpAndSettle();
    expect(find.text('계단으로 이동'), findsOneWidget);
    await binding.takeScreenshot('product-air-guidance');
    await tester.tap(find.text('실외'));
    await tester.pumpAndSettle();
    expect(find.text('가까운 건물로 대피'), findsOneWidget);
    await binding.takeScreenshot('product-outdoor-guidance');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
