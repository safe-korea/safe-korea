import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/widgets/shelter_map.dart';
import 'package:safe_korea/widgets/shelter_pin.dart';

class PreparationMemoryStore extends LocalStore {
  Set<String> values = {};
  bool failSave = false;
  @override
  Future<Set<String>> loadPreparation() async => {...values};
  @override
  Future<void> savePreparation(Set<String> next) async {
    if (failSave) throw StateError('test failure');
    values = {...next};
  }
}

void main() {
  testWidgets(
    'bottom navigation switches screens and system back returns home',
    (tester) async {
      await tester.pumpWidget(const SafeKoreaApp());
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.textContaining('오프라인 저장됨'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('province-11')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('province-11')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('부산광역시').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(find.text('부산광역시'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('모의 공습경보 시작'), findsOneWidget);
    },
  );
  testWidgets(
    'preparedness checks save, survive reopening and preserve prior value on failure',
    (tester) async {
      final store = PreparationMemoryStore();
      await tester.pumpWidget(MaterialApp(home: ReadinessScreen(store: store)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('생수 · 간편식'));
      await tester.tap(find.text('생수 · 간편식'));
      await tester.pumpAndSettle();
      expect(store.values, {'water'});
      store.failSave = true;
      await tester.tap(find.text('상비약 · 개인 복용약'));
      await tester.pumpAndSettle();
      expect(store.values, {'water'});
      expect(find.textContaining('체크를 저장하지 못했습니다'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: ReadinessScreen(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('체크한 준비물 1 / 8'), findsOneWidget);
    },
  );
  testWidgets(
    'missing Kakao key keeps the app usable and shelter pin opens details',
    (tester) async {
      const shelter = Shelter(
        id: 'test-only',
        name: '테스트 전용',
        address: '테스트 주소',
        latitude: 37.5,
        longitude: 127,
        updatedAt: null,
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ShelterMap(
                configuration: const MapConfiguration(nativeAppKey: ''),
                shelters: const [shelter],
                onSelected: (value) => selected = value.id,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('기본 지도'), findsOneWidget);
      await tester.tap(find.byType(ShelterPin));
      expect(selected, 'test-only');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
