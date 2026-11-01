import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'screens/drill_screen.dart';
import 'services/drill_notifications.dart';
import 'theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
bool _notificationDrillOpen = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeKoreaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DrillNotifications.instance.attach(() async {
      final navigator = _navigatorKey.currentState;
      if (navigator == null || _notificationDrillOpen) return;
      final kind = DrillNotifications.instance.openedKind;
      _notificationDrillOpen = true;
      try {
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => DrillScreen(kind: kind)),
        );
      } finally {
        _notificationDrillOpen = false;
      }
    });
    // A platform failure must never prevent access to offline guidance.
    DrillNotifications.instance.initialize().catchError((Object _) {});
  });
}

class SafeKoreaApp extends StatelessWidget {
  const SafeKoreaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: 'SAFE KOREA',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildAppTheme(),
    home: const AppShell(),
  );
}
