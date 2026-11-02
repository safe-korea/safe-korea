import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:safe_korea/models/offline_area.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/saved_map_downloader.dart';
import 'package:safe_korea/theme/app_theme.dart';

class BlockNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = ((uri, proxyHost, proxyPort) async =>
            throw const SocketException('Demo offline'));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'save one real shelter and its map then reopen with all network blocked',
    (tester) async {
      final area = await OfflineArea.load();
      final station = area.catalog.shelters.firstWhere(
        (s) => s.name.contains('승강장'),
      );
      final raw = area.catalog.toJson();
      raw['items'] = (raw['items'] as List)
          .where((s) => s['id'] == station.id)
          .toList();
      final catalog = ShelterCatalog.fromJson(raw);
      final db = await openDatabase(
        path.join(
          await getDatabasesPath(),
          'map_demo_${DateTime.now().millisecondsSinceEpoch}.db',
        ),
      );
      final store = LocalStore(database: db);
      final saved = SavedSheltersController(
        store: store,
        maps: SavedMapDownloader(
          baseUrl: 'https://safe-korea-shelter-api.trovapp.workers.dev',
        ),
      );
      await saved.load();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: SheltersScreen(catalog: catalog, savedShelters: saved),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(station.name).first);
      await tester.tap(find.text(station.name).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('대피소 저장').first);
      await tester.pump(const Duration(seconds: 2));
      debugPrint('DEMO_READY_TO_RECORD');
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.tap(find.text('대피소 저장').first);
      await tester.pump();
      for (var i = 0; i < 70 && saved.busy; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(
        saved.entries.single.offlineMap,
        isNotNull,
        reason: saved.mapMessage,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(seconds: 3));
      final reloaded = SavedSheltersController(store: store);
      await reloaded.load();
      expect(reloaded.entries.single.offlineMap, isNotNull);
      addTearDown(() => HttpOverrides.global = null);
      HttpOverrides.global = BlockNetwork();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          key: const ValueKey('offline'),
          home: SavedSheltersScreen(controller: reloaded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('저장한 주변 지도 보기'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 4));
      await tester.tap(find.text('저장한 주변 지도 보기'));
      await tester.pumpAndSettle();
      expect(find.text('저장한 주변 지도'), findsOneWidget);
      expect(find.text(station.address), findsOneWidget);
      await binding.takeScreenshot('saved-facility-map-offline-ios');
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.tap(find.byTooltip('지도 확대'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
      HttpOverrides.global = null;
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
}
