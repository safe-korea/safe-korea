import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safe_korea/models/saved_shelter.dart';
import 'package:safe_korea/screens/shelter_record_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/screens/status_share_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/shelter_photo_importer.dart';
import 'package:safe_korea/theme/app_theme.dart';

import '../test/map_and_saved_shelters_test.dart'
    show SavedMemoryStore, fixture;

class PreviewPhotoImporter extends ShelterPhotoImporter {
  @override
  Future<ShelterPhoto?> recover() async => null;
  @override
  Future<ShelterPhoto?> pick() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE0EEE7), BlendMode.src);
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: '사진 저장 테스트\n실제 시설 사진 아님',
        style: TextStyle(color: Color(0xFF17352D), fontSize: 40, height: 1.6),
      ),
    )..layout(maxWidth: 600);
    text.paint(canvas, const Offset(40, 80));
    final picture = recorder.endRecording();
    final image = await picture.toImage(680, 360);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return decode(XFile.fromData(data!.buffer.asUint8List()));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native offline personal photo, priority, enlargement and manual status preview',
    (tester) async {
      Future<void> mount(Widget screen) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.isIOS) await binding.takeScreenshot(name);
      }

      final c = SavedSheltersController(store: SavedMemoryStore());
      await c.load();
      await c.toggle(fixture('11110', '테스트용 시설 · 실제 대피소 아님', '사진 QA'), '사진 QA');
      await mount(
        ShelterRecordScreen(
          entry: c.entries.single,
          controller: c,
          importer: PreviewPhotoImporter(),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        '출입구 메모 표시 테스트 · 실제 이동 안내 아님',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(find.text('사진 보관함에서 선택'));
      await tester.tap(find.text('사진 보관함에서 선택'));
      await tester.pumpAndSettle();
      expect(find.text('내 사진 1/3'), findsOneWidget);
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      expect(c.entries.single.photos, hasLength(1));
      expect(
        base64Decode(c.entries.single.photos.single.data).length,
        greaterThan(100),
      );
      await capture('personal-photo-editor');
      final e = c.entries.single;
      await c.savePersonal(
        e.key,
        ShelterRole.primary,
        e.entranceNote,
        e.photos,
      );
      await mount(SavedSheltersScreen(controller: c));
      await capture('personal-photo-saved');
      await tester.ensureVisible(find.text('사진 1 크게 보기'));
      await tester.tap(find.text('사진 1 크게 보기'));
      await tester.pumpAndSettle();
      await capture('personal-photo-zoom');
      await mount(const AfterArrivalScreen(training: true));
      await capture('after-arrival');
      await mount(
        StatusShareScreen(
          training: true,
          shareText: (_, _) async => fail('No actual share during QA'),
        ),
      );
      await tester.tap(find.text('대피 중입니다.'));
      await tester.pumpAndSettle();
      await capture('status-share-preview');
    },
  );
}
