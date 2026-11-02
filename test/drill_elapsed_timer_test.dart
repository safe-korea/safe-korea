import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/widgets/drill_elapsed_timer.dart';

class TestWatch extends Stopwatch {
  Duration value = Duration.zero;
  bool stopped = false;
  @override
  Duration get elapsed => value;
  @override
  void start() {}
  @override
  void stop() => stopped = true;
}

void main() {
  testWidgets('elapsed clock reads actual duration and catches up on resume', (
    tester,
  ) async {
    final watch = TestWatch();
    await tester.pumpWidget(
      MaterialApp(home: DrillElapsedTimer(stopwatch: watch)),
    );
    expect(find.text('00:00'), findsOneWidget);
    watch.value = const Duration(seconds: 65);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:05'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    watch.value = const Duration(minutes: 71, seconds: 9);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('01:05'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('71:09'), findsOneWidget);
    expect(find.text('대피 여유시간 아님'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(watch.stopped, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
