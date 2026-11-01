import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/widgets/shelter_map.dart';

import 'helpers/map_tiles.dart';
import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;
import 'region_and_refresh_test.dart' show FixtureLocation;

void main() {
  testWidgets('GPS is explicit, sorts loaded facilities and can be cleared', (
    tester,
  ) async {
    rootBundle.clear();
    final location = FixtureLocation();
    final saved = SavedSheltersController(store: SavedMemoryStore());
    await tester.pumpWidget(
      MaterialApp(
        home: SheltersScreen(
          catalog: fixture('11110', '테스트 지역', 'gps'),
          locationService: location,
          savedShelters: saved,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(location.calls, 0);
    expect(
      tester.getTopLeft(find.text('온라인 지도 열기')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(find.text('GPS 현재 위치 확인').hitTestable(), findsOneWidget);
    await tester.tap(find.text('GPS 현재 위치 확인'));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    expect(find.textContaining('직선거리 가까운 순'), findsOneWidget);
    expect(find.textContaining('실시간 추적 아님'), findsOneWidget);
    await tester.ensureVisible(find.text('온라인 지도 열기'));
    await tester.tap(find.text('온라인 지도 열기'));
    await tester.pump();
    expect(
      tester.widget<ShelterMap>(find.byType(ShelterMap)).currentLocation,
      const LatLng(37.57, 126.98),
    );
    await tester.ensureVisible(find.text('현재 위치 표시 지우기'));
    await tester.tap(find.text('현재 위치 표시 지우기'));
    await tester.pumpAndSettle();
    expect(find.byType(ShelterMap), findsNothing);
    expect(find.textContaining('위치 미사용, 원본 순서'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    saved.dispose();
  });
  testWidgets(
    'map centers on GPS and distinguishes location from facility pins',
    (tester) async {
      const location = LatLng(37.57, 126.98);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShelterMap(
              shelters: fixture('11110', '테스트', 'gps').shelters,
              onSelected: (_) {},
              currentLocation: location,
              tileProviderFactory: () => FixtureTiles(false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter, location);
      expect(map.options.initialCameraFit, isNull);
      expect(find.bySemanticsLabel('내 위치 · 마지막 GPS 확인 지점'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
