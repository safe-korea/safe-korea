import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

import '../test/app_completion_test.dart' show PreparationMemoryStore;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'preparation radio and supplies follow the app design without sending data',
    (tester) async {
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.isIOS) await binding.takeScreenshot(name);
      }

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ReadinessScreen(store: PreparationMemoryStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('비상용품 준비'));
      await capture('preparation-services');
      await tester.tap(find.text('비상용품 준비'));
      await capture('supplies-preparation');
      await tester.ensureVisible(find.textContaining('현재 연결된 판매처가 없습니다'));
      await capture('supplies-no-partner');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('라디오 연결'));
      await tester.tap(find.text('라디오 연결'));
      await capture('radio-connection');
      await tester.tap(find.text('통신이 끊겼다면'));
      await capture('radio-offline-help');
      // No external launch or playback during automated visual QA.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const AfterArrivalScreen(training: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('KBS 라디오 연결'));
      await capture('after-arrival-radio');
      await tester.ensureVisible(find.text('가족에게 내 상태 알리기'));
      expect(find.text('가족에게 내 상태 알리기').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
