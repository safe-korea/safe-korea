import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/common.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'guide, drill action and bag share icon and text columns at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scale == 1 ? 402 : 320, 874));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Future<void> mount(Widget page) async {
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
          await tester.pump();
        }

        void checkColumns() {
          for (final element in find.byType(IconTextBlock).evaluate()) {
            final block = find.byWidget(element.widget);
            final title = find
                .descendant(of: block, matching: find.byType(Text))
                .first;
            final iconBox = find
                .descendant(of: block, matching: find.byType(Container))
                .first;
            // Page 20 + card inset 16 + icon 44 + gap 12.
            expect(tester.getTopLeft(title).dx, scale == 1 ? 92 : 36);
            expect(tester.getTopLeft(iconBox).dx, 36);
            expect(
              tester.getTopLeft(title).dy,
              tester.getTopLeft(iconBox).dy + (scale == 1 ? 0 : 56),
            );
          }
          expect(tester.takeException(), isNull);
        }

        await mount(const AlertGuideScreen());
        checkColumns();
        await mount(const DrillScreen());
        checkColumns();
        expect(
          tester.getTopLeft(find.text('가까운 대피소로 이동')).dx,
          tester.getTopLeft(find.text('손 닿는 곳에 있으면 챙기세요')).dx,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
