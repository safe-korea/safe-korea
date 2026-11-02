import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class DeniedLocation extends LocationService {
  @override
  Future<Position> current() async =>
      throw const LocationFailure('위치 권한 없이도 시설 검색과 행동강령을 이용할 수 있어요.');
}

void main() {
  testWidgets('Korean home opens a clearly labeled drill and returns', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaApp());
    expect(find.text('SAFE KOREA'), findsOneWidget);
    expect(find.textContaining('경보를 들었다면, 지금 할 행동부터'), findsOneWidget);
    await tester.ensureVisible(find.text('모의 공습경보 시작'));
    await tester.tap(find.text('모의 공습경보 시작'));
    await tester.pumpAndSettle();
    expect(find.text('훈련 / 테스트'), findsOneWidget);
    expect(find.textContaining('실제 공습경보가 아닙니다'), findsOneWidget);
    await tester.ensureVisible(find.text('훈련 종료 · 홈으로'));
    await tester.tap(find.text('훈련 종료 · 홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('모의 공습경보 시작'), findsOneWidget);
  });

  testWidgets(
    'guidance loads bundled content with chemical-specific instructions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GuidelinesScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('오프라인 저장됨'), findsOneWidget);
      await tester.ensureVisible(find.text('화생방 · 화학 공격'));
      await tester.tap(find.text('화생방 · 화학 공격'));
      await tester.pumpAndSettle();
      expect(find.textContaining('화학 공격이 확인되면 지하를 벗어나'), findsOneWidget);
      expect(find.textContaining('완전히 차단한다고 믿지 마세요'), findsOneWidget);
    },
  );

  testWidgets(
    'permission denial leaves official search and offline fallback usable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SheltersScreen(locationService: DeniedLocation())),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('저장된 대피시설이 없습니다.'), findsOneWidget);
      await tester.ensureVisible(find.text('GPS 현재 위치 확인'));
      await tester.tap(find.text('GPS 현재 위치 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('위치 권한 없이도 시설 검색'), findsOneWidget);
      expect(find.text('정부 공식 시설 검색 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow screen and 200 percent text never overflow home and drill',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final page in [
        const SafeKoreaApp(),
        const MaterialApp(home: DrillScreen()),
      ]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('home controls have accessible labels and Android tap sizes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
