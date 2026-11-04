import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/shelter_photo_importer.dart';
import 'package:safe_korea/screens/shelter_record_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';

import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgaHD4DwADBAHAqetaQwAAAABJRU5ErkJggg==';
ShelterPhoto photo() =>
    ShelterPhoto(data: png, addedAt: DateTime.utc(2026, 11, 1));

class PhotoFixture extends ShelterPhotoImporter {
  bool fail = false;
  ShelterPhoto? result = photo();
  @override
  Future<ShelterPhoto?> pick() async {
    if (fail) throw StateError('fixture');
    return result;
  }

  @override
  Future<ShelterPhoto?> recover() async => null;
}

Future<SavedSheltersController> controller(SavedMemoryStore store) async {
  final c = SavedSheltersController(store: store);
  await c.load();
  await c.toggle(fixture('11110', '서울', 'a'), 'a');
  return c;
}

void main() {
  test(
    'reference maps retain source through reload and official refresh',
    () async {
      final store = SavedMemoryStore();
      final c = await controller(store);
      final entry = c.entries.single;
      final map = ShelterPhoto(
        data: png,
        addedAt: DateTime.utc(2026, 11, 2),
        mapSource: '직접 만든 약도',
      );
      expect(
        await c.savePersonal(entry.key, ShelterRole.primary, '', [map]),
        isTrue,
      );
      final reloaded = SavedSheltersController(store: store);
      await reloaded.load();
      final restored = SavedShelter.fromJson(
        reloaded.entries.single
            .withCheck(entry.snapshot, DateTime.now(), ShelterCheck.confirmed)
            .toJson(),
      );
      expect(restored.photos.single.mapSource, '직접 만든 약도');
      expect(restored.photos.single.data, png);
      expect(ShelterPhoto.fromJson(photo().toJson()).isReferenceMap, isFalse);
      expect(
        await c.savePersonal(entry.key, ShelterRole.none, '', [
          ShelterPhoto(data: png, addedAt: DateTime.now(), mapSource: ' '),
        ]),
        isFalse,
      );
      expect(c.entries.single.photos.single.mapSource, '직접 만든 약도');
    },
  );

  testWidgets(
    'reference map requires source and opens offline without expanding records',
    (tester) async {
      final c = await controller(SavedMemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          home: ShelterRecordScreen(
            entry: c.entries.single,
            controller: c,
            importer: PhotoFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.text('오프라인 약도 이미지 추가');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('이미지 선택'));
      await tester.pumpAndSettle();
      expect(find.text('출처를 입력해 주세요.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '직접 만든 약도');
      await tester.tap(find.text('이미지 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      await c.load();
      expect(c.entries.single.photos.single.mapSource, '직접 만든 약도');
      await tester.pumpWidget(
        MaterialApp(home: SavedSheltersScreen(controller: c)),
      );
      await tester.pumpAndSettle();
      final open = find.text('저장한 약도 크게 보기');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('저장한 약도 1'), findsOneWidget);
      expect(find.textContaining('지도 갱신일 아님'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('legacy record loads without personal data; official refresh retains personal data', () {
    final initial = SavedShelter.fromCatalog(
      fixture('11110', '서울', 'a'),
      'a',
      DateTime.now(),
    );
    final raw = initial.toJson()
      ..remove('role')
      ..remove('photos')
      ..remove('entranceNote');
    expect(SavedShelter.fromJson(raw).role, ShelterRole.none);
    final edited = initial.withPersonal(
      role: ShelterRole.primary,
      note: '뒤편 계단',
      photos: [photo()],
    );
    final refreshed = edited.withCheck(
      edited.snapshot,
      DateTime.now(),
      ShelterCheck.confirmed,
    );
    final restored = SavedShelter.fromJson(refreshed.toJson());
    expect(restored.entranceNote, '뒤편 계단');
    expect(restored.photos.single.data, png);
    expect(restored.role, ShelterRole.primary);
    expect(restored.snapshot.toJson().containsKey('photos'), isFalse);
  });
  test(
    'priority reassignment is unique and failure keeps both previous records',
    () async {
      final store = SavedMemoryStore();
      final c = await controller(store);
      final a = c.entries.single;
      await c.toggle(fixture('26110', '부산', 'b'), 'b');
      final b = c.entries.firstWhere((e) => e.shelter.id == 'b');
      expect(
        await c.savePersonal(a.key, ShelterRole.primary, '계단', [photo()]),
        isTrue,
      );
      store.failWrite = true;
      expect(await c.savePersonal(b.key, ShelterRole.primary, '', []), isFalse);
      expect(c.entries.first.key, a.key);
      store.failWrite = false;
      expect(await c.savePersonal(b.key, ShelterRole.primary, '', []), isTrue);
      expect(c.entries.first.key, b.key);
      expect(
        c.entries.where((e) => e.role == ShelterRole.primary),
        hasLength(1),
      );
      expect(c.entries.last.photos, hasLength(1));
      await c.load();
      expect(c.entries.first.key, b.key);
      expect(
        await c.savePersonal(a.key, ShelterRole.alternate, '계단', [photo()]),
        isTrue,
      );
      expect(c.entries.map((e) => e.role), [
        ShelterRole.primary,
        ShelterRole.alternate,
      ]);
    },
  );
  test('SQLite personal photos survive reopening and are removed with saved shelter', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final store = LocalStore(database: db);
    final c = SavedSheltersController(store: store);
    await c.load();
    await c.toggle(fixture('11110', '서울', 'a'), 'a');
    final a = c.entries.single;
    await c.savePersonal(a.key, ShelterRole.primary, '문 옆', [
      photo(),
      ShelterPhoto(
        data: png,
        addedAt: DateTime.utc(2026, 11, 2),
        mapSource: '직접 만든 약도',
      ),
    ]);
    final reloaded = SavedSheltersController(store: LocalStore(database: db));
    await reloaded.load();
    expect(reloaded.entries.single.photos.first.data, png);
    expect(reloaded.entries.single.photos.last.mapSource, '직접 만든 약도');
    expect(reloaded.entries.single.entranceNote, '문 옆');
    await reloaded.toggle(a.snapshot, a.shelter.id);
    expect(await store.loadSavedShelters(), isEmpty);
  });
  test(
    'SQLite reassignment transaction rolls back if second write fails',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final store = LocalStore(database: db);
      final a = SavedShelter.fromCatalog(
        fixture('11110', '서울', 'a'),
        'a',
        DateTime.now(),
      );
      await store.saveSavedShelter(a.key, a.toJson());
      await expectLater(
        store.saveSavedShelters([
          {
            ...a
                .withPersonal(role: ShelterRole.primary, note: '변경', photos: [])
                .toJson(),
            'storageKey': a.key,
          },
          {'storageKey': 'broken'},
        ]),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        SavedShelter.fromJson((await store.loadSavedShelters()).single)
            .entranceNote,
        isEmpty,
      );
    },
  );
  testWidgets(
    'photo picker cancel and failure preserve draft; saving and reopening keeps local photo',
    (tester) async {
      final store = SavedMemoryStore();
      final c = await controller(store);
      final picker = PhotoFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ShelterRecordScreen(
            entry: c.entries.single,
            controller: c,
            importer: picker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '뒤편 출입구');
      final add = find.text('사진 보관함에서 선택');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('내 사진 1/3'), findsOneWidget);
      picker.result = null;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('내 사진 1/3'), findsOneWidget);
      picker.fail = true;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.textContaining('사진을 가져오지 못했습니다'), findsOneWidget);
      store.failWrite = true;
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      expect(c.entries.single.photos, isEmpty);
      store.failWrite = false;
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      expect(c.entries.single.photos.single.data, png);
      await tester.pumpWidget(
        MaterialApp(home: SavedSheltersScreen(controller: c)),
      );
      await tester.pumpAndSettle();
      expect(find.text('뒤편 출입구'), findsOneWidget);
      await tester.ensureVisible(find.text('내 기록 · 선택'));
      await tester.tap(find.text('내 기록 · 선택'));
      await tester.pumpAndSettle();
      expect(find.text('사진 1 크게 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('removal confirmation preserves photos when cancelled', (
    tester,
  ) async {
    final c = await controller(SavedMemoryStore());
    final e = c.entries.single;
    await c.savePersonal(e.key, ShelterRole.primary, '메모', [photo()]);
    await tester.pumpWidget(
      MaterialApp(home: SavedSheltersScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('조회·저장 정보'));
    await tester.tap(find.text('조회·저장 정보'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장 해제'));
    await tester.tap(find.text('저장 해제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사진·메모·우선순위도 삭제'), findsOneWidget);
    await tester.tap(find.text('유지하기'));
    await tester.pumpAndSettle();
    expect(c.entries.single.photos, hasLength(1));
  });
  testWidgets('narrow enlarged text record screen has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await controller(SavedMemoryStore());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: ShelterRecordScreen(
          entry: c.entries.single,
          controller: c,
          importer: PhotoFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('사진 보관함에서 선택'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('photo import decodes image and rejects non-image bytes', (
    tester,
  ) async {
    final importer = ShelterPhotoImporter();
    final image = await tester.runAsync(
      () => importer.decode(XFile.fromData(base64Decode(png))),
    );
    expect(image!.data, isNotEmpty);
    await tester.runAsync(() async {
      await expectLater(
        importer.decode(XFile.fromData(Uint8List.fromList([1, 2, 3]))),
        throwsA(anything),
      );
    });
  });
}
