import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;
import 'package:safe_korea/models/shelter_cluster.dart';
import 'package:safe_korea/services/shelter_repository.dart';
import 'package:safe_korea/widgets/shelter_map.dart';

// Explicit live test: requires an authorized local key and one official
// regional lookup. Never changes the user's database or sends alerts.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kakao authenticates and creates official shelter pins', (
    tester,
  ) async {
    expect(const MapConfiguration().hasKakaoKey, isTrue);
    final repository = ShelterRepository();
    try {
      final catalog = await repository.fetch('11110', '서울특별시 종로구');
      expect(catalog.shelters, isNotEmpty);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('카카오 지도 연결 검증')),
            body: ShelterMap(shelters: catalog.shelters, onSelected: (_) {}),
          ),
        ),
      );
      // Wait beyond the production readiness watchdog: finding a map widget
      // alone before authentication completes would be a false success.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(kakao.KakaoMap), findsOneWidget);
      // The pinned plugin exposes controller on its private State class.
      // This diagnostic uses it to check native camera calls and registered
      // POIs, without adding test-only APIs to the production widget.
      final dynamic mapState = tester.state(find.byType(kakao.KakaoMap));
      final controller = mapState.controller as kakao.KakaoMapController;
      final camera = await controller.getCameraPosition();
      final clusters = clusterShelters(
        catalog.shelters,
        camera.zoomLevel.toDouble(),
      );
      // iOS PoiOptions in plugin 1.3.1 generates native IDs instead of using
      // the requested ID. Check its rendered pins in the captured screen;
      // Android can additionally verify the registered IDs automatically.
      if (Platform.isAndroid) {
        for (final cluster in clusters) {
          expect(controller.labelLayer.getPoi(cluster.id), isNotNull);
        }
      }
      await controller.moveCamera(
        kakao.CameraUpdate.newCenterPosition(
          kakao.LatLng(
            catalog.shelters.first.latitude,
            catalog.shelters.first.longitude,
          ),
          zoomLevel: 16,
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect((await controller.getCameraPosition()).zoomLevel, 16);
      expect(find.byType(FlutterMap), findsNothing);
      if (Platform.isAndroid) {
        for (final cluster in clusterShelters(catalog.shelters, 16)) {
          expect(controller.labelLayer.getPoi(cluster.id), isNotNull);
        }
      }
      debugPrint('KAKAO_NATIVE_CAMERA_VERIFIED: capture rendered pins now');
      const captureSeconds = int.fromEnvironment('KAKAO_CAPTURE_SECONDS');
      for (var i = 0; i < captureSeconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      repository.close();
    }
  });
}
