import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/connection_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('no link needs no HTTP probe; service failure is distinct and recovery works', () async {
    var linked = false, reachable = false, probes = 0;
    final monitor = ConnectionMonitor(
      readLink: () async => linked,
      changes: const Stream.empty(),
      probe: () async {
        probes++;
        return reachable;
      },
    );
    addTearDown(monitor.dispose);
    await monitor.refresh();
    expect(monitor.value, LinkStatus.offline);
    expect(probes, 0);
    linked = true;
    await monitor.refresh();
    expect(monitor.value, LinkStatus.limited);
    reachable = true;
    await monitor.refresh();
    expect(monitor.value, LinkStatus.available);
  });
  test('a late successful probe cannot erase a newer offline state', () async {
    var linked = true;
    final response = Completer<bool?>();
    final entered = Completer<void>();
    final monitor = ConnectionMonitor(
      readLink: () async => linked,
      changes: const Stream.empty(),
      probe: () {
        entered.complete();
        return response.future;
      },
    );
    addTearDown(monitor.dispose);
    final old = monitor.refresh();
    await entered.future;
    linked = false;
    await monitor.refresh();
    response.complete(true);
    await old;
    expect(monitor.value, LinkStatus.offline);
  });
  test(
    'platform failure is unknown rather than verified disconnection',
    () async {
      final monitor = ConnectionMonitor(
        readLink: () async => throw Exception('platform'),
        changes: const Stream.empty(),
        probe: () async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      expect(monitor.value, LinkStatus.unknown);
    },
  );
}
