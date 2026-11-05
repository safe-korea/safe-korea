import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/screens/meeting_share_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/location_service.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'local_store_test.dart' show MemoryStore;
import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;
import 'region_and_refresh_test.dart' show RefreshRepository;

class DeniedLocation extends LocationService {
  int calls = 0;
  @override
  Future<Position> current() async {
    calls++;
    throw const LocationFailure('위치 권한 없이도 시설 검색과 행동강령을 이용할 수 있어요.');
  }
}

void main() {
  setUp(() => rootBundle.clear());
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'P1 first-time commuter reaches immediate action and returns home',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      );
      await tap(tester, '모의 공습경보 시작');
      expect(find.text('지금 즉시 대피하세요').hitTestable(), findsOneWidget);
      expect(find.text('훈련 / 테스트'), findsOneWidget);
      expect(find.text('대피 여유시간 아님'), findsOneWidget);
      await tap(tester, '실외');
      expect(find.text('가까운 건물로 대피'), findsOneWidget);
      await tap(tester, '훈련 종료 · 홈으로');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets('P2 large text caregiver can read and share plan at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryStore()
        ..plan = const FamilyPlan(
          meetingPlace: '테스트 첫 장소',
          backupPlace: '테스트 대체 장소',
          note: '가족 약속',
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(3),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: FamilyScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, '가족 약속 보기');
      await tester.ensureVisible(find.text('가족 약속'));
      expect(find.text('가족 약속').hitTestable(), findsOneWidget);
      await tap(tester, '가족에게 공유');
      expect(find.byType(MeetingShareScreen), findsOneWidget);
      await tester.ensureVisible(find.text('내용 복사'));
      expect(find.text('내용 복사').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'P3 location denial retains manual region choice and saved shelter access',
    (tester) async {
      final location = DeniedLocation();
      final saved = SavedSheltersController(store: SavedMemoryStore());
      addTearDown(saved.dispose);
      final catalog = fixture('11110', '테스트 지역', 'denied');
      await saved.ensureLoaded();
      await saved.toggle(catalog, catalog.shelters.first.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SheltersScreen(
            catalog: catalog,
            savedShelters: saved,
            locationService: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(location.calls, 0);
      await tap(tester, 'GPS 현재 위치 확인');
      expect(location.calls, 1);
      expect(find.textContaining('위치 권한 없이도'), findsOneWidget);
      final savedEntry = find.textContaining('· 오프라인 목록');
      await tester.ensureVisible(savedEntry);
      await tester.tap(savedEntry);
      await tester.pumpAndSettle();
      expect(find.text(catalog.shelters.first.address), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tap(tester, '지역 변경');
      await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
      expect(find.text('선택 지역 대피소 불러오기').hitTestable(), findsOneWidget);
      expect(location.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('P4 offline refresh preserves saved address across reopening', (
    tester,
  ) async {
    final memory = SavedMemoryStore();
    final saved = SavedSheltersController(store: memory);
    final repository = RefreshRepository()..fail = true;
    addTearDown(saved.dispose);
    addTearDown(repository.close);
    final catalog = fixture('11110', '테스트 지역', 'offline');
    await saved.ensureLoaded();
    await saved.toggle(catalog, catalog.shelters.first.id);
    final writes = memory.writes;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SavedSheltersScreen(controller: saved, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tap(tester, '조회·저장 정보');
    await tap(tester, '공식 자료 다시 확인');
    expect(repository.calls, 1);
    expect(memory.writes, writes);
    expect(find.text(catalog.shelters.first.address), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final reopened = SavedSheltersController(store: memory);
    addTearDown(reopened.dispose);
    await reopened.ensureLoaded();
    expect(
      reopened.entries.single.shelter.address,
      catalog.shelters.first.address,
    );
  });

  testWidgets(
    'P5 failed family save cannot share stale plan and retry keeps edits',
    (tester) async {
      final store = MemoryStore()..failSave = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: FamilyScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('family-field-2')),
        '테스트 가족 장소',
      );
      await tap(tester, '기기에 저장');
      expect(store.plan.hasMeetingPlan, false);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '가족에게 공유'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('family-field-2')))
            .controller!
            .text,
        '테스트 가족 장소',
      );
      store.failSave = false;
      await tap(tester, '기기에 저장');
      expect(store.plan.meetingPlace, '테스트 가족 장소');
      await tap(tester, '가족에게 공유');
      expect(find.text('테스트 가족 장소'), findsOneWidget);
      expect(find.text('지도 위치 미지정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P6 chemical guidance preserves indoor context and avoids generic shelter CTA',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const AlertGuideScreen(initialKind: AlertKind.cbrn),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '화학 공격 안내');
      await tap(tester, '실내');
      expect(find.text('문·창문 닫기'), findsOneWidget);
      expect(find.text('무조건 지하로 가지 마세요'), findsOneWidget);
      expect(find.text('주변 대피소 보기'), findsNothing);
      expect(find.text('대피시설 확인'), findsNothing);
      expect(find.byType(DrillScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
