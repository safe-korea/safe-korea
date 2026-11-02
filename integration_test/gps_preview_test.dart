import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/shelter_map.dart';

import '../test/map_and_saved_shelters_test.dart'
    show fixture, SavedMemoryStore;
import '../test/region_and_refresh_test.dart' show FixtureLocation;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('explicit fixture GPS appears on map and can be cleared', (
    tester,
  ) async {
    final saved = SavedSheltersController(store: SavedMemoryStore());
    final location = FixtureLocation();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: SheltersScreen(
          catalog: fixture('11110', '테스트 지역', 'GPS 확인'),
          locationService: location,
          savedShelters: saved,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(location.calls, 0);
    await tester.tap(find.text('GPS 현재 위치 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('실시간 추적 아님'), findsOneWidget);
    if (Platform.isIOS) await binding.takeScreenshot('gps-location');
    await tester.ensureVisible(find.text('온라인 지도 열기'));
    await tester.tap(find.text('온라인 지도 열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ShelterMap));
    for (
      var i = 0;
      i < 15 && find.textContaining('지도 배경 불러오는 중').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.bySemanticsLabel('내 위치 · 마지막 GPS 확인 지점'), findsOneWidget);
    if (Platform.isIOS) await binding.takeScreenshot('gps-map');
    await tester.ensureVisible(find.text('현재 위치 표시 지우기'));
    await tester.tap(find.text('현재 위치 표시 지우기'));
    await tester.pumpAndSettle();
    expect(find.byType(ShelterMap), findsNothing);
    await tester.pumpWidget(const SizedBox());
    saved.dispose();
  });
}
