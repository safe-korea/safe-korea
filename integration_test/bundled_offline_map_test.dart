import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/models/offline_area.dart';
import 'package:safe_korea/screens/offline_map_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled streets and official pins render without a map SDK', (
    tester,
  ) async {
    final area = await OfflineArea.load();
    final station = area.catalog.shelters.firstWhere(
      (s) => s.name.contains('승강장'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: OfflineMapScreen(initialId: station.id),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    expect(find.text(station.address), findsOneWidget);
    await binding.takeScreenshot(
      'bundled-offline-map-${Platform.operatingSystem}',
    );
    await tester.tap(find.byTooltip('지도 확대'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot(
      'bundled-offline-map-zoom-${Platform.operatingSystem}',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
