import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/notification_test_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';

class EmptyPreparation extends LocalStore {
  @override
  Future<Set<String>> loadPreparation() async => {};
}

void main() {
  testWidgets('redesigned everyday screens support narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in [
      const HomeScreen(),
      const GuidelinesScreen(),
      ReadinessScreen(store: EmptyPreparation()),
      const NotificationTestScreen(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
