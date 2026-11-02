import 'dart:async';

import 'package:flutter/material.dart';

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
  @override
  State<CivilAlertNavigation> createState() => _CivilAlertNavigationState();
}

class _CivilAlertNavigationState extends State<CivilAlertNavigation>
    with WidgetsBindingObserver {
  StreamSubscription<CivilAlertNotice>? _subscription;
  ValueNotifier<CivilAlertNotice>? _visible;
  CivilAlertNotice? _pending;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
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
    if (!notice.freshAt(DateTime.now())) return;
    if (!_foreground) {
      _pending = notice;
      return;
    }
    if (_visible != null) {
      _visible!.value = notice;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !notice.freshAt(DateTime.now())) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
