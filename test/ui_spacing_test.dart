import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/widgets/common.dart';
import 'package:safe_korea/widgets/public_support_links.dart';

void main() {
  testWidgets('home drill outline stays separate from guideline card border', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    final drill = find
        .ancestor(
          of: find.text('모의 공습경보 시작'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        )
        .first;
    final card = find
        .ancestor(of: find.text('상황별 행동강령'), matching: find.byType(Card))
        .first;
    final surface = find
        .descendant(of: card, matching: find.byType(Material))
        .first;
    expect(
      tester.getTopLeft(surface).dy - tester.getBottomLeft(drill).dy,
      greaterThanOrEqualTo(12),
    );
  });

  testWidgets('adjacent action card surfaces have a consistent visible gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PageBody(
            children: [
              ActionTile(
                icon: Icons.book,
                title: '첫 안내',
                subtitle: '내용',
                onTap: () {},
              ),
              ActionTile(
                icon: Icons.map,
                title: '둘째 안내',
                subtitle: '내용',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final surfaces = find.descendant(
      of: find.byType(Card),
      matching: find.byType(Material),
    );
    expect(
      tester.getTopLeft(surfaces.at(1)).dy -
          tester.getBottomLeft(surfaces.at(0)).dy,
      greaterThanOrEqualTo(12),
    );
  });

  testWidgets('privacy and support outlines do not share a touching edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: PageBody(children: [PublicSupportLinks()])),
      ),
    );
    final buttons = find.byWidgetPredicate((w) => w is OutlinedButton);
    expect(
      tester.getTopLeft(buttons.at(1)).dy -
          tester.getBottomLeft(buttons.at(0)).dy,
      greaterThanOrEqualTo(12),
    );
  });
}
