import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;
import 'package:safe_korea/screens/meeting_point_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('family Kakao map selects, zooms, returns and reopens a pin', (
    tester,
  ) async {
    MeetingPoint? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<MeetingPoint>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeetingPointScreen(
                      title: '가족 장소 · 테스트',
                      initialPoint: MeetingPoint(37.5665, 126.978),
                    ),
                  ),
                );
              },
              child: const Text('장소 선택'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('장소 선택'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(kakao.KakaoMap), findsOneWidget);
    final dynamic mapState = tester.state(find.byType(kakao.KakaoMap));
    final controller = mapState.controller as kakao.KakaoMapController;
    expect((await controller.getCameraPosition()).zoomLevel, 16);
    if (Platform.isAndroid) {
      expect(controller.labelLayer.getPoi('family-meeting-point'), isNotNull);
    }
    await tester.tap(find.byTooltip('지도 확대'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect((await controller.getCameraPosition()).zoomLevel, 17);
    await controller.moveCamera(
      kakao.CameraUpdate.newCenterPosition(
        const kakao.LatLng(37.567, 126.979),
        zoomLevel: 16,
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final target = (await controller.getCameraPosition()).position;
    expect(target.latitude, closeTo(37.567, .0001));
    expect(target.longitude, closeTo(126.979, .0001));
    final coordinates =
        '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}';
    await tester.ensureVisible(find.text('지도 중앙에 핀 놓기'));
    await tester.tap(find.text('지도 중앙에 핀 놓기'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining(coordinates), findsOneWidget);
    await tester.ensureVisible(find.text('이 위치 선택'));
    if (Platform.isIOS) await binding.takeScreenshot('meeting-kakao-edit');
    await tester.tap(find.text('이 위치 선택'));
    await tester.pumpAndSettle();
    expect(selected!.latitude, closeTo(target.latitude, .000001));
    expect(selected!.longitude, closeTo(target.longitude, .000001));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MeetingPointScreen(
          title: '저장한 가족 장소 · 테스트',
          initialPoint: selected,
          readOnly: true,
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(kakao.KakaoMap), findsOneWidget);
    expect(find.text('이 위치 선택'), findsNothing);
    expect(find.textContaining(coordinates), findsOneWidget);
    if (Platform.isIOS) await binding.takeScreenshot('meeting-kakao-readonly');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
