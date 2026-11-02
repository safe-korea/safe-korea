import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/alert_guidance.dart';
import 'civil_alert_ingress.dart';

/// Android-only, opt-in relay of already delivered system cell broadcasts.
/// This is not government-server push or access to an SMS inbox.
class SystemCivilAlertLink with WidgetsBindingObserver {
  static final shared = SystemCivilAlertLink();
  static const _methods = MethodChannel('kr.safekor.app/civil_alerts');
  static const _events = EventChannel('kr.safekor.app/civil_alert_events');
  static const _sources = {
    'com.android.cellbroadcastreceiver',
    'com.google.android.cellbroadcastreceiver',
  };
  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool _started = false;
  Future<Map<String, dynamic>> status() async {
    if (!available) {
      return {
        'enabled': false,
        'accessGranted': false,
        'sourceInstalled': false,
        'canNotify': false,
      };
    }
    return Map<String, dynamic>.from(
      await _methods.invokeMapMethod<String, dynamic>('status') ?? {},
    );
  }

  Future<void> setEnabled(bool enabled) =>
      _methods.invokeMethod('setEnabled', {'enabled': enabled});
  Future<void> openSettings() => _methods.invokeMethod('openSettings');
  void _receive(dynamic raw) {
    if (raw is! Map ||
        raw['source'] != 'system_cell_broadcast' ||
        !_sources.contains(raw['sourcePackage'])) {
      return;
    }
    final kind = AlertKind.fromName(raw['kind']?.toString() ?? '');
    final issued = raw['receivedAtMs'],
        expires = raw['expiresAtMs'],
        id = raw['id'];
    if (kind == null ||
        kind == AlertKind.release ||
        issued is! int ||
        expires is! int ||
        id is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      return;
    }
    CivilAlertIngress.shared.accept(
      CivilAlertNotice(
        id: id,
        revision: '1',
        kind: kind,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(issued, isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true),
        agency: '휴대전화 시스템 재난문자',
        area: '이 휴대전화에 수신된 경보',
      ),
      sourceAuthenticated: true,
      recipientMatched: true,
    );
  }

  Future<void> _pending() async {
    try {
      _receive(await _methods.invokeMethod('pending'));
    } catch (_) {}
  }

  Future<void> start() async {
    if (!available || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _events.receiveBroadcastStream().listen(_receive, onError: (_) {});
    await _pending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pending();
  }
}
