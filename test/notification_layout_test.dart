import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/notification_test_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('notification layout remains readable at $size and 2x text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const NotificationTestScreen(),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['이 설정으로 알림 보내기', '알림 지우기', '소리 없이 행동 연습', '소리 안내 자세히']) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('소리 안내 자세히'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('종류는 문자·방송으로 확인하세요.'));
      expect(tester.takeException(), isNull);
      final buttons = [
        find.widgetWithText(OutlinedButton, '이 설정으로 알림 보내기'),
        find.widgetWithText(TextButton, '알림 지우기'),
      ];
      expect(tester.getRect(buttons[0]).left, tester.getRect(buttons[1]).left);
      expect(
        tester.getRect(buttons[0]).width,
        tester.getRect(buttons[1]).width,
      );
    });
  }
}
