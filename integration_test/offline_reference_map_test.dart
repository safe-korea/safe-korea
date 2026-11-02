import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/screens/offline_hub_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/connection_monitor.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';

import '../test/map_and_saved_shelters_test.dart'
    show SavedMemoryStore, fixture;
import 'shelter_records_test.dart' show PreviewPhotoImporter;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline hub and local reference image need no map service', (
    tester,
  ) async {
    final monitor = ConnectionMonitor(
      readLink: () async => false,
      changes: const Stream.empty(),
      probe: () async => false,
    );
    await monitor.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: OfflineHubScreen(monitor: monitor),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('네트워크 연결이 없어요'), findsOneWidget);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    await binding.takeScreenshot(
      'offline-reference-hub-${Platform.operatingSystem}',
    );
    final store = SavedMemoryStore();
    final c = SavedSheltersController(store: store);
    await c.load();
    await c.toggle(
      fixture('11110', '테스트 시설 · 실제 대피소 아님', 'offline-qa'),
      'offline-qa',
    );
    final photo = await PreviewPhotoImporter().pick();
    await c.savePersonal(c.entries.single.key, ShelterRole.none, '', [
      ShelterPhoto(
        data: photo!.data,
        addedAt: photo.addedAt,
        mapSource: 'QA용 생성 이미지 · 실제 약도 아님',
      ),
    ]);
    final reloaded = SavedSheltersController(store: store);
    await reloaded.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SavedSheltersScreen(controller: reloaded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장한 약도 크게 보기'));
    await binding.takeScreenshot(
      'offline-reference-card-${Platform.operatingSystem}',
    );
    await tester.tap(find.text('저장한 약도 크게 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('지도 갱신일 아님'), findsOneWidget);
    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot(
      'offline-reference-viewer-${Platform.operatingSystem}',
    );
    await tester.pumpWidget(const SizedBox());
    monitor.dispose();
    c.dispose();
    reloaded.dispose();
  });
}
