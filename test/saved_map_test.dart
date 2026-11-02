import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/saved_map_downloader.dart';

import 'map_and_saved_shelters_test.dart' show SavedMemoryStore, fixture;

class TestMaps extends SavedMapDownloader {
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> fetch(Shelter shelter) async {
    calls++;
    if (fail) throw StateError('offline');
    return {
      'schemaVersion': 1,
      'bounds': [126.99, 37.49, 127.01, 37.51],
      'features': [],
      'license': 'ODbL 1.0',
    };
  }
}

void main() {
  test('only saving downloads map; reload and personal edits preserve map; removal clears it', () async {
    final store = SavedMemoryStore(), maps = TestMaps();
    final c = SavedSheltersController(store: store, maps: maps);
    await c.load();
    expect(maps.calls, 0);
    final catalog = fixture('11110', 'test', 'one');
    await c.toggle(catalog, 'one');
    expect(maps.calls, 1);
    final next = SavedSheltersController(store: store, maps: maps);
    await next.load();
    expect(maps.calls, 1);
    expect(next.entries.single.offlineMap, isNotNull);
    await next.savePersonal(
      next.entries.single.key,
      ShelterRole.primary,
      '메모',
      [],
    );
    expect(
      SavedShelter.fromJson(store.records.values.single).offlineMap,
      isNotNull,
    );
    await next.toggle(catalog, 'one');
    expect(store.records, isEmpty);
    expect(maps.calls, 1);
  });
  test(
    'map failure preserves facility and can retry without duplicating it',
    () async {
      final store = SavedMemoryStore(), maps = TestMaps()..fail = true;
      final c = SavedSheltersController(store: store, maps: maps);
      await c.load();
      expect(await c.toggle(fixture('11110', 'test', 'one'), 'one'), isTrue);
      expect(c.entries.single.offlineMap, isNull);
      expect(c.mapMessage, contains('지도는 저장하지 못했어요'));
      maps.fail = false;
      await c.retryMap(c.entries.single);
      expect(c.entries, hasLength(1));
      expect(c.entries.single.offlineMap, isNotNull);
    },
  );
}
