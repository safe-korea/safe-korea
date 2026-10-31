import 'package:flutter/material.dart';
import 'package:safe_korea/widgets/shelter_pin.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/widgets/shelter_cluster_pin.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/shelter_repository.dart';
import 'package:safe_korea/services/local_store.dart';

// Explicit live diagnostic: one regional request, no nationwide crawling.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'official Jongno response appears on map and reopens from SQLite',
    (tester) async {
      final dbPath = path.join(
        await getDatabasesPath(),
        'safe_korea_shelter_integration_only.db',
      );
      final db = await openDatabase(dbPath);
      final store = LocalStore(database: db);
      final repository = ShelterRepository(store: store);
      final saved = SavedSheltersController(store: store);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: SheltersScreen(repository: repository, savedShelters: saved),
          ),
        );
        await tester.pumpAndSettle();
        if (find.text('지역 변경').evaluate().isNotEmpty) {
          await tester.ensureVisible(find.text('지역 변경'));
          await tester.tap(find.text('지역 변경'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
        await tester.tap(find.text('선택 지역 대피소 불러오기'));
        await tester.pump();
        for (
          var i = 0;
          i < 30 && find.text('공식 시설 조회 중…').evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.textContaining('건을 받아 기기에 저장했습니다'), findsOneWidget);
        final catalog = await repository.cached();
        expect(catalog, isNotNull);
        expect(catalog!.areaCode, '11110');
        expect(catalog.shelters.length, greaterThan(5));
        expect(catalog.shelters.first.updatedAt, isNull);
        await tester.ensureVisible(find.text('온라인 지도 열기'));
        await tester.tap(find.text('온라인 지도 열기'));
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byWidgetPredicate(
            (widget) => widget is ShelterPin || widget is ShelterClusterPin,
          ),
          findsWidgets,
        );
        await tester.ensureVisible(find.text('대피소 저장').first);
        await tester.tap(find.text('대피소 저장').first);
        await tester.pumpAndSettle();
        expect(saved.entries.length, 1);
        await saved.refresh(saved.entries.single, repository);
        expect(
          saved.entries.single.check,
          anyOf(ShelterCheck.confirmed, ShelterCheck.changed),
        );
        final reopenedSaved = SavedSheltersController(store: store);
        await reopenedSaved.ensureLoaded();
        expect(
          reopenedSaved.entries.single.shelter.id,
          saved.entries.single.shelter.id,
        );
        expect(
          reopenedSaved.entries.single.snapshot.retrievedAt,
          saved.entries.single.snapshot.retrievedAt,
        );
        reopenedSaved.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: SheltersScreen(repository: repository, savedShelters: saved),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('현재 표시 범위: 서울특별시 종로구'), findsOneWidget);
        expect(
          (await repository.cached())!.shelters.length,
          catalog.shelters.length,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        saved.dispose();
        repository.close();
        await db.close();
        await deleteDatabase(dbPath);
      }
    },
  );
}
