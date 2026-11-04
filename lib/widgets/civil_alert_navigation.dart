import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';

import '../services/civil_alert_ingress.dart';
import '../screens/civil_alert_screen.dart';

class CivilAlertNavigation extends StatefulWidget {
  const CivilAlertNavigation({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.notices,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Stream<CivilAlertNotice>? notices;
  final Widget child;

  /// The most recent received alert (official within [CivilAlertNotice.recentWindow],
  /// tests until their short expiry), or null.
  static ValueListenable<CivilAlertNotice?> recentOf(BuildContext context) =>
      context
          .findAncestorStateOfType<_CivilAlertNavigationState>()
          ?._recent ??
      _none;
  static final _none = ValueNotifier<CivilAlertNotice?>(null);

  /// Reopen the response screen for an already received alert.
  static void reopen(BuildContext context, CivilAlertNotice notice) => context
      .findAncestorStateOfType<_CivilAlertNavigationState>()
      ?._show(notice);

  @override
  State<CivilAlertNavigation> createState() => _CivilAlertNavigationState();
}

class _CivilAlertNavigationState extends State<CivilAlertNavigation>
    with WidgetsBindingObserver {
  StreamSubscription<CivilAlertNotice>? _subscription;
  ValueNotifier<CivilAlertNotice>? _visible;
  CivilAlertNotice? _pending;
  bool _foreground = true;
  final _recent = ValueNotifier<CivilAlertNotice?>(null);
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
    _expiry = Timer.periodic(const Duration(seconds: 30), (_) => _prune());
  }

  void _prune() {
    final current = _recent.value;
    if (current != null && !current.recentAt(DateTime.now())) {
      _recent.value = null;
    }
  }

  void _remember(CivilAlertNotice notice) {
    if (notice.kind == AlertKind.release) {
      _recent.value = null;
    } else if (notice.recentAt(DateTime.now())) {
      _recent.value = notice;
    }
  }

  void _listen() {
    _subscription = (widget.notices ?? CivilAlertIngress.shared.notices).listen(
      _receive,
    );
    if (widget.notices == null &&
        CivilAlertIngress.shared.latestAccepted != null) {
      final initial = CivilAlertIngress.shared.latestAccepted!;
      scheduleMicrotask(() {
        if (mounted) _receive(initial);
      });
    }
  }

  @override
  void didUpdateWidget(CivilAlertNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notices != widget.notices) {
      _subscription?.cancel();
      _listen();
    }
  }

  void _receive(CivilAlertNotice notice) {
    _remember(notice);
    // Only fresh alerts open the screen by themselves; older ones stay on home.
    if (!notice.freshAt(DateTime.now())) return;
    if (!_foreground) {
      _pending = notice;
      return;
    }
    _show(notice, requireFresh: true);
  }

  void _show(CivilAlertNotice notice, {bool requireFresh = false}) {
    bool usable() => requireFresh
        ? notice.freshAt(DateTime.now())
        : notice.recentAt(DateTime.now());
    if (!usable()) return;
    if (_visible != null) {
      _visible!.value = notice;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !usable()) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      if (_visible != null) {
        _visible!.value = notice;
        return;
      }
      final value = ValueNotifier(notice);
      _visible = value;
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder<CivilAlertNotice>(
                valueListenable: value,
                builder: (context, event, _) => CivilAlertScreen(notice: event),
              ),
            ),
          )
          .whenComplete(() {
            if (_visible == value) _visible = null;
            value.dispose();
          });
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _pending != null) {
      final notice = _pending!;
      _pending = null;
      _receive(notice);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _expiry?.cancel();
    _recent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
