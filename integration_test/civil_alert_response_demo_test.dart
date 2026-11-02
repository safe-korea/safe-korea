import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture response renderer via accepted synthetic ingress, never send an alert',
    (tester) async {
      final ingress = CivilAlertIngress();
      addTearDown(ingress.dispose);
      await tester.pumpWidget(
        SafeKoreaApp(officialAlertEvents: ingress.notices),
      );
      await tester.pumpAndSettle();
      final now = DateTime.now();
      ingress.accept(
        CivilAlertNotice(
          id: 'demo-synthetic-only',
          revision: '1',
          kind: AlertKind.air,
          issuedAt: now,
          expiresAt: now.add(const Duration(minutes: 2)),
          agency: '상황 재현용 합성 데이터',
          area: '서울특별시 송파구 · 상황 재현',
        ),
        sourceAuthenticated: true,
        recipientMatched: true,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      expect(find.text('훈련 / 테스트'), findsNothing);
      await binding.takeScreenshot('civil-response-before-setting');
      debugPrint('RESPONSE_SCENE_received');
      await Future<void>.delayed(const Duration(seconds: 9));
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      await binding.takeScreenshot('civil-response-indoor');
      debugPrint('RESPONSE_SCENE_response_actions');
      await Future<void>.delayed(const Duration(seconds: 9));
      expect(tester.takeException(), isNull);
      debugPrint('RESPONSE_CAPTURE_COMPLETE');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
