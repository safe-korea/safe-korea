import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/offline_area.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/offline_map_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled real map has independent official facilities and OSM provenance',
    () async {
      final area = await OfflineArea.load();
      expect(area.catalog.shelters, hasLength(22));
      expect(area.catalog.sourceUrl, officialMapSource);
      expect(area.catalog.shelters.every(OfflineArea.covers), isTrue);
      expect(area.map['license'], 'ODbL 1.0');
      expect((area.map['features'] as List).length, greaterThan(100));
      expect(area.map['bounds'], [
        OfflineArea.west,
        OfflineArea.south,
        OfflineArea.east,
        OfflineArea.north,
      ]);
    },
  );
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'offline map selection, zoom and sources fit $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final area = (await tester.runAsync(OfflineArea.load))!;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: OfflineMapScreen(initialId: area.catalog.shelters.first.id),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(find.text(area.catalog.shelters.first.address), findsOneWidget);
        await tester.tap(find.byTooltip('지도 확대'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('전체 범위'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('출처·범위'));
        await tester.pumpAndSettle();
        expect(find.textContaining('전국 지도는 아닙니다'), findsOneWidget);
        expect(find.textContaining('OpenStreetMap contributors'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
