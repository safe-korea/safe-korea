import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/meeting_point_screen.dart';

import '../test/helpers/map_tiles.dart';

import 'package:safe_korea/screens/notification_test_screen.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

import '../test/map_and_saved_shelters_test.dart'
    show SavedMemoryStore, fixture;

class PreviewStore extends LocalStore {
  @override
  Future<FamilyPlan> load() async => const FamilyPlan(
    meetingPlace: '서울시청 앞 · 테스트 장소',
    backupPlace: '광화문 광장 · 테스트 장소',
    meetingPoint: MeetingPoint(37.5665, 126.978),
    backupPoint: MeetingPoint(37.5725, 126.9769),
    note: '가족 약속 표시 테스트',
  );
  @override
  Future<Set<String>> loadPreparation() async => {};
}

class EmptyPreviewStore extends PreviewStore {
  @override
  Future<FamilyPlan> load() async => const FamilyPlan();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('inner pages align expanded text, places and facility metadata', (
    tester,
  ) async {
    Future<void> mount(Widget page) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.isIOS) await binding.takeScreenshot(name);
    }

    await mount(const HomeScreen());
    await capture('visual-home');
    await mount(const DrillScreen());
    await capture('visual-drill');
    await mount(FamilyScreen(store: EmptyPreviewStore()));
    await capture('visual-family-empty');
    await mount(
      MeetingPointScreen(
        title: '테스트 만남 장소',
        initialPoint: const MeetingPoint(37.5, 127),
        tileProviderFactory: () => FixtureTiles(false),
      ),
    );
    await capture('visual-meeting-map-controls');
    await mount(const NotificationTestScreen());
    await capture('notification-settings-review');
    await mount(const AlertGuideScreen());
    await capture('situational-guide-review');
    await mount(const GuidelinesScreen());
    await capture('visual-guidelines');
    await tester.tap(find.text('공습경보'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('공습경보'));
    await capture('guideline-expanded');
    await mount(ReadinessScreen(store: PreviewStore()));
    await capture('readiness');
    await mount(FamilyScreen(store: PreviewStore()));
    await capture('family-meeting');
    expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
    await tester.tap(find.text('가족에게 공유'));
    await tester.pumpAndSettle();
    await capture('family-share-preview');
    final saved = SavedSheltersController(store: SavedMemoryStore());
    await saved.ensureLoaded();
    final catalog = fixture('11110', '테스트 지역', '정렬 검증');
    await mount(SavedSheltersScreen(controller: saved));
    await capture('visual-saved-empty');
    await tester.tap(find.text('대피소 찾아서 저장하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SheltersScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await saved.toggle(catalog, catalog.shelters.first.id);
    await mount(SheltersScreen(catalog: catalog, savedShelters: saved));
    await capture('shelters-review');
    await tester.ensureVisible(find.text(catalog.shelters.first.name));
    await tester.tap(find.text(catalog.shelters.first.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시설 자료 상세'));
    await capture('shelter-detail-alignment');
    await mount(SavedSheltersScreen(controller: saved));
    await capture('saved-shelter-summary');
    await tester.ensureVisible(find.text('조회·저장 정보'));
    await tester.tap(find.text('조회·저장 정보'));
    await capture('saved-shelter-alignment');
    await tester.pumpWidget(const SizedBox());
    saved.dispose();
  });
}
