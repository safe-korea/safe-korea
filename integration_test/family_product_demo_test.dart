import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture loaded family plan and sharing without sending', (
    tester,
  ) async {
    final db = await openDatabase(
      path.join(
        await getDatabasesPath(),
        'family_capture_${DateTime.now().millisecondsSinceEpoch}.db',
      ),
    );
    await db.execute(
      'CREATE TABLE plans (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
    );
    final store = LocalStore(database: db);
    await store.save(
      const FamilyPlan(
        meetingPlace: '잠실역 2번 출구 앞 · 시연용 약속',
        backupPlace: '송파구청 앞 · 시연용 약속',
        note: '연락이 되면 서로 위치를 확인해요.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: FamilyScreen(store: store),
      ),
    );
    for (var i = 0; i < 50 && find.text('가족에게 공유').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('잠실역 2번 출구 앞 · 시연용 약속'), findsOneWidget);
    await binding.takeScreenshot('full-demo-family-loaded');
    debugPrint('FAMILY_READY_RECORD');
    await Future<void>.delayed(const Duration(seconds: 9));
    await tester.ensureVisible(find.text('가족에게 공유'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가족에게 공유'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('full-demo-share-preview');
    debugPrint('FAMILY_PREVIEW_RECORD');
    await Future<void>.delayed(const Duration(seconds: 7));
    await tester.tap(find.text('카카오톡 등으로 공유'));
    await tester.pumpAndSettle();
    debugPrint('FAMILY_SHEET_RECORD');
    await Future<void>.delayed(const Duration(seconds: 7));
    expect(find.textContaining('공유 창을 열지 못했습니다'), findsNothing);
    debugPrint('FAMILY_CAPTURE_COMPLETE');
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
