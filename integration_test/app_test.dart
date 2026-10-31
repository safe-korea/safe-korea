import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/screens/family_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native offline drill, guidance and isolated SQLite plan', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('모의 공습경보 시작'));
    await tester.pumpAndSettle();
    expect(find.text('훈련 / 테스트'), findsOneWidget);
    await tester.ensureVisible(find.text('훈련 종료 · 홈으로'));
    await tester.tap(find.text('훈련 종료 · 홈으로'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('상황별 행동강령'));
    await tester.tap(find.text('상황별 행동강령'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오프라인 저장됨'), findsOneWidget);
    await tester.tap(find.text('공습경보'));
    await tester.pumpAndSettle();
    expect(find.textContaining('엘리베이터를 피하세요'), findsOneWidget);

    if (Platform.isIOS) {
      await const MethodChannel('kr.example.safe_korea/privacy')
          .invokeMethod<void>('excludeFamilyBackup');
    }
    // Test a separate database: never touch a user's actual family plan.
    final dbPath = path.join(
      await getDatabasesPath(),
      'safe_korea_integration_only.db',
    );
    Database? db;
    try {
      db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE plans (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
        ),
      );
      final store = LocalStore(database: db);
      await tester.pumpWidget(MaterialApp(home: FamilyScreen(store: store)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '테스트 연락처');
      await tester.enterText(find.byType(TextField).at(2), '테스트 만남 장소');
      await tester.ensureVisible(find.text('기기에 저장'));
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이 기기에 저장했습니다'), findsOneWidget);
      await db.close();
      db = await openDatabase(dbPath);
      expect((await LocalStore(database: db).load()).meetingPlace, '테스트 만남 장소');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await db?.close();
      await deleteDatabase(dbPath);
    }
  });
}
