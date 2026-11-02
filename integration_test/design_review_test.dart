import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelter_record_screen.dart';
import 'package:safe_korea/screens/status_share_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';

import '../test/map_and_saved_shelters_test.dart' show SavedMemoryStore;
import '../test/public_shelter_photo_test.dart' show matchedRecord;
import '../test/shelter_records_test.dart' show PhotoFixture;
import 'inner_layout_test.dart' as inner;

void main() {
  inner.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'design review of new personal records, public photos and manual status',
    (tester) async {
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
        if (Platform.isIOS) await binding.takeScreenshot('design-$name');
      }

      final c = SavedSheltersController(store: SavedMemoryStore());
      await c.load();
      final catalog = ShelterCatalog.fromJson(matchedRecord());
      await c.toggle(catalog, catalog.shelters.single.id);
      await mount(SavedSheltersScreen(controller: c));
      await capture('saved-public-summary');
      await tester.ensureVisible(find.text('공개된 건물 사진'));
      await capture('saved-public-photo');
      await tester.ensureVisible(find.text('공개 사진 크게 보기'));
      await tester.tap(find.text('공개 사진 크게 보기'));
      await capture('photo-expanded');
      await mount(
        ShelterRecordScreen(
          entry: c.entries.single,
          controller: c,
          importer: PhotoFixture(),
        ),
      );
      await capture('record-editor');
      await mount(const AfterArrivalScreen(training: true));
      await capture('after-arrival');
      await mount(const StatusShareScreen(training: true));
      await capture('status-empty');
      await tester.tap(find.text('대피 중입니다.'));
      await tester.enterText(find.byType(TextField), '가족에게 알려줄 장소 · 테스트 입력');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(find.text('보낼 내용'));
      await capture('status-preview');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
