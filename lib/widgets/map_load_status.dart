import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tracks only tiles currently mounted by the map. Old requests cannot change
/// the state of a new retry attempt.
class MapLoadStatus extends ChangeNotifier {
  MapLoadStatus({this.timeout = const Duration(seconds: 15)});
  final Duration timeout;
  final Set<Object> _pending = {};
  Timer? _timer;
  bool failed = false;
  bool disposed = false;
  int generation = 0;
  bool get loading => _pending.isNotEmpty && !failed;

  void update(
    Object tile,
    int attempt, {
    required bool done,
    required bool error,
  }) {
    if (disposed || attempt != generation) return;
    if (done || error) {
      _pending.remove(tile);
    } else {
      _pending.add(tile);
    }
    if (error) failed = true;
    if (_pending.isEmpty || failed) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer(timeout, () {
        if (disposed) return;
        failed = true;
        _timer = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void remove(Object tile, int attempt) {
    if (disposed || attempt != generation) return;
    _pending.remove(tile);
    if (_pending.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
    notifyListeners();
  }

  void retry() {
    generation++;
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    failed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class ObservedMapTile extends StatefulWidget {
  const ObservedMapTile({
    super.key,
    required this.tile,
    required this.status,
    required this.attempt,
    required this.child,
  });
  final TileImage tile;
  final MapLoadStatus status;
  final int attempt;
  final Widget child;
  @override
  State<ObservedMapTile> createState() => _ObservedMapTileState();
}

class _ObservedMapTileState extends State<ObservedMapTile> {
  @override
  void initState() {
    super.initState();
    widget.tile.addListener(_report);
    _report();
  }

  void _report() {
    final tile = widget.tile, status = widget.status;
    final attempt = widget.attempt;
    scheduleMicrotask(() {
      if (!mounted) return;
      status.update(
        tile,
        attempt,
        done: tile.imageInfo != null,
        error: tile.loadError,
      );
    });
  }

  @override
  void dispose() {
    final tile = widget.tile, status = widget.status;
    final attempt = widget.attempt;
    tile.removeListener(_report);
    scheduleMicrotask(() => status.remove(tile, attempt));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
