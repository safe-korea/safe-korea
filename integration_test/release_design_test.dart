import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/data_permissions_screen.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'severity colors and data disclosures remain distinct and readable',
    (tester) async {
      for (final kind in [AlertKind.air, AlertKind.watch, AlertKind.release]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: DrillScreen(kind: kind),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('훈련 / 테스트'), findsOneWidget);
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          AppPalette.forAlert(kind),
        );
        if (Platform.isIOS) {
          await binding.takeScreenshot('release-color-${kind.name}');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const DataPermissionsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isIOS) {
        await binding.takeScreenshot('release-data-permissions');
      }
      await tester.tap(find.text('현재 위치는 어떻게 쓰나요?'));
      await tester.pumpAndSettle();
      if (Platform.isIOS) {
        await binding.takeScreenshot('release-location-disclosure');
      }
      await tester.ensureVisible(find.text('저장한 정보를 지우려면'));
      await tester.tap(find.text('저장한 정보를 지우려면'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('이전 버전의 연락처'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
