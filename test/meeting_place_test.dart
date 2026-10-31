import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/meeting_point_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'helpers/map_tiles.dart';
import 'local_store_test.dart' show MemoryStore;

void main() {
  test('legacy plan and invalid coordinates remain readable', () {
    final old = FamilyPlan.fromJson({
      'phone': ' keep ',
      'meetingPlace': '기존 장소',
    });
    expect(old.phone, ' keep ');
    expect(old.meetingPoint, isNull);
    final plan = FamilyPlan.fromJson({
      ...old.toJson(),
      'meetingPoint': {'latitude': 37.5, 'longitude': 127},
      'backupPoint': {'latitude': 95, 'longitude': 127},
    });
    expect(plan.meetingPoint!.latitude, 37.5);
    expect(plan.backupPoint, isNull);
    expect(FamilyPlan.fromJson(plan.toJson()).meetingPoint!.longitude, 127);
  });
  testWidgets('editing and clearing meeting places preserves legacy contacts', (
    tester,
  ) async {
    final store = MemoryStore()
      ..plan = const FamilyPlan(
        contactName: ' preserved ',
        phone: '01000000000',
        meetingPlace: '기존 장소',
        meetingPoint: MeetingPoint(37.5, 127),
      );
    await tester.pumpWidget(MaterialApp(home: FamilyScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('만남 장소 수정'));
    await tester.tap(find.text('만남 장소 수정'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('비상연락처 이름'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('family-field-2')),
      '새 장소',
    );
    await tester.ensureVisible(find.text('기기에 저장'));
    await tester.tap(find.text('기기에 저장'));
    await tester.pumpAndSettle();
    expect(store.plan.contactName, ' preserved ');
    expect(store.plan.phone, '01000000000');
    expect(store.plan.meetingPoint!.latitude, 37.5);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장된 계획 삭제'));
    await tester.tap(find.text('저장된 계획 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(store.plan.contactName, ' preserved ');
    expect(store.plan.meetingPoint, isNull);
    expect(store.plan.hasMeetingPlan, false);
  });
  testWidgets('map requires precise selection and returns a chosen point', (
    tester,
  ) async {
    MeetingPoint? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await Navigator.push<MeetingPoint>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingPointScreen(
                      title: '테스트 장소',
                      initialPoint: const MeetingPoint(37.5, 127),
                      tileProviderFactory: () => FixtureTiles(false),
                    ),
                  ),
                );
              },
              child: const Text('지도 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('지도 열기'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지도 중앙에 핀 놓기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 위치 선택'));
    await tester.pumpAndSettle();
    expect(chosen!.latitude, closeTo(37.5, .001));
    expect(chosen!.longitude, closeTo(127, .001));
  });
  testWidgets('failed map cannot confirm a new pin and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingPointScreen(
          title: '테스트 장소',
          tileProviderFactory: () => FixtureTiles(true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('지도 배경을 불러오지 못했습니다'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '이 위치 선택'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('meeting form and map remain usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in [
      FamilyScreen(store: MemoryStore()),
      MeetingPointScreen(
        title: '첫 번째 만남 장소',
        initialPoint: const MeetingPoint(37.5, 127),
        tileProviderFactory: () => FixtureTiles(false),
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
