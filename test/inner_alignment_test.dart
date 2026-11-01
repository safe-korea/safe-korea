import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/common.dart';

void main() {
  testWidgets(
    'expanded guideline title and instructions share a content edge',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const GuidelinesScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('공습경보'));
      await tester.pumpAndSettle();
      final titleX = tester.getTopLeft(find.text('대피 장소')).dx;
      final step = find.text('민방위 대피소나 지하시설, 또는 콘크리트 건물 안 유리창 없는 곳으로 대피하세요.');
      expect(tester.getTopLeft(step).dx, titleX);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'metadata values align and stack at large text without clipping',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: PageBody(
                children: [
                  InfoLine(label: '출처', value: '국민안전24'),
                  InfoLine(label: '공식 자료 조회', value: '2026.11.01 10:30'),
                ],
              ),
            ),
          ),
        );
        expect(
          tester.getTopLeft(find.text('국민안전24')).dx,
          tester.getTopLeft(find.text('2026.11.01 10:30')).dx,
        );
        if (scale == 2) {
          expect(
            tester.getTopLeft(find.text('출처')).dx,
            tester.getTopLeft(find.text('국민안전24')).dx,
          );
          expect(
            tester.getTopLeft(find.text('국민안전24')).dy,
            greaterThan(tester.getTopLeft(find.text('출처')).dy),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
