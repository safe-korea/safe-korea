import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/meeting_point_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/widgets/shelter_map.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'helpers/map_tiles.dart';

void main() {
  for (final view in [
    (const Size(375, 812), 3.0),
    (const Size(568, 320), 2.0),
    (const Size(1024, 768), 2.0),
  ]) {
    testWidgets('meeting map actions remain reachable $view', (tester) async {
      tester.view.physicalSize = view.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(view.$2)),
            child: child!,
          ),
          home: MeetingPointScreen(
            title: '첫 번째 만남 장소',
            initialPoint: const MeetingPoint(37.5, 127),
            tileProviderFactory: () => FixtureTiles(false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('지도 중앙에 핀 놓기'));
      expect(find.text('지도 중앙에 핀 놓기').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('이 위치 선택'));
      expect(find.text('이 위치 선택').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'native initialization failure preserves coordinates and offers retry',
    (tester) async {
      const channel = MethodChannel('flutter_kakao_maps_sdk');
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            attempts++;
            throw PlatformException(code: 'offline');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: MeetingPointScreen(
            title: '가족 장소',
            initialPoint: MeetingPoint(37.5, 127),
            configuration: MapConfiguration(
              nativeAppKey: 'test-only-no-network',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('지도 배경을 불러오지 못했습니다'), findsOneWidget);
      expect(find.textContaining('37.50000, 127.00000'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '이 위치 선택'))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('지도 다시 시도'));
      await tester.tap(find.text('지도 다시 시도'));
      await tester.pumpAndSettle();
      expect(find.textContaining('37.50000, 127.00000'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
