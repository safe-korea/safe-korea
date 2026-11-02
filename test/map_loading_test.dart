import 'helpers/map_tiles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/widgets/map_load_status.dart';
import 'package:safe_korea/widgets/shelter_map.dart';

import 'map_and_saved_shelters_test.dart' show point;

void main() {
  testWidgets(
    'stalled tiles time out; retries ignore results from old requests',
    (tester) async {
      final status = MapLoadStatus();
      status.update('a', 0, done: false, error: false);
      expect(status.loading, isTrue);
      await tester.pump(const Duration(seconds: 16));
      expect(status.failed, isTrue);
      status.retry();
      status.update('old', 0, done: false, error: true);
      expect(status.failed, isFalse);
      status.update('new', 1, done: false, error: false);
      status.update('new', 1, done: true, error: false);
      expect(status.loading, isFalse);
      await tester.pump(const Duration(seconds: 16));
      expect(status.failed, isFalse);
      status.dispose();
    },
  );

  testWidgets(
    'partial tile failure remains visible and removed tiles stop waiting',
    (tester) async {
      final status = MapLoadStatus();
      status.update('a', 0, done: false, error: true);
      status.update('b', 0, done: true, error: false);
      expect(status.failed, isTrue);
      status.retry();
      status.update('gone', 1, done: false, error: false);
      status.remove('gone', 1);
      await tester.pump(const Duration(seconds: 16));
      expect(status.failed, isFalse);
      status.update('pending', 1, done: false, error: false);
      status.dispose();
      await tester.pump(const Duration(seconds: 16));
    },
  );

  testWidgets(
    'failed background keeps facility list usable and retry recovers without moving camera',
    (tester) async {
      var fail = true;
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShelterMap(
              configuration: const MapConfiguration(nativeAppKey: ''),
              shelters: [point('a', 37.5, 127)],
              onSelected: (s) => selected = s.id,
              tileProviderFactory: () => FixtureTiles(fail),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('지도 배경 일부 또는 전체'), findsOneWidget);
      await tester.tap(find.text('시설 목록 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 시설 a'));
      await tester.pumpAndSettle();
      expect(selected, 'a');
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;
      fail = false;
      await tester.tap(find.text('지도 다시 시도'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('지도 다시 시도'), findsNothing);
      expect(find.textContaining('지도 배경 불러오는 중'), findsNothing);
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
