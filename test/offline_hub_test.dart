import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/screens/offline_hub_screen.dart';
import 'package:safe_korea/services/connection_monitor.dart';

void main() {
  testWidgets(
    'offline home groups local tools without interrupting an open guide',
    (tester) async {
      final monitor = ConnectionMonitor(
        readLink: () async => false,
        changes: const Stream.empty(),
        probe: () async => true,
      );
      addTearDown(monitor.dispose);
      await tester.pumpWidget(SafeKoreaApp(monitor: monitor));
      await monitor.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(OfflineHubScreen), findsOneWidget);
      for (final label in ['지금 할 행동 보기', '저장한 대피소', '가족 만남 장소', '비상배낭 체크리스트']) {
        expect(find.text(label), findsOneWidget);
      }
      // Right after the banner appears the page has just moved: taps are
      // ignored briefly so they cannot land on a different button.
      await tester.tap(find.text('지금 할 행동 보기'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('지금 할 행동 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      monitor.value = LinkStatus.available;
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      monitor.value = LinkStatus.offline;
      await tester.pumpAndSettle();
      expect(find.byType(AlertGuideScreen), findsOneWidget);
      expect(find.text('연결 없음 · 오프라인 기능 보기'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('연결 없음 · 오프라인 기능 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(OfflineHubScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
