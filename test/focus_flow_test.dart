import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/action_brief.dart';

void main() {
  testWidgets(
    'core actions are reachable from the initial phone home without scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SafeKoreaApp());
      await tester.pumpAndSettle();
      for (final label in ['지금 할 행동 보기', '저장한 대피소', '가족 만남 장소', '비상배낭 체크리스트']) {
        expect(
          find.text(label).hitTestable(),
          findsOneWidget,
          reason: 'First-screen access: $label',
        );
      }
      await tester.tap(find.text('지금 할 행동 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      expect(find.text('훈련 / 테스트'), findsNothing);
      expect(find.textContaining('자동 수신'), findsOneWidget);
      expect(find.byType(ActionBriefTile), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('공습경보').last);
      await tester.pumpAndSettle();
      expect(find.text('실내').hitTestable(), findsOneWidget);
    },
  );
  testWidgets(
    'one context tap reveals first action on a small phone, without scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const AlertGuideScreen()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('실내')).dy,
        tester.getTopLeft(find.text('차량')).dy,
      );
      for (final pair in [
        ('실내', '계단으로 이동'),
        ('실외', '가까운 건물로 대피'),
        ('차량', '운전 중이면 정차 후 대피'),
      ]) {
        expect(find.text(pair.$1).hitTestable(), findsOneWidget);
        await tester.tap(find.text(pair.$1));
        await tester.pumpAndSettle();
        expect(
          find.text(pair.$2).hitTestable(),
          findsOneWidget,
          reason: 'First action for ${pair.$1} must be on screen',
        );
      }
      expect(
        tester.getRect(find.byType(ActionBriefTile).first).bottom,
        lessThanOrEqualTo(560),
        reason: 'The complete primary instruction, including its conditions, must fit',
      );
      await tester.tap(find.byTooltip('선택 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('가까운 대피소로 이동').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
