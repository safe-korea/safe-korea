import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';
import 'package:safe_korea/services/system_civil_alert_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native relay drops foreign sources, unknown kinds, releases, stale events and duplicates', () async {
    final received = <CivilAlertNotice>[];
    final subscription = CivilAlertIngress.shared.notices.listen(received.add);
    const method = MethodChannel('kr.safekor.app/civil_alerts');
    const event = MethodChannel('kr.safekor.app/civil_alert_events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(method, (call) async => null);
    messenger.setMockMethodCallHandler(event, (call) async => null);
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = <String, Object>{
      'source': 'system_cell_broadcast',
      'sourcePackage': 'com.android.cellbroadcastreceiver',
      'id': 'a' * 64,
      'kind': 'air',
      'receivedAtMs': now,
      'expiresAtMs': now + 120000,
    };
    await SystemCivilAlertLink.shared.start();
    Future<void> send(Map<String, Object> payload) async {
      await messenger.handlePlatformMessage(
        'kr.safekor.app/civil_alert_events',
        const StandardMethodCodec().encodeSuccessEnvelope(payload),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
    }

    await send({...record, 'sourcePackage': 'kr.safekor.app'});
    await send({...record, 'source': 'external_push'});
    await send({...record, 'kind': 'unknown'});
    await send({...record, 'kind': 'release'});
    await send({
      ...record,
      'receivedAtMs': now - 1200000,
      'expiresAtMs': now - 1000,
    });
    await send({...record, 'id': 'invalid'});
    expect(received, isEmpty);
    await send(record);
    await send(record);
    expect(received, hasLength(1));
    expect(received.single.agency, '휴대전화 시스템 재난문자');
    await subscription.cancel();
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(event, null);
  });
}
