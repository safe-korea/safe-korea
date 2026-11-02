// Explicit emulator QA only. Sends silent, clearly labelled local test notices.
// This does not exercise a remote push service or government-alert receiver.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/drill_notifications.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native silent notifications replace, label and cancel', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    final service = DrillNotifications.instance;
    final plugin = FlutterLocalNotificationsPlugin();
    addTearDown(service.cancel);
    await service.cancel();
    for (final kind in [AlertKind.air, AlertKind.nuclear, AlertKind.release]) {
      expect(
        await service.send(sound: false, vibration: false, kind: kind),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      final active = (await plugin.getActiveNotifications())
          .where((n) => n.id == DrillNotifications.notificationId)
          .toList();
      expect(active, hasLength(1));
      expect(active.single.title, '[훈련 / 테스트] ${kind.label}');
      expect(active.single.body, contains('실제 경보가 아닙니다'));
    }
    await service.cancel();
    expect(
      (await plugin.getActiveNotifications()).where(
        (n) => n.id == DrillNotifications.notificationId,
      ),
      isEmpty,
    );
  });
}
