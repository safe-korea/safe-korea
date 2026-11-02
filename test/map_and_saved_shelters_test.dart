import 'helpers/map_tiles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/models/shelter_cluster.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/widgets/shelter_map.dart';
import 'package:safe_korea/widgets/shelter_cluster_pin.dart';

Shelter point(String id, double latitude, double longitude) => Shelter(
  id: id,
  name: '테스트 시설 $id',
  address: '테스트 주소 $id',
  latitude: latitude,
  longitude: longitude,
  updatedAt: null,
);
ShelterCatalog fixture(
  String code,
  String label,
  String id, {
  double latitude = 37.5,
}) => ShelterCatalog.fromJson({
  'schemaVersion': 1,
  'sourceName': '테스트 전용 공식 스키마',
  'sourceUrl': officialMapSource,
  'retrievedAt': '2026-10-31T01:02:03Z',
  'areaCode': code,
  'coverage': label,
  'status': 'verified',
  'items': [
    {
      'id': id,
      'name': '테스트 시설 $id',
      'address': '테스트 주소 $id',
      'latitude': latitude,
      'longitude': 127.0,
      'updatedAt': null,
      'status': 'official_listing',
    },
  ],
});

class SavedMemoryStore extends LocalStore {
  final records = <String, Map<String, dynamic>>{};
  bool failRead = false, failWrite = false;
  int writes = 0;
  @override
  Future<List<Map<String, dynamic>>> loadSavedShelters() async {
    if (failRead) throw StateError('test read');
    return records.values.toList();
  }

  @override
  Future<void> saveSavedShelter(String id, Map<String, dynamic> entry) async {
    if (failWrite) throw StateError('test write');
    writes++;
    records[id] = entry;
  }

  @override
  Future<void> saveSavedShelters(List<Map<String, dynamic>> entries) async {
    if (failWrite) throw StateError('test batch write');
    for (final entry in entries) {
      records[entry['storageKey'] as String] = {...entry}..remove('storageKey');
    }
    writes++;
  }

  @override
  Future<void> removeSavedShelter(String id) async {
    if (failWrite) throw StateError('test remove');
    writes++;
    records.remove(id);
  }
}

void main() {
  test('nearby pins group, distant ones remain separate, zoom reveals individual facilities', () {
    final points = [
      point('a', 37.5, 127),
      point('b', 37.501, 127),
      point('far', 37.6, 127),
    ];
    final grouped = clusterShelters(points, 12);
    expect(grouped.map((g) => g.members.length).toList()..sort(), [1, 2]);
    expect(clusterShelters(points, 20).every((g) => g.isSingle), isTrue);
  });
  test('clustering preserves every facility once and is independent of input order', () {
    final points = List.generate(
      120,
      (i) => point('$i', 37.5 + (i % 12) * 0.001, 127 + (i ~/ 12) * 0.001),
    );
    final groups = clusterShelters(points, 15);
    final ids = groups.expand((g) => g.members.map((s) => s.id)).toList();
    expect(ids.length, 120);
    expect(ids.toSet().length, 120);
    expect(
      groups.map((g) => g.members.map((s) => s.id).join(',')).toList(),
      clusterShelters(
        points.reversed.toList(),
        15,
      ).map((g) => g.members.map((s) => s.id).join(',')).toList(),
    );
    expect(clusterShelters([], 14), isEmpty);
    expect(() => clusterShelters(points, double.nan), throwsArgumentError);
  });
  test('saved snapshot preserves original query provenance and rejects unknown facilities', () {
    final original = fixture('11110', '테스트 지역 A', 'a');
    final saved = SavedShelter.fromCatalog(
      original,
      'a',
      DateTime.utc(2026, 10, 31, 8),
    );
    final reloaded = SavedShelter.fromJson(saved.toJson());
    expect(reloaded.snapshot.retrievedAt, '2026-10-31T01:02:03Z');
    expect(reloaded.savedAt, DateTime.utc(2026, 10, 31, 8));
    expect(reloaded.shelter.updatedAt, isNull);
    expect(reloaded.snapshot.coverage, '테스트 지역 A');
    expect(
      () => SavedShelter.fromCatalog(original, 'missing', DateTime.now()),
      throwsFormatException,
    );
  });
  test('saved facilities from multiple regions survive reopening and failures do not alter prior values', () async {
    final store = SavedMemoryStore();
    final controller = SavedSheltersController(store: store);
    await controller.load();
    final a = fixture('11110', '테스트 지역 A', 'a'),
        b = fixture('26110', '테스트 지역 B', 'b', latitude: 35.1);
    expect(await controller.toggle(a, 'a'), isTrue);
    expect(await controller.toggle(b, 'b'), isTrue);
    final reopened = SavedSheltersController(store: store);
    await reopened.load();
    expect(reopened.entries.map((e) => e.shelter.id).toSet(), {'a', 'b'});
    store.failWrite = true;
    expect(await reopened.toggle(a, 'a'), isFalse);
    expect(reopened.entries.length, 2);
    store.failWrite = false;
    store.failRead = true;
    await reopened.load();
    expect(reopened.loaded, isFalse);
    expect(reopened.entries.length, 2);
    final writes = store.writes;
    expect(await reopened.toggle(a, 'a'), isFalse);
    expect(store.writes, writes);
    store.failRead = false;
    await reopened.load();
    expect(await reopened.toggle(a, 'a'), isTrue);
    expect(reopened.entries.single.shelter.id, 'b');
    controller.dispose();
    reopened.dispose();
  });
  testWidgets(
    'same-location cluster can expose a facility list and select the intended shelter',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ShelterMap(
                configuration: const MapConfiguration(nativeAppKey: ''),
                tileProviderFactory: () => FixtureTiles(false),
                shelters: [point('a', 37.5, 127), point('b', 37.5, 127)],
                onSelected: (s) => chosen = s.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShelterClusterPin), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(ShelterClusterPin));
      await tester.pumpAndSettle();
      expect(find.text('대피소 목록 2곳'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('테스트 시설 b'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 시설 b'));
      await tester.pumpAndSettle();
      expect(chosen, 'b');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'save from a query, view offline saved list, remove and synchronize original screen',
    (tester) async {
      final controller = SavedSheltersController(store: SavedMemoryStore());
      final catalog = fixture('11110', '테스트 지역 A', 'a');
      await tester.pumpWidget(
        MaterialApp(
          home: SheltersScreen(catalog: catalog, savedShelters: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('대피소 저장'), findsNothing);
      await tester.ensureVisible(find.text('테스트 시설 a'));
      await tester.tap(find.text('테스트 시설 a'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('대피소 저장'));
      await tester.tap(find.text('대피소 저장'));
      await tester.pumpAndSettle();
      expect(controller.entries.length, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('대피소 저장 해제'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('저장한 대피소 (1)'));
      await tester.pumpAndSettle();
      expect(find.text('테스트 시설 a'), findsOneWidget);
      await tester.ensureVisible(find.text('조회·저장 정보'));
      await tester.tap(find.text('조회·저장 정보'));
      await tester.pumpAndSettle();
      expect(find.text('공식 자료 조회'), findsOneWidget);
      await tester.ensureVisible(find.text('저장 해제'));
      await tester.tap(find.text('저장 해제'));
      await tester.pumpAndSettle();
      expect(controller.entries, isEmpty);
      expect(find.textContaining('저장한 대피소가 아직 없어요'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('저장한 대피소 (0)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
