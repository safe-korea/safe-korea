import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/system_civil_alert_settings_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android relay status and disclosure do not enable notification access',
    (tester) async {
      const bridge = MethodChannel('kr.safekor.app/civil_alerts');
      final before = await bridge.invokeMapMethod<String, dynamic>('status');
      expect(before, isNotNull);
      expect(before!['enabled'], isA<bool>());
      expect(before['accessGranted'], isA<bool>());
      await tester.pumpWidget(const SafeKoreaApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.text('지금 필요한 안내'));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SystemCivilAlertSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('휴대전화 경보 연결'), findsOneWidget);
      expect(find.textContaining('다른 앱 알림에도 접근할 수 있는 권한'), findsOneWidget);
      final enable = find.widgetWithText(FilledButton, '알림 접근 설정에서 연결 허용');
      await tester.ensureVisible(enable);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(enable).onPressed, isNull);
      final after = await bridge.invokeMapMethod<String, dynamic>('status');
      expect(after!['enabled'], before['enabled']);
      expect(after['accessGranted'], before['accessGranted']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
