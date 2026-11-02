import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'walk through tabs, all guidance, drill and return paths without modifying user data',
    (tester) async {
      await tester.pumpWidget(const SafeKoreaApp());
      await tester.pumpAndSettle();
      Future<void> tab(int index) async {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tab(2);
      final data = jsonDecode(
        await rootBundle.loadString('assets/guidelines.json'),
      ) as Map<String, dynamic>;
      for (final item in data['items'] as List) {
        final title = find.text(item['title'] as String);
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        for (final step in item['steps'] as List) {
          await tester.ensureVisible(find.text(step as String));
          expect(find.text(step).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
      }
      await tab(0);
      await tester.ensureVisible(find.text('모의 공습경보 시작'));
      await tester.tap(find.text('모의 공습경보 시작'));
      await tester.pumpAndSettle();
      expect(find.text('훈련 / 테스트'), findsOneWidget);
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      await tester.tap(find.text('실외'));
      await tester.pumpAndSettle();
      expect(find.text('가까운 건물로 대피'), findsOneWidget);
      await tester.tap(find.text('훈련 종료 · 홈으로'));
      await tester.pumpAndSettle();
      await tab(3);
      await tester.tap(find.text('가족 만남 장소'));
      await tester.pumpAndSettle();
      expect(find.byType(FamilyScreen), findsOneWidget);
      expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tab(1);
      final savedButton = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message?.startsWith('저장한 대피소 (') == true,
      );
      await tester.tap(savedButton);
      await tester.pumpAndSettle();
      expect(find.byType(SavedSheltersScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tab(0);
      expect(find.text('모의 공습경보 시작'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
