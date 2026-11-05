import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_korea/services/local_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('district map larger than the SQLite row window round-trips', () async {
    final store = LocalStore();
    await store.removeAreaMap();
    expect(await store.loadAreaMap(), isNull);
    // ~3.5MB: above Android's 2MB CursorWindow that broke table storage.
    final features = [
      for (var i = 0; i < 40000; i++)
        {
          'id': '$i',
          'kind': 'road',
          'points': [
            [126.9 + i * 1e-6, 37.5],
            [126.91, 37.51],
          ],
        },
    ];
    await store.saveAreaMap({
      'schemaVersion': 1,
      'region': {'code': '11110', 'name': '서울특별시 종로구'},
      'map': {'features': features},
    });
    final back = await store.loadAreaMap();
    expect((back!['map'] as Map)['features'], hasLength(40000));
    await store.saveAreaMap({
      'schemaVersion': 1,
      'region': {'code': '11140', 'name': '서울특별시 중구'},
      'map': {'features': <Object>[]},
    });
    expect(((await store.loadAreaMap())!['region'] as Map)['code'], '11140');
    await store.removeAreaMap();
    expect(await store.loadAreaMap(), isNull);
  });
}
