import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/connection_monitor.dart';
import 'package:safe_korea/services/region_suggestion_service.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';

import 'local_store_test.dart' show MemoryStore;
import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

Future<ConnectionMonitor> monitor(bool online) async {
  final m = ConnectionMonitor(
    readLink: () async => online,
    changes: const Stream<void>.empty(),
    probe: () async => online ? true : null,
  )..start();
  // Let the initial link check settle.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return m;
}

void main() {
  for (final online in [true, false]) {
    testWidgets('online-only shelter actions follow connectivity ($online)', (
      tester,
    ) async {
      rootBundle.clear();
      final link = await tester.runAsync(() => monitor(online));
      addTearDown(link!.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SheltersScreen(
            catalog: fixture('11110', '테스트 지역', 'polish'),
            regionService: RegionSuggestionService(lookup: (_, _) async => []),
            savedShelters: SavedSheltersController(store: SavedMemoryStore()),
            monitor: link,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('온라인 지도 열기'), online ? findsOneWidget : findsNothing);
      expect(
        find.text('온라인 지도 · 연결 후 이용'),
        online ? findsNothing : findsOneWidget,
      );
      // One labelled entry to saved shelters, with the count.
      expect(find.text('저장한 대피소 (0곳) · 오프라인 목록'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      expect(find.textContaining('KnellBalm'), findsNothing);
    });
  }

  testWidgets('large text keeps only the usable family action pinned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: FamilyScreen(store: MemoryStore()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기기에 저장'), findsOneWidget);
    // Nothing to share yet: no disabled share button or hint in the bar.
    expect(find.text('가족에게 공유'), findsNothing);
    expect(find.text('장소를 하나 저장하면 공유할 수 있어요.'), findsNothing);
    expect(find.text('내 상태 공유'), findsOneWidget);
  });

  for (final online in [true, false]) {
    testWidgets('saved shelter online map follows connectivity ($online)', (
      tester,
    ) async {
      final link = await tester.runAsync(() => monitor(online));
      addTearDown(link!.dispose);
      final controller = SavedSheltersController(store: SavedMemoryStore());
      await tester.runAsync(controller.load);
      await tester.runAsync(
        () => controller.toggle(fixture('11110', '종로구', 'a'), 'a'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SavedSheltersScreen(controller: controller, monitor: link),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('온라인 지도 보기'), online ? findsOneWidget : findsNothing);
      expect(
        find.text('온라인 지도 · 연결 후 이용'),
        online ? findsNothing : findsOneWidget,
      );
      controller.dispose();
    });
  }
}
