// Opt-in emulator harness; never used by a release entrypoint.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/drill_notifications.dart';

Future<void> main() async {
  if (!kDebugMode) throw StateError('Emulator QA requires a debug build');
  app.main();
  await DrillNotifications.instance.initialize();
  final launch = await FlutterLocalNotificationsPlugin()
      .getNotificationAppLaunchDetails();
  // A notification cold start must not create another test notification.
  if (launch?.didNotificationLaunchApp ?? false) return;
  Timer(const Duration(seconds: 15), () async {
    final sent = await DrillNotifications.instance.send(
      sound: false,
      vibration: false,
      kind: AlertKind.nuclear,
    );
    debugPrint(
      'LOCAL_NOTIFICATION_QA posted=$sent sound=false vibration=false',
    );
  });
}
