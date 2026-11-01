import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/services/shelter_street_view.dart';
import 'package:safe_korea/widgets/shelter_street_view_button.dart';

import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

final shelter = fixture('11110', '테스트', 'a').shelters.single;
void main() {
  test('documented HTTPS roadview URL uses facility latitude then longitude, without keys or GPS', () {
    final uri = ShelterStreetView.urlFor(shelter);
    expect(uri.scheme, 'https');
    expect(uri.host, 'map.kakao.com');
    expect(uri.path, '/link/roadview/37.5,127.0');
    expect(uri.query, isEmpty);
    expect(uri.userInfo, isEmpty);
  });
  test('invalid public facility coordinates cannot launch', () async {
    var calls = 0;
    final service = ShelterStreetView(
      launch: (_, _) async {
        calls++;
        return true;
      },
    );
    await expectLater(
      service.open(
        const Shelter(
          id: 'bad',
          name: 'bad',
          address: 'bad',
          latitude: double.nan,
          longitude: 127,
          updatedAt: null,
        ),
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });
  test(
    'native browser failure falls back once; total failure is reported',
    () async {
      final modes = <LaunchMode>[];
      final service = ShelterStreetView(
        launch: (_, mode) async {
          modes.add(mode);
          if (mode == LaunchMode.inAppBrowserView) {
            throw StateError('unsupported');
          }
          return true;
        },
      );
      expect(await service.open(shelter), isTrue);
      expect(modes, [
        LaunchMode.inAppBrowserView,
        LaunchMode.externalApplication,
      ]);
      expect(
        await ShelterStreetView(launch: (_, _) async => false).open(shelter),
        isFalse,
      );
    },
  );
  testWidgets(
    'public imagery is explicit, retryable and not labelled as an entrance photograph',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShelterStreetViewButton(
              shelter: shelter,
              service: ShelterStreetView(
                launch: (_, _) async {
                  calls++;
                  return false;
                },
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      expect(find.textContaining('실제 출입구와 다를 수'), findsOneWidget);
      await tester.tap(find.text('주변 실제 모습 보기'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('로드뷰를 열지 못했어요'), findsOneWidget);
      await tester.tap(find.text('주변 실제 모습 보기'));
      await tester.pumpAndSettle();
      expect(calls, 4);
    },
  );
  testWidgets(
    'saved facility offers public imagery before collapsed optional private photos',
    (tester) async {
      final c = SavedSheltersController(store: SavedMemoryStore());
      await c.load();
      await c.toggle(fixture('11110', '테스트', 'a'), 'a');
      await tester.pumpWidget(
        MaterialApp(home: SavedSheltersScreen(controller: c)),
      );
      await tester.pumpAndSettle();
      expect(find.text('주변 실제 모습 보기'), findsOneWidget);
      expect(find.text('우선순위·사진·메모 추가'), findsNothing);
      await tester.ensureVisible(find.text('내 기록 · 선택'));
      await tester.tap(find.text('내 기록 · 선택'));
      await tester.pumpAndSettle();
      expect(find.text('우선순위·사진·메모 추가'), findsOneWidget);
    },
  );
  testWidgets(
    'street view controls remain readable with large text and stale coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShelterStreetViewButton(
                shelter: shelter,
                previousLocation: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('이전 저장 위치 기준'), findsOneWidget);
      await tester.ensureVisible(find.text('사진 이용 안내'));
      await tester.tap(find.text('사진 이용 안내'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(812, 375);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
