// Test-only HTTP transport. Not imported by lib/ or release entrypoints.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/drill_notifications.dart';

class SyntheticReceiver {
  final Set<String> _delivered = {};

  Future<int> receive(String scenario) async {
    if (!kDebugMode) throw StateError('Synthetic transport requires debug');
    const scenarios = {
      'air',
      'duplicate',
      'other-region',
      'stale',
      'future',
      'weather',
      'release',
    };
    if (!scenarios.contains(scenario)) throw ArgumentError('Unknown scenario');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      // Android uses adb reverse; iOS simulator uses the host loopback.
      final request = await client.getUrl(
        Uri.http('127.0.0.1:8799', '/lab/events', {'scenario': scenario}),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != 200) throw StateError('Lab unavailable');
      final bytes = await response
          .fold<List<int>>([], (all, chunk) {
            if (all.length + chunk.length > 16384) {
              throw StateError('Lab payload too large');
            }
            return all..addAll(chunk);
          })
          .timeout(const Duration(seconds: 3));
      final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (payload['testOnly'] != true) {
        throw StateError('Not a synthetic batch');
      }
      var sent = 0;
      for (final raw in payload['events'] as List) {
        final event = raw as Map<String, dynamic>;
        final id = event['id'] as String;
        final kind = AlertKind.fromName(event['kind'] as String?);
        final expiry = DateTime.tryParse(event['expiresAt'] as String? ?? '');
        if (event['testOnly'] != true ||
            !id.startsWith('lab-') ||
            kind == null ||
            expiry == null ||
            !expiry.isAfter(DateTime.now()) ||
            expiry.difference(DateTime.now()) > const Duration(minutes: 2) ||
            _delivered.contains(id)) {
          continue;
        }
        if (await DrillNotifications.instance.send(
          sound: false,
          vibration: false,
          kind: kind,
        )) {
          _delivered.add(id);
          sent++;
        }
      }
      return sent;
    } finally {
      client.close(force: true);
    }
  }
}
