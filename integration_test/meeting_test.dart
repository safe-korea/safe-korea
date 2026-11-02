import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'dart:io';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('public fixture meeting map and isolated SQLite persistence', (
    tester,
  ) async {
    if (Platform.isIOS) {
      await const MethodChannel('kr.example.safe_korea/privacy')
          .invokeMethod<void>('excludeFamilyBackup');
    }
    final dbPath = path.join(
      await getDatabasesPath(),
      'safe_korea_meeting_integration_only.db',
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
      await db.delete('plans'); // This database belongs only to this test.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: FamilyScreen(key: const ValueKey('empty-plan'), store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
      expect(find.text('장소를 하나 저장하면 공유할 수 있어요.'), findsOneWidget);
      if (Platform.isIOS) await binding.takeScreenshot('family-empty');
      await store.save(
        const FamilyPlan(
          contactName: 'legacy fixture',
          phone: 'test-only',
          meetingPlace: '서울시청 앞 · 테스트 장소',
          backupPlace: '광화문 광장 · 테스트 장소',
          meetingPoint: MeetingPoint(37.5665, 126.978),
          backupPoint: MeetingPoint(37.5725, 126.9769),
          note: '공개 장소 좌표를 사용한 테스트 계획입니다.',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: FamilyScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isIOS) await binding.takeScreenshot('family-meeting');
      await tester.ensureVisible(find.text('만남 장소 수정'));
      await tester.tap(find.text('만남 장소 수정'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('첫 번째 장소 지도에서 지정'));
      await tester.tap(find.text('첫 번째 장소 지도에서 지정'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 && find.text('지도 불러오는 중…').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('지도 배경을 불러오지 못했습니다'), findsNothing);
      await tester.tap(find.text('지도 중앙에 핀 놓기'));
      await tester.pumpAndSettle();
      if (Platform.isIOS) await binding.takeScreenshot('family-meeting-map');
      await tester.tap(find.text('이 위치 선택'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('기기에 저장'));
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      await db.close();
      db = await openDatabase(dbPath);
      final saved = await LocalStore(database: db).load();
      expect(saved.meetingPoint!.latitude, closeTo(37.5665, .00001));
      expect(saved.backupPoint!.longitude, 126.9769);
      expect(saved.contactName, 'legacy fixture');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await db?.close();
      await deleteDatabase(dbPath);
    }
  });
}
