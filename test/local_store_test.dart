import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/screens/family_screen.dart';

class MemoryStore extends LocalStore {
  FamilyPlan plan = const FamilyPlan();
  @override
  Future<FamilyPlan> load() async => plan;
  @override
  Future<void> save(FamilyPlan value) async {
    plan = value;
  }

  @override
  Future<void> clear() async {
    plan = const FamilyPlan();
  }
}

void main() {
  late Database db;
  late LocalStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE plans (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
        ),
      ),
    );
    store = LocalStore(database: db);
  });
  tearDown(() async => db.close());
  test(
    'SQLite persists Korean plan across store instances, replaces and deletes',
    () async {
      expect((await store.load()).phone, isEmpty);
      await store.save(
        const FamilyPlan(
          contactName: '가족',
          phone: '01012345678',
          meetingPlace: '합의한 장소',
          note: '약 챙기기',
        ),
      );
      final reloaded = await LocalStore(database: db).load();
      expect(reloaded.meetingPlace, '합의한 장소');
      expect(reloaded.note, '약 챙기기');
      await store.save(const FamilyPlan(contactName: '변경'));
      expect((await db.query('plans')).length, 1);
      expect((await store.load()).phone, isEmpty);
      await store.clear();
      expect((await store.load()).contactName, isEmpty);
    },
  );
  testWidgets('family form saves locally and confirms deletion', (
    tester,
  ) async {
    final memory = MemoryStore();
    await tester.pumpWidget(MaterialApp(home: FamilyScreen(store: memory)));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '가족');
    await tester.enterText(find.byType(TextField).at(2), '만남 장소');
    await tester.ensureVisible(find.text('기기에 저장'));
    await tester.tap(find.text('기기에 저장'));
    await tester.pumpAndSettle();
    expect((await memory.load()).meetingPlace, '만남 장소');
    await tester.ensureVisible(find.text('저장된 계획 삭제'));
    await tester.tap(find.text('저장된 계획 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect((await memory.load()).contactName, '가족');
    await tester.tap(find.text('저장된 계획 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect((await memory.load()).contactName, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
