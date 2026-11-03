// Explicit own-emulator test only. No government feed or external recipient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/services/drill_notifications.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'local test opens red response in foreground and after notification tap',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      final service = DrillNotifications.instance;
      addTearDown(service.cancel);
      expect(
        await service.send(
          sound: false,
          vibration: false,
          responseTest: true,
          responseDelay: Duration.zero,
        ),
        true,
      );
      await tester.pumpAndSettle();
      expect(find.text('테스트 중 · 실제 경보 아님'), findsOneWidget);
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await service.cancel();
      // The host QA driver puts this dedicated emulator in the background here,
      // then taps only this app's clearly labelled local notification.
      debugPrint('SAFEKOR_QA_BACKGROUND_READY');
      expect(
        await tester.runAsync(
          () =>
              service.send(sound: false, vibration: false, responseTest: true),
        ),
        true,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (find.text('테스트 중 · 실제 경보 아님').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('훈련 / 테스트 · 공습경보'), findsOneWidget);
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      await tester.tap(find.text('실외'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugPrint('SAFEKOR_QA_CAPTURE_READY');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
    },
  );
}
