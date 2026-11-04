import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/public_shelter_photo.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/screens/shelter_record_screen.dart';
import 'package:safe_korea/screens/status_share_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/public_shelter_photo.dart';

import 'map_and_saved_shelters_test.dart' show SavedMemoryStore;
import 'public_shelter_photo_test.dart' show matchedRecord;
import 'shelter_records_test.dart' show PhotoFixture;

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> mount(WidgetTester tester, Widget page, double scale) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'public photo enlargement preserves image space in landscape with 3x text',
    (tester) async {
      viewport(tester, const Size(568, 320));
      await mount(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: PublicShelterPhotoCard(photo: PublicShelterPhoto.cityHall),
          ),
        ),
        3,
      );
      await tester.ensureVisible(find.text('공개 사진 크게 보기'));
      await tester.tap(find.text('공개 사진 크게 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      await tester.tap(find.byTooltip('확대'));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1.5, .001),
      );
      await tester.tap(find.byTooltip('축소'));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1, .001),
      );
      await tester.tap(find.byTooltip('확대'));
      await tester.tap(find.byTooltip('원래 크기'));
      await tester.pump();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      expect(
        tester.getSize(find.byType(InteractiveViewer)).height,
        greaterThanOrEqualTo(96),
      );
    },
  );
  testWidgets('priority dropdown selected value is not clipped at 3x text', (
    tester,
  ) async {
    viewport(tester, const Size(375, 812));
    final c = SavedSheltersController(store: SavedMemoryStore());
    await c.load();
    final catalog = ShelterCatalog.fromJson(matchedRecord());
    await c.toggle(catalog, catalog.shelters.single.id);
    await mount(
      tester,
      ShelterRecordScreen(
        entry: c.entries.single,
        controller: c,
        importer: PhotoFixture(),
      ),
      3,
    );
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<ShelterRole>),
    );
    expect(tester.takeException(), isNull);
    final field = tester.getRect(
      find.byType(DropdownButtonFormField<ShelterRole>),
    );
    final save = tester.getRect(find.widgetWithText(FilledButton, '기기에 저장'));
    expect(save.left, field.left);
    expect(save.right, field.right);
    expect(
      tester.getSize(find.text('일반 저장').first).height,
      greaterThanOrEqualTo(48),
    );
  });
  for (final view in [
    (const Size(375, 812), 3.0),
    (const Size(568, 320), 2.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets(
      'new screens keep actions reachable at ${view.$1} scale ${view.$2}',
      (tester) async {
        viewport(tester, view.$1);
        await mount(tester, const AfterArrivalScreen(training: true), view.$2);
        await tester.ensureVisible(find.text('가족에게 내 상태 알리기'));
        expect(find.text('가족에게 내 상태 알리기').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await mount(tester, const StatusShareScreen(training: true), view.$2);
        await tester.ensureVisible(find.text('대피 중입니다.'));
        await tester.tap(find.text('대피 중입니다.'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('확인하고 공유 앱 열기'));
        expect(find.text('확인하고 공유 앱 열기').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final c = SavedSheltersController(store: SavedMemoryStore());
        await c.load();
        final catalog = ShelterCatalog.fromJson(matchedRecord());
        await c.toggle(catalog, catalog.shelters.single.id);
        await mount(tester, SavedSheltersScreen(controller: c), view.$2);
        await tester.ensureVisible(find.text('온라인 지도 보기'));
        expect(find.text('온라인 지도 보기').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('주변 실제 모습 보기'));
        expect(find.text('주변 실제 모습 보기').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('내 기록 · 선택'));
        await tester.tap(find.text('내 기록 · 선택'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('사진·약도·메모 추가'));
        expect(find.text('사진·약도·메모 추가').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
