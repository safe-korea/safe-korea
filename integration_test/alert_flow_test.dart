import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/notification_test_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline context guidance and signal selection without playing audio',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const DrillScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 지하나 아래층으로 이동하세요.'), findsOneWidget);
      if (Platform.isIOS) await binding.takeScreenshot('air-indoor');
      await tester.tap(find.text('실외'));
      await tester.pumpAndSettle();
      expect(find.text('가까운 지하시설이나 콘크리트 건물 안으로 대피하세요.'), findsOneWidget);
      if (Platform.isIOS) await binding.takeScreenshot('air-outdoor');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const AlertGuideScreen(initialKind: AlertKind.chemical),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('대피시설 확인'), findsNothing);
      if (Platform.isIOS) await binding.takeScreenshot('chemical-indoor');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const NotificationTestScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('경계경보').last);
      await tester.pumpAndSettle();
      expect(find.text('음성 안내 켜기'), findsOneWidget);
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).every((s) => !s.value),
        isTrue,
      );
      if (Platform.isIOS) await binding.takeScreenshot('watch-signal');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
