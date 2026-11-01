import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/action_brief.dart';

import '../test/map_and_saved_shelters_test.dart'
    show SavedMemoryStore, fixture;
import 'inner_layout_test.dart' show PreviewStore;

// Synthetic plans/facilities only. No location, audio or external sharing.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('focused Android user walkthrough', (tester) async {
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    Future<void> mount(Widget page, {double scale = 1}) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    for (final label in ['지금 할 행동 보기', '저장한 대피소', '가족 만남 장소', '비상배낭 체크리스트']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await capture('focus-home');
    await tester.tap(find.text('지금 할 행동 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(ActionBriefTile), findsNothing);
    await capture('focus-select-alert');
    await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공습경보').last);
    await tester.pumpAndSettle();
    for (final pair in [
      ('실내', '계단으로 이동'),
      ('실외', '가까운 건물로 대피'),
      ('이동 중', '운전 중이면 정차 후 대피'),
    ]) {
      await tester.tap(find.text(pair.$1));
      await tester.pumpAndSettle();
      expect(find.text(pair.$2).hitTestable(), findsOneWidget);
      await capture('focus-context-${pair.$1}');
    }
    final saved = SavedSheltersController(store: SavedMemoryStore());
    await saved.ensureLoaded();
    await mount(SavedSheltersScreen(controller: saved));
    expect(find.text('대피소 찾아서 저장하기'), findsOneWidget);
    await capture('focus-saved-empty');
    final catalog = fixture('11110', 'QA 지역', 'QA 전용');
    await saved.toggle(catalog, catalog.shelters.first.id);
    await mount(SavedSheltersScreen(controller: saved));
    expect(find.text(catalog.shelters.first.name), findsOneWidget);
    await capture('focus-saved');
    await mount(FamilyScreen(store: PreviewStore()));
    expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
    await capture('focus-family');
    await tester.tap(find.text('가족에게 공유'));
    await capture('focus-share-preview');
    await mount(ReadinessScreen(store: PreviewStore()), scale: 2);
    await capture('focus-preparation-large-text');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
    await capture('focus-preparation-large-text-scrolled');
    await tester.pumpWidget(const SizedBox());
    saved.dispose();
  });
}
