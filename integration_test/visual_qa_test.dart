import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/screens/drill_screen.dart';
import 'package:safe_korea/screens/notification_test_screen.dart';
import 'package:safe_korea/screens/alert_guide_screen.dart';
import 'package:safe_korea/theme/app_theme.dart';
import 'package:safe_korea/screens/family_screen.dart';
import 'package:safe_korea/screens/readiness_screen.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';

// Synthetic plan only; never read or write the owner's family details.
class VisualQaStore extends LocalStore {
  @override
  Future<FamilyPlan> load() async => const FamilyPlan(
    meetingPlace: 'QA 만남 장소 · 사전에 정한 출입구',
    backupPlace: 'QA 대체 장소',
    note: '연락이 어려우면 미리 정한 장소에서 만나요.',
  );
  @override
  Future<Set<String>> loadPreparation() async => {};
  @override
  Future<List<Map<String, dynamic>>> loadSavedShelters() async => [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('visual QA: guidance and silent training screens', (
    tester,
  ) async {
    final store = VisualQaStore();
    final saved = SavedSheltersController(store: store);
    await saved.ensureLoaded();
    addTearDown(saved.dispose);
    for (final scale in [1.0, 2.0]) {
      for (final entry in <String, Widget>{
        'drill': const DrillScreen(),
        'notification': const NotificationTestScreen(),
        'guide': const AlertGuideScreen(),
        'family': FamilyScreen(store: store),
        'readiness': ReadinessScreen(store: store),
        'saved-empty': SavedSheltersScreen(controller: saved),
        'arrival': const AfterArrivalScreen(training: true),
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('${entry.key}-$scale'),
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: entry.value,
          ),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('qa-${entry.key}-$scale-top');
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -650),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('qa-${entry.key}-$scale-scroll');
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
