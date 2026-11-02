import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/services/drill_notifications.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native initialization and drill routing without sending alerts',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await DrillNotifications.instance.initialize();
      await tester.ensureVisible(find.text('테스트 알림 설정'));
      await tester.tap(find.text('테스트 알림 설정'));
      await tester.pumpAndSettle();
      expect(find.text('지금 테스트 알림 보내기'), findsOneWidget);
      DrillNotifications.instance.handlePayload('invalid');
      await tester.pumpAndSettle();
      expect(find.text('테스트 알림'), findsOneWidget);
      DrillNotifications.instance.handlePayload(DrillNotifications.payload);
      DrillNotifications.instance.handlePayload(DrillNotifications.payload);
      await tester.pumpAndSettle();
      expect(find.text('훈련 종료 · 홈으로'), findsOneWidget);
      await tester.tap(find.text('훈련 종료 · 홈으로'));
      await tester.pumpAndSettle();
      expect(find.text('테스트 알림'), findsOneWidget);
    },
  );
}
