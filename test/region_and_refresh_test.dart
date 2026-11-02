import 'dart:convert';

import 'package:flutter/material.dart';

import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/location_service.dart';
import 'package:safe_korea/services/region_suggestion_service.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/shelter_repository.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

class RefreshRepository extends ShelterRepository {
  ShelterCatalog next = fixture('11110', '서울특별시 종로구', 'a');
  bool fail = false, incomplete = false;
  int calls = 0;
  @override
  Future<ShelterCatalog> fetch(String code, String regionName) async {
    calls++;
    if (fail) throw StateError('test offline');
    if (incomplete) throw const IncompleteShelterResponse(812, 479);
    return next;
  }

  @override
  Future<ShelterCatalog?> cached() async => null;
}

class FixtureLocation extends LocationService {
  FixtureLocation({this.accuracy = 10, this.age = Duration.zero});
  final double accuracy;
  final Duration age;
  int calls = 0;
  @override
  Future<Position> current() async {
    calls++;
    return Position(
      latitude: 37.57,
      longitude: 126.98,
      timestamp: DateTime.now().subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class FixtureRegion extends RegionSuggestionService {
  FixtureRegion({this.provinceOnly = false});
  final bool provinceOnly;
  int calls = 0;
  @override
  Future<RegionSuggestion?> suggest(
    Position position,
    List<Map<String, dynamic>> provinces,
  ) async {
    calls++;
    return provinceOnly
        ? const RegionSuggestion('11', null, '서울특별시')
        : const RegionSuggestion('26', '26110', '부산광역시 중구');
  }
}

Future<List<Map<String, dynamic>>> regions() async =>
    ((jsonDecode(File('assets/regions.json').readAsStringSync())
                as Map)['provinces']
            as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => rootBundle.clear());
  testWidgets(
    'confirmed GPS region queries once and retains position for distance ordering',
    (tester) async {
      final repo = RefreshRepository()
        ..next = fixture('26110', '부산광역시 중구', 'a');
      final location = FixtureLocation();
      final region = FixtureRegion();
      final saved = SavedSheltersController(store: SavedMemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SheltersScreen(
            repository: repo,
            locationService: location,
            regionService: region,
            savedShelters: saved,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('현재 위치로 지역 찾기'));
      await tester.tap(find.text('현재 위치로 지역 찾기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('위치로 조회 지역 제안받기'));
      await tester.tap(find.text('위치로 조회 지역 제안받기'));
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.ensureVisible(find.text('이 지역 대피소 바로 조회'));
      await tester.tap(find.text('이 지역 대피소 바로 조회'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(location.calls, 1);
      expect(find.byTooltip('내 위치 옵션'), findsOneWidget);
      expect(find.text('부산광역시 중구'), findsWidgets);
    },
  );
  test(
    'stale or imprecise GPS does not reach the external region lookup',
    () async {
      var calls = 0;
      final service = RegionSuggestionService(
        lookup: (lat, lon) async {
          calls++;
          return [];
        },
      );
      final catalog = await regions();
      for (final location in [
        FixtureLocation(accuracy: 2000),
        FixtureLocation(age: const Duration(minutes: 5)),
      ]) {
        await expectLater(
          service.suggest(await location.current(), catalog),
          throwsA(isA<LocationFailure>()),
        );
      }
      expect(calls, 0);
    },
  );
  test('region requires country, province and full district; ambiguity is rejected', () async {
    final catalog = await regions();
    RegionSuggestion? match(List<Placemark> p) =>
        RegionSuggestionService.match(p, catalog);
    expect(
      match([
        const Placemark(
          isoCountryCode: 'KR',
          administrativeArea: '서울특별시',
          subLocality: '종로구',
        ),
      ])?.districtCode,
      '11110',
    );
    expect(
      match([
        const Placemark(
          isoCountryCode: 'KR',
          administrativeArea: '경기도',
          locality: '수원시',
          subLocality: '영통구',
        ),
      ])?.districtCode,
      '41117',
    );
    expect(
      match([const Placemark(isoCountryCode: 'KR', locality: '중구')]),
      isNull,
    );
    expect(
      match([
        const Placemark(
          isoCountryCode: 'US',
          administrativeArea: '서울특별시',
          locality: '종로구',
        ),
      ]),
      isNull,
    );
    expect(
      match([
        const Placemark(
          isoCountryCode: 'KR',
          administrativeArea: '서울특별시',
          locality: '종로구',
        ),
        const Placemark(
          isoCountryCode: 'KR',
          administrativeArea: '서울특별시',
          locality: '중구',
        ),
      ]),
      isNull,
    );
  });
  test(
    'iOS-style province and neighbourhood response never invents a district',
    () async {
      final result = RegionSuggestionService.match([
        const Placemark(
          isoCountryCode: 'KR',
          administrativeArea: '서울특별시',
          locality: '서울특별시',
          subLocality: '가회동',
        ),
      ], await regions());
      expect(result?.provinceCode, '11');
      expect(result?.districtCode, isNull);
    },
  );
  testWidgets(
    'province-only suggestion clears district and prevents accidental query',
    (tester) async {
      final saved = SavedSheltersController(store: SavedMemoryStore()),
          repo = RefreshRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SheltersScreen(
            savedShelters: saved,
            repository: repo,
            locationService: FixtureLocation(),
            regionService: FixtureRegion(provinceOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('현재 위치로 지역 찾기'));
      await tester.tap(find.text('현재 위치로 지역 찾기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('위치로 조회 지역 제안받기'));
      await tester.tap(find.text('위치로 조회 지역 제안받기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('제안한 지역 선택'));
      await tester.tap(find.text('제안한 지역 선택'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, '선택 지역 대피소 불러오기');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(repo.calls, 0);
      await tester.pumpWidget(const SizedBox());
      saved.dispose();
      repo.close();
    },
  );
  test('same official ID in different regions never overwrites a saved facility; legacy keys remain removable', () async {
    final store = SavedMemoryStore();
    final a = fixture('11110', '서울특별시 종로구', 'shared'),
        b = fixture('26110', '부산광역시 중구', 'shared');
    final legacy = SavedShelter.fromCatalog(
      a,
      'shared',
      DateTime.utc(2026, 10, 31),
    ).toJson()..remove('keyVersion');
    final oldKey = '${a.sourceUrl}|shared';
    store.records[oldKey] = legacy;
    final controller = SavedSheltersController(store: store);
    await controller.load();
    expect(controller.contains(a, 'shared'), isTrue);
    expect(controller.contains(b, 'shared'), isFalse);
    await controller.toggle(b, 'shared');
    expect(controller.entries.length, 2);
    expect(store.records.containsKey(oldKey), isTrue);
    await controller.toggle(a, 'shared');
    expect(store.records.containsKey(oldKey), isFalse);
    await controller.toggle(a, 'shared');
    final reopened = SavedSheltersController(store: store);
    await reopened.load();
    expect(reopened.entries.map((e) => e.snapshot.areaCode).toSet(), {
      '11110',
      '26110',
    });
    expect(reopened.entries.every((e) => e.keyVersion == 2), isTrue);
    controller.dispose();
    reopened.dispose();
  });
  test('refresh preserves save time and persists confirmed or changed source information', () async {
    final store = SavedMemoryStore(), repo = RefreshRepository();
    final controller = SavedSheltersController(store: store);
    await controller.load();
    await controller.toggle(repo.next, 'a');
    final before = controller.entries.single;
    await controller.refresh(before, repo);
    expect(controller.entries.single.check, ShelterCheck.confirmed);
    final json = repo.next.toJson();
    (json['items'] as List).first['name'] = '변경된 공식 시설 이름';
    json['retrievedAt'] = '2026-11-01T00:00:00Z';
    repo.next = ShelterCatalog.fromJson(json);
    await controller.refresh(controller.entries.single, repo);
    final reopened = SavedSheltersController(store: store);
    await reopened.load();
    expect(reopened.entries.single.shelter.name, '변경된 공식 시설 이름');
    expect(reopened.entries.single.check, ShelterCheck.changed);
    expect(reopened.entries.single.savedAt, before.savedAt);
    expect(
      reopened.entries.single.snapshot.retrievedAt,
      '2026-11-01T00:00:00Z',
    );
    controller.dispose();
    reopened.dispose();
    repo.close();
  });
  test('missing and incomplete results preserve original facility; network and storage failures preserve all saved fields', () async {
    final store = SavedMemoryStore(), repo = RefreshRepository();
    final controller = SavedSheltersController(store: store);
    await controller.load();
    await controller.toggle(repo.next, 'a');
    final old = controller.entries.single;
    repo.next = fixture('11110', '서울특별시 종로구', 'other');
    await controller.refresh(old, repo);
    expect(controller.entries.single.check, ShelterCheck.notFound);
    expect(controller.entries.single.snapshot.toJson(), old.snapshot.toJson());
    repo.next = ShelterCatalog.fromJson({
      ...repo.next.toJson(),
      'skippedCount': 1,
    });
    await controller.refresh(controller.entries.single, repo);
    expect(controller.entries.single.check, ShelterCheck.incomplete);
    final retained = controller.entries.single.toJson();
    repo.fail = true;
    await controller.refresh(controller.entries.single, repo);
    expect(controller.entries.single.toJson(), retained);
    repo.fail = false;
    store.failWrite = true;
    await controller.refresh(controller.entries.single, repo);
    expect(controller.entries.single.toJson(), retained);
    controller.dispose();
    repo.close();
  });
  testWidgets(
    'region geocoding runs only on explicit button and never auto-fetches shelters',
    (tester) async {
      final location = FixtureLocation(),
          region = FixtureRegion(),
          repo = RefreshRepository();
      final saved = SavedSheltersController(store: SavedMemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          home: SheltersScreen(
            locationService: location,
            regionService: region,
            repository: repo,
            savedShelters: saved,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(location.calls, 0);
      expect(region.calls, 0);
      expect(repo.calls, 0);
      await tester.ensureVisible(find.text('현재 위치로 지역 찾기'));
      await tester.tap(find.text('현재 위치로 지역 찾기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('위치로 조회 지역 제안받기'));
      await tester.tap(find.text('위치로 조회 지역 제안받기'));
      await tester.pumpAndSettle();
      expect(region.calls, 1);
      expect(repo.calls, 0);
      await tester.ensureVisible(find.text('제안한 지역 선택'));
      await tester.tap(find.text('제안한 지역 선택'));
      await tester.pumpAndSettle();
      expect(find.textContaining('부산광역시 중구 선택됨'), findsOneWidget);
      expect(repo.calls, 0);
      await tester.pumpWidget(const SizedBox());
      saved.dispose();
      repo.close();
    },
  );
  testWidgets(
    'incomplete official response explains the mismatch and preserves existing facilities',
    (tester) async {
      final saved = SavedSheltersController(store: SavedMemoryStore());
      final repo = RefreshRepository()..incomplete = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SheltersScreen(
            catalog: repo.next,
            repository: repo,
            savedShelters: saved,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('지역 변경'));
      await tester.tap(find.text('지역 변경'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
      await tester.tap(find.text('선택 지역 대피소 불러오기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('전체 812건인데 지도 목록은 479건'), findsOneWidget);
      expect(find.text('테스트 시설 a'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      saved.dispose();
      repo.close();
    },
  );
  testWidgets(
    'saved details refresh from UI and large text can reach action buttons',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final saved = SavedSheltersController(store: SavedMemoryStore()),
          repo = RefreshRepository();
      await saved.load();
      await saved.toggle(repo.next, 'a');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SavedSheltersScreen(controller: saved, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('조회·저장 정보'));
      await tester.tap(find.text('조회·저장 정보'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('공식 자료 다시 확인'));
      await tester.tap(find.text('공식 자료 다시 확인'));
      await tester.pumpAndSettle();
      expect(saved.entries.single.check, ShelterCheck.confirmed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SheltersScreen(repository: repo, savedShelters: saved),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      saved.dispose();
      repo.close();
    },
  );
}
