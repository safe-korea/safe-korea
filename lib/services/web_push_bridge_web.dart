import 'dart:convert';
import 'dart:js_interop';

import '../models/alert_guidance.dart';
import 'civil_alert_ingress.dart';

@JS('window.safeKorPushReceiver')
external set _receiver(JSFunction value);
@JS('window.safeKorPushReady')
external JSFunction? get _ready;

/// Only push-client.js calls this after an authenticated same-origin lookup.
/// A URL contains an opaque delivery ID, never the alert type or authority.
void attachWebPushBridge() {
  _receiver = ((JSString value) {
    try {
      final row = jsonDecode(value.toDart) as Map<String, dynamic>;
      if (row['type'] == 'test') {
        final id = row['deliveryId'],
            issued = row['publishedAt'],
            expires = row['expiresAt'];
        if (id is! String ||
            !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
            issued is! int ||
            expires is! int) {
          return;
        }
        CivilAlertIngress.shared.acceptResponseTest(
          id: id,
          kind: AlertKind.air,
          issuedAt: DateTime.fromMillisecondsSinceEpoch(issued, isUtc: true),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
        );
        return;
      }
      final kind = AlertKind.fromName(row['kind'] as String?);
      if (row['type'] != 'civil' || kind == null || kind == AlertKind.release) {
        return;
      }
      final issued = row['publishedAt'], expires = row['expiresAt'];
      final id = row['id'], revision = row['revision'];
      if (issued is! int ||
          expires is! int ||
          id is! String ||
          revision is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision)) {
        return;
      }
      CivilAlertIngress.shared.accept(
        CivilAlertNotice(
          id: id,
          revision: revision,
          kind: kind,
          issuedAt: DateTime.fromMillisecondsSinceEpoch(issued, isUtc: true),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
          agency: row['agency'] as String,
          area: row['area'] as String,
        ),
        sourceAuthenticated: true,
        recipientMatched: true,
      );
    } catch (_) {
      // Unavailable/invalid notifications must never block offline guidance.
    }
  }).toJS;
  _ready?.callAsFunction();
}

@JS('window.safeKorOpenPushSettings')
external JSFunction? get _openPushSettings;
@JS('window.safeKorOpenInstallSettings')
external JSFunction? get _openInstallSettings;
void openWebNotificationSettings() => _openPushSettings?.callAsFunction();
void openWebInstallSettings() => _openInstallSettings?.callAsFunction();

@JS('window.safeKorPlayTestSiren')
external JSPromise<JSBoolean> _playTestSiren();
@JS('window.safeKorStopTestSiren')
external void _stopTestSiren();
Future<bool> playWebTestSiren() async => (await _playTestSiren().toDart).toDart;
void stopWebTestSiren() => _stopTestSiren();
