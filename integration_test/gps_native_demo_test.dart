// Uses the simulator's OS location, not a mocked LocationService.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart' as app;
import 'package:safe_korea/services/location_service.dart';
import 'package:safe_korea/services/shelter_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'simulator GPS immediately fetches its district and reveals nearby shelters',
    (tester) async {
      final position = await LocationService().current();
      expect(position.latitude, closeTo(37.5133, 0.001));
      expect(position.longitude, closeTo(127.1001, 0.001));
      final repository = ShelterRepository();
      addTearDown(repository.close);
      final catalog = await repository.fetch('11710', '서울특별시 송파구');
      expect(catalog.shelters, isNotEmpty);
      await repository.save(catalog);
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPS 현재 위치 확인'));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.textContaining('송파구 내 가까운 대피소').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('송파구 내 가까운 대피소'), findsOneWidget);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('gps-simulator-confirmed');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
