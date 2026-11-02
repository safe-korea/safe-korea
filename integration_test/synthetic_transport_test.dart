// Explicit, silent local-server QA. This is NOT background remote push QA.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/services/drill_notifications.dart';

import '../test_driver/synthetic_receiver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('HTTP synthetic gate to native test notification', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    final notifications = DrillNotifications.instance;
    await notifications.initialize();
    await notifications.cancel();
    addTearDown(notifications.cancel);
    final receiver = SyntheticReceiver();
    for (final scenario in [
      'other-region',
      'stale',
      'future',
      'weather',
      'release',
    ]) {
      expect(await receiver.receive(scenario), 0, reason: scenario);
    }
    expect(await receiver.receive('air'), 1);
    expect(await receiver.receive('air'), 0, reason: 'Repeated HTTP response');
    expect(
      await receiver.receive('duplicate'),
      1,
      reason: 'Repeated record in batch',
    );
    final active = await FlutterLocalNotificationsPlugin()
        .getActiveNotifications();
    final ours = active.where((n) => n.id == DrillNotifications.notificationId);
    expect(ours, hasLength(1));
    expect(ours.single.title, '[훈련 / 테스트] 공습경보');
    expect(ours.single.body, contains('실제 경보가 아닙니다'));
  });
}
