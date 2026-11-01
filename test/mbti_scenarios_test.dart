// MBTI labels identify fictional QA scenarios, not personality predictions.
// All storage, clipboard, notifications and sharing are isolated test doubles.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/home_screen.dart';
import 'package:safe_korea/screens/meeting_share_screen.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/shelter_map.dart';
import 'package:safe_korea/widgets/drill_elapsed_timer.dart';

import 'drill_elapsed_timer_test.dart' show TestWatch;

import 'package:safe_korea/widgets/shelter_pin.dart';

import 'app_completion_test.dart' show PreparationMemoryStore;
import 'helpers/map_tiles.dart';
import 'local_store_test.dart' show MemoryStore;
import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;
import 'meeting_share_test.dart' show plan;
import 'persona_journeys_test.dart' show DeniedLocation;
import 'region_and_refresh_test.dart' show RefreshRepository;

void main() {
  setUp(() => rootBundle.clear());
  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
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

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> small(WidgetTester tester, {double height = 640}) async {
    await tester.binding.setSurfaceSize(Size(320, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('MBTI ISTJ: preparation survives reopening and can be revised', (
    tester,
  ) async {
    final store = PreparationMemoryStore();
    await mount(tester, ReadinessScreen(store: store));
    await tap(tester, '생수 · 간편식');
    await tap(tester, '손전등');
    await mount(tester, ReadinessScreen(store: store));
    expect(find.text('체크한 준비물 2 / 8'), findsOneWidget);
    await tap(tester, '손전등');
    await mount(tester, ReadinessScreen(store: store));
    expect(find.text('체크한 준비물 1 / 8'), findsOneWidget);
    expect(store.values, {'water'});
  });

  testWidgets('MBTI ISFJ: long family note does not hide places or sharing', (
    tester,
  ) async {
    await small(tester);
    final store = MemoryStore()
      ..plan = FamilyPlan(
        meetingPlace: '첫 장소',
        backupPlace: '두 번째 가족 장소',
        note: '긴 가족 약속 ' * 100,
      );
    await mount(tester, FamilyScreen(store: store), scale: 2);
    expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
    await tap(tester, '가족 약속 보기');
    await tap(tester, '가족에게 공유');
    expect(find.byType(MeetingShareScreen), findsOneWidget);
    expect(find.text('첫 장소'), findsOneWidget);
    expect(find.text('두 번째 가족 장소'), findsOneWidget);
  });

  testWidgets('MBTI INFJ: note opt-in can be revoked before another share', (
    tester,
  ) async {
    final sent = <String>[];
    await mount(
      tester,
      MeetingShareScreen(
        plan: plan,
        shareText: (text, _) async => sent.add(text),
      ),
    );
    expect(sent, isEmpty);
    await tap(tester, '가족 약속도 포함');
    await tap(tester, '카카오톡 등으로 공유');
    expect(sent.single, contains('개인 약속'));
    await tap(tester, '가족 약속도 포함');
    await tap(tester, '카카오톡 등으로 공유');
    expect(sent.last, isNot(contains('개인 약속')));
    expect(sent.every((text) => !text.contains('hidden-')), isTrue);
  });

  testWidgets(
    'MBTI INTJ: saved source and time remain distinguishable from opening status',
    (tester) async {
      final saved = SavedSheltersController(store: SavedMemoryStore());
      addTearDown(saved.dispose);
      final catalog = fixture('11110', '테스트 지역', 'source');
      await saved.ensureLoaded();
      await saved.toggle(catalog, 'source');
      await mount(tester, SavedSheltersScreen(controller: saved));
      expect(find.text('개방 여부는 현장에서 확인하세요'), findsOneWidget);
      await tap(tester, '조회·저장 정보');
      expect(find.text('공식 자료 조회'), findsOneWidget);
      expect(find.text('기기 저장'), findsOneWidget);
      expect(find.text('저장 후 다시 확인하지 않음'), findsOneWidget);
      await tester.ensureVisible(find.text('공식 출처 열기'));
      expect(find.text('공식 출처 열기').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'MBTI ISTP: explicit map pin selection identifies the chosen facility',
    (tester) async {
      final catalog = fixture('11110', '테스트 지역', 'pin');
      String? selected;
      await mount(
        tester,
        Scaffold(
          body: ShelterMap(
            configuration: const MapConfiguration(nativeAppKey: ''),
            shelters: catalog.shelters,
            tileProviderFactory: () => FixtureTiles(false),
            onSelected: (value) => selected = value.id,
          ),
        ),
      );
      expect(selected, isNull);
      await tester.tap(find.byType(ShelterPin));
      await tester.pumpAndSettle();
      expect(selected, 'pin');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'MBTI ISFP: permission refusal and silent drill do not send notifications',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final location = DeniedLocation();
      final saved = SavedSheltersController(store: SavedMemoryStore());
      addTearDown(saved.dispose);
      await mount(
        tester,
        SheltersScreen(
          catalog: fixture('11110', '테스트', 'quiet'),
          locationService: location,
          savedShelters: saved,
        ),
      );
      expect(location.calls, 0);
      await tap(tester, 'GPS 현재 위치 확인');
      expect(find.textContaining('위치 권한 없이도'), findsOneWidget);
      await mount(tester, const DrillScreen());
      await tap(tester, '실내');
      expect(find.text('계단으로 이동'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'MBTI INFP: preview and clipboard contain only selected public fields',
    (tester) async {
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await mount(tester, const MeetingShareScreen(plan: plan));
      await tap(tester, '전송 내용 전체 보기');
      expect(
        find.textContaining('https://map.kakao.com/link/map/'),
        findsOneWidget,
      );
      expect(copied, isNull);
      await tap(tester, '내용 복사');
      expect(copied, contains('첫 장소'));
      expect(copied, isNot(contains('개인 약속')));
      expect(copied, isNot(contains('hidden-')));
    },
  );

  testWidgets(
    'MBTI INTP: chemical and nuclear exceptions are directly readable',
    (tester) async {
      await mount(
        tester,
        const AlertGuideScreen(initialKind: AlertKind.chemical),
      );
      await tap(tester, '실내');
      expect(find.text('문·창문 닫기'), findsOneWidget);
      expect(find.text('무조건 지하로 가지 마세요'), findsOneWidget);
      expect(find.text('주변 대피소 보기'), findsNothing);
      await mount(
        tester,
        const AlertGuideScreen(initialKind: AlertKind.nuclear),
      );
      expect(find.text('섬광·폭발을 봤다면 엎드리기'), findsOneWidget);
      expect(find.text('폭발 전 경보라면 대피'), findsOneWidget);
      expect(find.text('폭발 후에는 낙진 피하기'), findsOneWidget);
    },
  );

  testWidgets('MBTI ESTP: urgent primary action is reachable without a form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, const HomeScreen());
    await tap(tester, '모의 공습경보 시작');
    expect(find.text('주변 대피소 보기').hitTestable(), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final button = find.widgetWithText(FilledButton, '주변 대피소 보기');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tap(tester, '훈련 종료 · 홈으로');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('MBTI ESFP: share failure offers a functioning copy fallback', (
    tester,
  ) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = call.arguments['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await mount(
      tester,
      MeetingShareScreen(
        plan: plan,
        shareText: (_, _) async => throw PlatformException(code: 'unavailable'),
      ),
    );
    await tap(tester, '카카오톡 등으로 공유');
    expect(find.textContaining('공유 창을 열지 못했습니다'), findsOneWidget);
    await tap(tester, '내용 복사');
    expect(copied, contains('첫 장소'));
    expect(find.textContaining('내용을 복사했습니다'), findsOneWidget);
  });

  testWidgets(
    'MBTI ENFP: backing out of an edit preserves the draft until a decision',
    (tester) async {
      final store = MemoryStore()..plan = plan;
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FamilyScreen(store: store),
                ),
              ),
              child: const Text('가족 계획 열기'),
            ),
          ),
        ),
      );
      await tap(tester, '가족 계획 열기');
      await tap(tester, '만남 장소 수정');
      await tester.enterText(
        find.byKey(const ValueKey('family-field-2')),
        '수정 장소',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않은 변경이 있습니다'), findsOneWidget);
      await tap(tester, '계속 작성');
      expect(store.plan.meetingPlace, '첫 장소');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '가족에게 공유'))
            .onPressed,
        isNull,
      );
      await tap(tester, '기기에 저장');
      await tap(tester, '가족에게 공유');
      expect(find.text('수정 장소'), findsOneWidget);
    },
  );

  testWidgets(
    'MBTI ENTP: failed refresh does not trap the user or erase offline data',
    (tester) async {
      final saved = SavedSheltersController(store: SavedMemoryStore());
      final repository = RefreshRepository()..fail = true;
      addTearDown(saved.dispose);
      addTearDown(repository.close);
      await saved.ensureLoaded();
      await saved.toggle(fixture('11110', '테스트', 'fallback'), 'fallback');
      await mount(
        tester,
        SavedSheltersScreen(controller: saved, repository: repository),
      );
      await tap(tester, '조회·저장 정보');
      await tap(tester, '공식 자료 다시 확인');
      expect(repository.calls, 1);
      expect(find.text('테스트 주소 fallback'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '없는 시설');
      await tester.pumpAndSettle();
      expect(find.textContaining('검색 결과가 없습니다'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('테스트 주소 fallback'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('MBTI ESTJ: preparation count reflects successful writes only', (
    tester,
  ) async {
    final store = PreparationMemoryStore();
    await mount(tester, ReadinessScreen(store: store));
    await tap(tester, '손전등');
    store.failSave = true;
    await tap(tester, '생수 · 간편식');
    expect(find.text('체크한 준비물 1 / 8'), findsOneWidget);
    expect(store.values, {'light'});
    store.failSave = false;
    await tap(tester, '생수 · 간편식');
    expect(find.text('체크한 준비물 2 / 8'), findsOneWidget);
    expect(store.values, {'light', 'water'});
  });

  testWidgets(
    'MBTI ESFJ: closing share flow does not claim delivery or family safety',
    (tester) async {
      int calls = 0;
      await mount(
        tester,
        MeetingShareScreen(
          plan: plan,
          shareText: (_, _) async {
            calls++;
          },
        ),
      );
      expect(calls, 0);
      await tap(tester, '카카오톡 등으로 공유');
      expect(calls, 1);
      expect(find.textContaining('도착 여부를 확인할 수 없습니다'), findsOneWidget);
      expect(find.text('전송 완료'), findsNothing);
      expect(find.text('가족 안전 확인 완료'), findsNothing);
    },
  );

  testWidgets(
    'MBTI ENFJ: enlarged action text remains reachable when explaining to a companion',
    (tester) async {
      await small(tester);
      await mount(tester, const AlertGuideScreen(), scale: 3);
      await tap(tester, '실내');
      for (final label in ['계단으로 이동', '유리창에서 떨어지세요', '대피 후 방송 확인']) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label).hitTestable(), findsOneWidget);
        expect(tester.widget<Text>(find.text(label)).maxLines, isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MBTI ENTJ: elapsed time never becomes an evacuation countdown', (
    tester,
  ) async {
    await mount(tester, const DrillScreen());
    expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
    expect(find.text('훈련 시작 후 경과'), findsOneWidget);
    expect(find.text('대피 여유시간 아님'), findsOneWidget);
    final watch = TestWatch();
    await mount(tester, Scaffold(body: DrillElapsedTimer(stopwatch: watch)));
    watch.value = const Duration(minutes: 6);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('대피 여유시간 아님'), findsOneWidget);
    expect(find.text('안전합니다'), findsNothing);
    expect(find.text('대피 시간 종료'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
