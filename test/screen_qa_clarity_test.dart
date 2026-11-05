import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/guidelines_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  testWidgets('guidelines tab uses the same emergency entry as home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const GuidelinesScreen()),
    );
    await tester.pumpAndSettle();
    final entry = find.text('지금 할 행동 보기');
    expect(entry, findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(of: entry, matching: find.byType(FilledButton)),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppPalette.alert,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    // Like home, people confirm the alert kind first.
    expect(find.text('받은 경보 선택'), findsOneWidget);
  });
}
