import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/widgets/radio_link_card.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/radio_screen.dart';
import 'package:safe_korea/screens/supplies_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'app_completion_test.dart' show PreparationMemoryStore;

void main() {
  testWidgets(
    'radio opens official URL only after a tap and blocks duplicate requests',
    (tester) async {
      final pending = Completer<bool>();
      final urls = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadioLinkCard(
              open: (uri) {
                urls.add(uri);
                return pending.future;
              },
            ),
          ),
        ),
      );
      expect(urls, isEmpty);
      await tester.tap(find.text('KBS 라디오 연결'));
      await tester.pump();
      expect(urls.single.toString(), 'https://radio.kbs.co.kr/kong.html');
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('KBS 라디오 연결'), findsOneWidget);
    },
  );
  testWidgets('radio failure offers copy and retry without claiming playback', (
    tester,
  ) async {
    var calls = 0;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RadioLinkCard(
              open: (_) async {
                calls++;
                if (calls == 1) throw StateError('unavailable');
                return false;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('KBS 라디오 연결'));
    await tester.pumpAndSettle();
    expect(find.textContaining('연결을 열지 못했어요'), findsOneWidget);
    await tester.ensureVisible(find.text('공식 주소 복사'));
    await tester.tap(find.text('공식 주소 복사'));
    await tester.pumpAndSettle();
    expect(copied, kbsRadioUri.toString());
    await tester.ensureVisible(find.text('KBS 라디오 연결'));
    await tester.tap(find.text('KBS 라디오 연결'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('연결을 열지 못했어요'), findsOneWidget);
  });
  testWidgets(
    'preparation routes expose radio and honest unconnected supplier state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReadinessScreen(store: PreparationMemoryStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('비상용품 준비'));
      await tester.tap(find.text('비상용품 준비'));
      await tester.pumpAndSettle();
      expect(find.byType(SuppliesScreen), findsOneWidget);
      await tester.ensureVisible(find.textContaining('현재 연결된 판매처가 없습니다'));
      expect(find.byType(FilledButton), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('라디오 연결'));
      await tester.tap(find.text('라디오 연결'));
      await tester.pumpAndSettle();
      expect(find.byType(RadioScreen), findsOneWidget);
      expect(find.text('KBS 라디오 연결'), findsOneWidget);
    },
  );
  for (final viewport in [
    (const Size(375, 812), 3.0),
    (const Size(568, 320), 2.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets('radio and supplies layout $viewport', (tester) async {
      tester.view.physicalSize = viewport.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final screen in [
        const RadioScreen(),
        const SuppliesScreen(),
        const AfterArrivalScreen(training: true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(viewport.$2)),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        if (screen is SuppliesScreen) {
          await tester.ensureVisible(find.textContaining('현재 연결된 판매처가 없습니다'));
        } else {
          await tester.ensureVisible(find.text('KBS 라디오 연결'));
          expect(find.text('KBS 라디오 연결').hitTestable(), findsOneWidget);
          if (screen is RadioScreen) {
            await tester.ensureVisible(find.text('통신이 끊겼다면'));
            await tester.tap(find.text('통신이 끊겼다면'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.textContaining('이 앱의 연결 버튼은 오프라인'));
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
