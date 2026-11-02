import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

const shelterApiBaseUrl = String.fromEnvironment('SHELTER_API_BASE_URL');

enum LinkStatus { unknown, available, offline, limited }

extension LinkStatusTools on LinkStatus {
  bool get needsOfflineTools =>
      this == LinkStatus.offline || this == LinkStatus.limited;
}

/// Link absence and failure of our data service are deliberately distinct.
/// No polling, location, identifiers or third-party connectivity probes.
class ConnectionMonitor extends ValueNotifier<LinkStatus>
    with WidgetsBindingObserver {
  ConnectionMonitor({
    required this.readLink,
    required this.changes,
    required this.probe,
  }) : super(LinkStatus.unknown);
  final Future<bool> Function() readLink;
  final Stream<void> changes;
  final Future<bool?> Function() probe;
  StreamSubscription<void>? _subscription;
  Timer? _debounce;
  int _generation = 0;
  bool _started = false, _disposed = false, _active = true;

  static final instance = _production();
  static ConnectionMonitor _production() {
    final connectivity = Connectivity();
    return ConnectionMonitor(
      readLink: () async => (await connectivity.checkConnectivity()).any(
        (kind) => kind != ConnectivityResult.none,
      ),
      changes: connectivity.onConnectivityChanged.map<void>((_) {}),
      probe: () async {
        if (shelterApiBaseUrl.isEmpty) return null;
        final base = Uri.parse(shelterApiBaseUrl);
        if (base.scheme != 'https') return null;
        final client = http.Client();
        try {
          final response = await client
              .get(base.resolve('/health'))
              .timeout(const Duration(seconds: 4));
          if (response.statusCode != 200 || response.bodyBytes.length > 4096) {
            return false;
          }
          final data = jsonDecode(response.body);
          return data is Map &&
              data['service'] == 'safe-korea-shelter-api' &&
              data['status'] == 'ok';
        } finally {
          client.close();
        }
      },
    );
  }

  void reportServiceFailure() {
    if (_started && !_disposed && value != LinkStatus.offline) {
      _generation++;
      value = LinkStatus.limited;
    }
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = changes.listen(
      (_) => _schedule(),
      onError: (Object _) {
        // Detection failure must never be represented as verified disconnection.
        if (!_disposed) {
          _generation++;
          value = LinkStatus.unknown;
        }
      },
    );
    unawaited(refresh());
  }

  void _schedule() {
    _generation++;
    _debounce?.cancel();
    if (_active) _debounce = Timer(const Duration(milliseconds: 700), refresh);
  }

  Future<void> refresh() async {
    if (_disposed || !_active) return;
    final generation = ++_generation;
    LinkStatus next;
    try {
      final linked = await readLink().timeout(const Duration(seconds: 4));
      if (_disposed || generation != _generation) return;
      if (!linked) {
        next = LinkStatus.offline;
      } else {
        try {
          final reachable = await probe().timeout(const Duration(seconds: 5));
          next = reachable == false ? LinkStatus.limited : LinkStatus.available;
        } catch (_) {
          next = LinkStatus.limited;
        }
      }
    } catch (_) {
      next = LinkStatus.unknown;
    }
    if (!_disposed && generation == _generation) value = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _generation++;
    _debounce?.cancel();
    if (_active) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    _subscription?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
