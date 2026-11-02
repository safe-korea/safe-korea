import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/meeting_share_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('open native share sheet with public fixture, never send', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const MeetingShareScreen(
          plan: FamilyPlan(
            meetingPlace: '서울시청 앞 · 공유 테스트',
            meetingPoint: MeetingPoint(37.5665, 126.978),
            backupPlace: '광화문 광장 · 공유 테스트',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isIOS) await binding.takeScreenshot('family-share-preview');
    await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
    await tester.tap(find.text('카카오톡 등으로 공유'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    debugPrint('SHARE_SHEET_READY_PUBLIC_FIXTURE');
    // Allow host capture of native UI. Do not select a recipient or send.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 15)),
    );
    expect(find.textContaining('공유 창을 열지 못했습니다'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
