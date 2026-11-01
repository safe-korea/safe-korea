import 'dart:async';

import 'package:flutter/material.dart';

/// Elapsed time for this drill session, never a safe evacuation deadline.
class DrillElapsedTimer extends StatefulWidget {
  const DrillElapsedTimer({super.key, this.stopwatch, this.compact = false});
  final Stopwatch? stopwatch;
  final bool compact;

  @override
  State<DrillElapsedTimer> createState() => _DrillElapsedTimerState();
}

class _DrillElapsedTimerState extends State<DrillElapsedTimer>
    with WidgetsBindingObserver {
  late final Stopwatch _watch;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _watch = widget.stopwatch ?? Stopwatch();
    _watch.start();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Read the clock, not a count of callbacks: suspended ticks are not lost.
      setState(() {});
      _startTicker();
    } else {
      _ticker?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _watch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _watch.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Semantics(
      // Do not interrupt spoken guidance every second.
      label:
          '연습 경과 ${elapsed.inMinutes}분 ${elapsed.inSeconds % 60}초. 대피 제한시간이 아닙니다.',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          const Text(
            '연습 경과',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            '$minutes:$seconds',
            key: const ValueKey('drill-elapsed'),
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 16 : 24,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Text(
            '제한시간 아님',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
