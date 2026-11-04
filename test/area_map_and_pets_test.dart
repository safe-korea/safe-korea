import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_korea/models/offline_area.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/screens/offline_map_screen.dart';
import 'package:safe_korea/screens/shelter_record_screen.dart';
import 'package:safe_korea/services/area_map_service.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/location_service.dart';
import 'package:safe_korea/services/region_suggestion_service.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/shelter_repository.dart';

import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

class AreaStore extends LocalStore {
  Map<String, dynamic>? area;
  @override
  Future<Map<String, dynamic>?> loadAreaMap() async => area;
  @override
  Future<void> saveAreaMap(Map<String, dynamic> record) async =>
      area = jsonDecode(jsonEncode(record)) as Map<String, dynamic>;
  @override
  Future<void> removeAreaMap() async => area = null;
}

class Here extends LocationService {
  Here(this.lat, this.lon);
  final double lat, lon;
  @override
  Future<Position> current() async => Position(
    latitude: lat,
    longitude: lon,
    timestamp: DateTime.now(),
    accuracy: 12,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class Jongno extends RegionSuggestionService {
  @override
  Future<RegionSuggestion?> suggest(
    Position p,
    List<Map<String, dynamic>> _,
  ) async => const RegionSuggestion('11', '11110', '서울특별시 종로구');
}

class Border extends RegionSuggestionService {
  @override
  Future<RegionSuggestion?> suggest(
    Position p,
    List<Map<String, dynamic>> _,
  ) async => null;
}

class FixtureRepository extends ShelterRepository {
  FixtureRepository() : super(store: SavedMemoryStore());
  final codes = <String>[];
  @override
  Future<ShelterCatalog> fetch(String code, String regionName) async {
    codes.add(code);
    return fixture(code, regionName, 'jongno-1', latitude: 37.58);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pet record', () {
    test('round-trips and old records default to unchecked', () {
      final entry = SavedShelter.fromCatalog(
        fixture('11110', '종로구', 'a'),
        'a',
        DateTime.utc(2026, 11, 4),
      );
      expect(entry.pet.status, PetStatus.unchecked);
      expect(entry.toJson().containsKey('pet'), isFalse);
      final pet = PetCheck(
        status: PetStatus.allowed,
        conditions: '이동장 필수',
        checkedWith: '종로구청 안전총괄과',
        checkedOn: DateTime.utc(2026, 11, 5),
      );
      final updated = entry.withPersonal(
        role: ShelterRole.none,
        note: '',
        photos: const [],
        pet: pet,
      );
      final back = SavedShelter.fromJson(
        jsonDecode(jsonEncode(updated.toJson())) as Map<String, dynamic>,
      );
      expect(back.pet.status, PetStatus.allowed);
      expect(back.pet.conditions, '이동장 필수');
      expect(back.pet.checkedWith, '종로구청 안전총괄과');
      // Changing role or map keeps the pet record.
      expect(
        back
            .withPersonal(role: ShelterRole.primary, note: '', photos: const [])
            .pet
            .status,
        PetStatus.allowed,
      );
      expect(back.withOfflineMap({'x': 1}).pet.status, PetStatus.allowed);
    });

    test('controller rejects over-long pet fields', () async {
      final controller = SavedSheltersController(store: SavedMemoryStore());
      await controller.load();
      final catalog = fixture('11110', '종로구', 'a');
      await controller.toggle(catalog, 'a');
      final key = controller.entries.single.key;
      expect(
        await controller.savePersonal(
          key,
          ShelterRole.none,
          '',
          const [],
          pet: PetCheck(status: PetStatus.allowed, conditions: 'x' * 201),
        ),
        isFalse,
      );
      expect(
        await controller.savePersonal(
          key,
          ShelterRole.none,
          '',
          const [],
          pet: const PetCheck(status: PetStatus.notAllowed),
        ),
        isTrue,
      );
      expect(controller.entries.single.pet.status, PetStatus.notAllowed);
      controller.dispose();
    });

    testWidgets('record screen saves a user-checked pet answer with date', (
      tester,
    ) async {
      final controller = SavedSheltersController(store: SavedMemoryStore());
      await tester.runAsync(controller.load);
      await tester.runAsync(
        () => controller.toggle(fixture('11110', '종로구', 'a'), 'a'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ShelterRecordScreen(
            entry: controller.entries.single,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('공식 동반 가능 대피소 목록은 없어요'), findsOneWidget);
      expect(find.text('수용 조건'), findsNothing);
      await tester.ensureVisible(find.text('동반 가능'));
      await tester.tap(find.text('동반 가능'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '수용 조건'), '이동장 필수');
      await tester.enterText(find.widgetWithText(TextField, '확인한 곳'), '종로구청');
      expect(find.textContaining('공식 정보 아님'), findsOneWidget);
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      final pet = controller.entries.single.pet;
      expect(pet.status, PetStatus.allowed);
      expect(pet.conditions, '이동장 필수');
      expect(pet.checkedWith, '종로구청');
      expect(pet.checkedOn, isNotNull);
      controller.dispose();
    });

    testWidgets('pet guidance is shown as a draft with its own source', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: GuidelinesScreen()));
      await tester.pumpAndSettle();
      final tile = find.text('반려동물과 함께 대피 준비');
      await tester.scrollUntilVisible(tile, 300);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.textContaining('초안 · 원문 대조 전 ·'), findsOneWidget);
      expect(find.textContaining('농림축산식품부'), findsOneWidget);
    });
  });

  group('my area map', () {
    MockClient cells(List<String> urls) => MockClient((request) async {
      urls.add(request.url.toString());
      final name = request.url.pathSegments.last;
      return http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'license': 'ODbL 1.0',
          'features': [
            {
              'id': name,
              'kind': 'road',
              'type': 'primary',
              'name': '종로',
              'points': [
                [126.98, 37.57],
                [126.99, 37.575],
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    test('plans the district and downloads only cells and region code', () async {
      rootBundle.clear();
      final urls = <String>[];
      final store = AreaStore();
      final repository = FixtureRepository();
      final service = AreaMapService(
        location: Here(37.5735, 126.9790),
        regions: Jongno(),
        store: store,
        repository: repository,
        baseUrl: 'https://example.test',
        client: cells(urls),
      );
      final plan = await service.plan();
      expect(plan.region.label, '서울특별시 종로구');
      expect(plan.bounds, hasLength(4));
      expect(plan.cellCount, greaterThan(0));
      // Real bundled index: Jongno's road cells are several MB, not an average.
      expect(plan.totalKb, greaterThan(5000));
      expect(plan.sizeLabel, matches(r'^약 \d+MB$'));
      final saved = await service.download(plan);
      expect(urls, hasLength(plan.cellCount));
      // Only public cell numbers are requested; no device coordinates.
      for (final url in urls) {
        expect(
          url,
          matches(r'^https://example\.test/offline-packs/\d+-\d+\.json$'),
        );
        expect(url, isNot(contains('37.57')));
      }
      expect(repository.codes, ['11110']);
      expect(saved.regionName, '서울특별시 종로구');
      expect(saved.catalog!.shelters, hasLength(1));
      expect((await service.load())!.regionCode, '11110');
      await service.remove();
      expect(await service.load(), isNull);
    });

    test(
      'ambiguous district near a border asks the user instead of guessing',
      () async {
        final service = AreaMapService(
          location: Here(37.5735, 126.9790),
          regions: Border(),
          store: AreaStore(),
        );
        expect(service.plan(), throwsA(isA<AreaMapFailure>()));
      },
    );

    test(
      'near a real district boundary the user chooses; no guessing',
      () async {
        rootBundle.clear();
        // Jongno-1ga sits on the Jongno/Jung boundary (Cheonggyecheon).
        final service = AreaMapService(
          location: Here(37.5700, 126.9790),
          store: AreaStore(),
        );
        try {
          await service.plan();
          fail('expected a choice');
        } on AreaMapChoice catch (choice) {
          final labels = choice.plans.map((p) => p.region.label).toList();
          expect(labels, containsAll(['서울특별시 종로구', '서울특별시 중구']));
          expect(choice.plans.every((p) => p.totalKb > 0), isTrue);
        }
      },
    );

    testWidgets(
      'saved area shows my position, coordinates and straight-line distance',
      (tester) async {
        final catalog = fixture('11110', '종로구', 'near', latitude: 37.5745);
        final area = OfflineArea({
          'schemaVersion': 1,
          'bounds': [126.97, 37.56, 127.0, 37.59],
          'features': [
            {
              'id': '1',
              'kind': 'road',
              'type': 'primary',
              'name': '종로',
              'points': [
                [126.97, 37.57],
                [127.0, 37.57],
              ],
            },
          ],
          'preparedAt': '2026-11-04',
        }, catalog);
        await tester.pumpWidget(
          MaterialApp(
            home: OfflineMapScreen(
              title: '종로구 지도',
              savedArea: area,
              showMyLocation: true,
              locationService: Here(37.5735, 126.99),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('종로구 지도'), findsOneWidget);
        expect(find.text('인터넷 없이 사용 · 길찾기 없음'), findsOneWidget);
        await tester.tap(find.text('내 위치 확인 (GPS)'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('내 위치'), findsOneWidget);
        expect(find.textContaining('북위 37.57350°'), findsOneWidget);
        expect(find.textContaining('직선'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
