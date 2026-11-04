import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/meeting_share_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'map_and_saved_shelters_test.dart' show SavedMemoryStore, fixture;

const longPlan = FamilyPlan(
  meetingPlace: '가족이 미리 정해 둔 첫 번째 만남 장소의 긴 이름과 출입구 설명',
  backupPlace: '첫 번째 장소에 접근하기 어려울 때 만날 대체 장소의 긴 이름',
  note: '연락이 어려울 때 참고할 가족 약속입니다.',
  meetingPoint: MeetingPoint(37.5665, 126.978),
);

class QaStore extends LocalStore {
  @override
  Future<FamilyPlan> load() async => longPlan;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('internal long content remains usable at 320px scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> mount(Widget page) async {
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
        expect(tester.takeException(), isNull);
      }

      Future<void> tapText(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await mount(FamilyScreen(store: QaStore()));
      expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
      await tapText('가족 약속 보기');
      await tapText('가족에게 공유');
      expect(find.byType(MeetingShareScreen), findsOneWidget);
      await tapText('전송 내용 전체 보기');
      await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
      expect(find.text('카카오톡 등으로 공유').hitTestable(), findsOneWidget);
      final saved = SavedSheltersController(store: SavedMemoryStore());
      await saved.ensureLoaded();
      addTearDown(saved.dispose);
      final catalog = fixture('11110', '테스트 지역', '긴 이름의 시설과 출입구 설명');
      await saved.toggle(catalog, catalog.shelters.first.id);
      // Asset futures must not cross test fake-async zones.
      rootBundle.clear();
      await mount(SheltersScreen(catalog: catalog, savedShelters: saved));
      final savedEntry = find.textContaining('· 오프라인 목록');
      await tester.ensureVisible(savedEntry);
      await tester.tap(savedEntry);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SavedSheltersScreen), findsOneWidget);
      expect(find.text(catalog.shelters.first.name), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapText(catalog.shelters.first.name);
      await tapText('시설 자료 상세');
      await tester.ensureVisible(find.text('저장됨 · 저장 해제'));
      expect(find.text('저장됨 · 저장 해제').hitTestable(), findsOneWidget);
      await mount(SavedSheltersScreen(controller: saved));
      await tapText('조회·저장 정보');
      await tester.ensureVisible(find.text('공식 자료 다시 확인'));
      expect(find.text('공식 자료 다시 확인').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
