import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/screens/family_screen.dart';

class MemoryStore extends LocalStore {
  FamilyPlan plan = const FamilyPlan();
  bool failLoad = false, failSave = false;
  @override
  Future<FamilyPlan> load() async {
    if (failLoad) throw StateError('test read failure');
    return plan;
  }

  @override
  Future<void> save(FamilyPlan value) async {
    if (failSave) throw StateError('test write failure');
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
          meetingPoint: MeetingPoint(37.5665, 126.978),
          backupPoint: MeetingPoint(37.57, 126.98),
        ),
      );
      final reloaded = await LocalStore(database: db).load();
      expect(reloaded.meetingPlace, '합의한 장소');
      expect(reloaded.note, '약 챙기기');
      expect(reloaded.meetingPoint!.latitude, 37.5665);
      expect(reloaded.backupPoint!.longitude, 126.98);
      await store.save(const FamilyPlan(contactName: '변경'));
      expect((await db.query('plans')).length, 1);
      expect((await store.load()).phone, isEmpty);
      await store.clear();
      expect((await store.load()).contactName, isEmpty);
    },
  );
  test(
    'catalog cache persists independently without overwriting family plan',
    () async {
      await store.save(const FamilyPlan(contactName: '보존'));
      expect(await store.loadShelterCatalog(), isNull);
      await store.saveShelterCatalog({'coverage': '테스트 지역', 'items': []});
      expect(
        (await LocalStore(database: db).loadShelterCatalog())!['coverage'],
        '테스트 지역',
      );
      expect((await store.load()).contactName, '보존');
      await store.clear();
      expect(await store.loadShelterCatalog(), isNotNull);
    },
  );
  test(
    'old family JSON remains readable and new backup contact persists',
    () async {
      await db.insert('plans', {
        'id': 1,
        'content': '{"contactName":"이전 계획","meetingPlace":"기존 장소"}',
      });
      final old = await store.load();
      expect(old.backupContactName, isEmpty);
      expect(old.meetingPlace, '기존 장소');
      await store.save(
        const FamilyPlan(
          contactName: '주 연락처',
          backupContactName: '추가 연락처',
          backupPhone: '01000000000',
        ),
      );
      expect((await store.load()).backupPhone, '01000000000');
      await store.savePreparation({'water', 'radio'});
      expect(await LocalStore(database: db).loadPreparation(), {
        'water',
        'radio',
      });
      expect((await store.load()).backupContactName, '추가 연락처');
    },
  );
  test(
    'saved shelters persist separately from cache, family plan and readiness',
    () async {
      await store.save(const FamilyPlan(contactName: '유지할 계획'));
      await store.savePreparation({'water'});
      await store.saveSavedShelter('a', {
        'savedAt': '2026-10-31T01:00:00Z',
        'record': 'a',
      });
      await store.saveSavedShelter('b', {
        'savedAt': '2026-10-31T02:00:00Z',
        'record': 'b',
      });
      await store.saveShelterCatalog({'coverage': '새 조회 지역', 'items': []});
      final reopened = LocalStore(database: db);
      expect((await reopened.loadSavedShelters()).length, 2);
      await reopened.removeSavedShelter('a');
      expect((await reopened.loadSavedShelters()).single['record'], 'b');
      expect((await reopened.load()).contactName, '유지할 계획');
      expect(await reopened.loadPreparation(), {'water'});
      expect((await reopened.loadShelterCatalog())!['coverage'], '새 조회 지역');
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
    await tester.enterText(
      find.byKey(const ValueKey('family-field-2')),
      '만남 장소',
    );
    await tester.ensureVisible(find.text('기기에 저장'));
    await tester.tap(find.text('기기에 저장'));
    await tester.pumpAndSettle();
    expect((await memory.load()).meetingPlace, '만남 장소');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장된 계획 삭제'));
    await tester.tap(find.text('저장된 계획 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect((await memory.load()).meetingPlace, '만남 장소');
    await tester.tap(find.text('저장된 계획 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect((await memory.load()).contactName, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsaved family changes are protected when going back', (
    tester,
  ) async {
    final memory = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FamilyScreen(store: memory),
                ),
              ),
              child: const Text('계획 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('계획 열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '아직 저장 안 함');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않은 변경이 있습니다'), findsOneWidget);
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.text('아직 저장 안 함'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('변경 버리고 나가기'));
    await tester.pumpAndSettle();
    expect(find.text('계획 열기'), findsOneWidget);
    expect(memory.plan.contactName, isEmpty);
  });
  testWidgets(
    'read failure blocks overwrite and write failure preserves input',
    (tester) async {
      final memory = MemoryStore()..failLoad = true;
      await tester.pumpWidget(MaterialApp(home: FamilyScreen(store: memory)));
      await tester.pumpAndSettle();
      expect(find.textContaining('기존 내용을 보호하기 위해 저장을 멈췄습니다'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      memory.failLoad = false;
      await tester.tap(find.text('저장 내용 다시 읽기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '보존할 입력');
      memory.failSave = true;
      await tester.ensureVisible(find.text('기기에 저장'));
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '보존할 입력',
      );
      expect(memory.plan.contactName, isEmpty);
    },
  );
}
