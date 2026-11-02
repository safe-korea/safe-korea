import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/services/connection_monitor.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline tools remain reachable and never replace open guidance',
    (tester) async {
      var linked = false;
      final monitor = ConnectionMonitor(
        readLink: () async => linked,
        changes: const Stream.empty(),
        probe: () async => true,
      );
      await monitor.refresh();
      await tester.pumpWidget(SafeKoreaApp(monitor: monitor));
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
      }
      expect(find.text('네트워크 연결이 없어요'), findsOneWidget);
      await binding.takeScreenshot('offline-hub-${Platform.operatingSystem}');
      await tester.tap(find.text('지금 할 행동 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      linked = true;
      await monitor.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      linked = false;
      await monitor.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      await tester.tap(find.text('연결 없음 · 오프라인 기능 보기'));
      await tester.pumpAndSettle();
      expect(find.text('가족 만남 장소'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      monitor.dispose();
    },
  );
}
