import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'services/system_civil_alert_link.dart';
import 'widgets/civil_alert_navigation.dart';
import 'services/civil_alert_ingress.dart';
import 'screens/offline_hub_screen.dart';
import 'services/connection_monitor.dart';
import 'screens/drill_screen.dart';
import 'services/drill_notifications.dart';
import 'theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
bool _notificationDrillOpen = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeKoreaApp());
  ConnectionMonitor.instance.start();
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
    SystemCivilAlertLink.shared.start().catchError((Object _) {});
  });
}

class SafeKoreaApp extends StatelessWidget {
  const SafeKoreaApp({
    super.key,
    this.monitor,
    this.appTheme,
    this.officialAlertEvents,
  });
  final Stream<CivilAlertNotice>? officialAlertEvents;
  final ThemeData? appTheme;
  final ConnectionMonitor? monitor;
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: 'SAFE KOREA',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appTheme ?? buildAppTheme(),
    builder: (context, child) => CivilAlertNavigation(
      navigatorKey: _navigatorKey,
      notices: officialAlertEvents,
      child: ValueListenableBuilder<LinkStatus>(
        valueListenable: monitor ?? ConnectionMonitor.instance,
        builder: (context, status, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status.needsOfflineTools)
              Material(
                color: AppPalette.cautionBackground,
                child: SafeArea(
                  bottom: false,
                  child: TextButton.icon(
                    onPressed: () => _navigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => OfflineHubScreen(monitor: monitor),
                      ),
                    ),
                    icon: const Icon(Icons.wifi_off),
                    label: Text(
                      status == LinkStatus.offline
                          ? '연결 없음 · 오프라인 기능 보기'
                          : '연결 확인 필요 · 오프라인 기능 보기',
                    ),
                  ),
                ),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: status.needsOfflineTools,
                child: child!,
              ),
            ),
          ],
        ),
      ),
    ),
    home: AppShell(monitor: monitor),
  );
}
