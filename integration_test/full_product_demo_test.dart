import 'dart:io';

import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/screens/family_screen.dart';

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
    'capture complete current product walkthrough without sending messages',
    (tester) async {
      final area = await OfflineArea.load();
      final station = area.catalog.shelters.firstWhere(
        (s) => s.name.contains('승강장'),
      );
      final raw = area.catalog.toJson();
      raw['items'] = (raw['items'] as List)
          .where((s) => s['id'] == station.id)
          .toList();
      raw['coverage'] = '서울특별시 송파구 · 선택 시설';
      final catalog = ShelterCatalog.fromJson(raw);
      final db = await openDatabase(
        path.join(
          await getDatabasesPath(),
          'map_demo_${DateTime.now().millisecondsSinceEpoch}.db',
        ),
      );
      await db.execute(
        'CREATE TABLE plans (id INTEGER PRIMARY KEY, content TEXT NOT NULL)',
      );
      final store = LocalStore(database: db);
      final saved = SavedSheltersController(
        store: store,
        maps: SavedMapDownloader(
          baseUrl: 'https://safe-korea-shelter-api.trovapp.workers.dev',
        ),
      );
      await saved.load();
      Future<void> showScene(String name, Widget screen) async {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(name),
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> hold(String name, int seconds) async {
        debugPrint('DEMO_SCENE_$name');
        await Future<void>.delayed(Duration(seconds: seconds));
      }

      await showScene('home', const HomeScreen());
      await hold('home', 8);
      await tester.ensureVisible(find.text('모의 공습경보 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('모의 공습경보 시작'));
      await tester.pumpAndSettle();
      await hold('drill', 8);
      await tester.ensureVisible(find.text('실내').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('실내').first);
      await tester.pumpAndSettle();
      await hold('actions', 8);
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
      await hold('save', 4);
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
      await hold('saved', 4);
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
      await hold('offline', 6);
      await tester.tap(find.text('저장한 주변 지도 보기'));
      await tester.pumpAndSettle();
      expect(find.text('저장한 주변 지도'), findsOneWidget);
      expect(find.text(station.address), findsOneWidget);
      await binding.takeScreenshot('saved-facility-map-offline-ios');
      await hold('map', 5);
      await tester.tap(find.byTooltip('지도 확대'));
      await tester.pumpAndSettle();
      await hold('zoom', 5);
      expect(tester.takeException(), isNull);
      HttpOverrides.global = null;
      await store.save(
        FamilyPlan(
          meetingPlace: '잠실역 2번 출구 앞 · 시연용 약속',
          backupPlace: '송파구청 앞 · 시연용 약속',
          note: '연락이 되면 서로 위치를 확인해요.',
        ),
      );
      await showScene('family', FamilyScreen(store: store));
      await hold('family', 7);
      await tester.ensureVisible(find.text('가족에게 공유'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('가족에게 공유'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
      await tester.pumpAndSettle();
      await hold('share', 5);
      await tester.tap(find.text('카카오톡 등으로 공유'));
      await tester.pumpAndSettle();
      await hold('sheet', 6);
      expect(find.textContaining('공유 창을 열지 못했습니다'), findsNothing);
      debugPrint('DEMO_CAPTURE_COMPLETE');
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
}
