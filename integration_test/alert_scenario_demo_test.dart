import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/theme/app_theme.dart';

/// Recreates hearing an external warning and manually consulting the app.
/// Does not inject, impersonate, or claim a government notification.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'respond to an external air warning without entering drill mode',
    (tester) async {
      Future<void> hold(String name, int seconds) async {
        await binding.takeScreenshot('scenario-$name');
        debugPrint('SCENARIO_SCENE_$name');
        await Future<void>.delayed(Duration(seconds: seconds));
      }

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await hold('open', 6);
      await tester.tap(find.text('지금 할 행동 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('공습경보').last);
      await tester.pumpAndSettle();
      expect(find.text('훈련 / 테스트'), findsNothing);
      await hold('kind', 8);
      await tester.ensureVisible(find.text('실내').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('실내').first);
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      await hold('actions', 9);
      expect(tester.takeException(), isNull);
      debugPrint('SCENARIO_CAPTURE_COMPLETE');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
