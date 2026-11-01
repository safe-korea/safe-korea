import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/services/shelter_repository.dart';
import 'package:safe_korea/models/public_shelter_photo.dart';
import 'package:safe_korea/widgets/public_shelter_photo.dart';
import 'package:safe_korea/widgets/shelter_street_view_button.dart';
import 'package:safe_korea/widgets/common.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'licensed public building photograph matches a live official facility and renders offline asset',
    (tester) async {
      final repo = ShelterRepository();
      final catalog = await repo.fetch('11140', '서울특별시 중구');
      repo.close();
      final shelter = catalog.shelters.singleWhere((s) => s.id == 'S201200008');
      final photo = PublicShelterPhoto.match(catalog, shelter);
      expect(photo, isNotNull);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('공개된 건물 사진')),
            body: PageBody(
              children: [
                Text(shelter.name),
                const SizedBox(height: 16),
                PublicShelterPhotoCard(photo: photo!),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('대피 출입구 사진 아님'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.isIOS) await binding.takeScreenshot('public-building-photo');
    },
  );
  testWidgets(
    'public roadview opens from an actual official facility coordinate',
    (tester) async {
      final repo = ShelterRepository();
      final catalog = await repo.fetch('11110', '서울특별시 종로구');
      repo.close();
      final matches = catalog.shelters
          .where((s) => s.id == 'S200700195')
          .toList();
      expect(matches, hasLength(1));
      final shelter = matches.single;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('대피소 주변 모습')),
            body: PageBody(
              children: [
                Text(
                  shelter.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(shelter.address),
                const SizedBox(height: 20),
                ShelterStreetViewButton(shelter: shelter),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.isIOS) await binding.takeScreenshot('public-roadview-entry');
      if (const bool.fromEnvironment('CHECK_LIVE_ROADVIEW')) {
        await tester.tap(find.text('주변 실제 모습 보기'));
        // Provider's browser UI must be checked via a native screenshot; a successful
        // URL launch alone does not verify that imagery exists or is an entrance.
        await tester.pump(const Duration(seconds: 12));
        expect(find.textContaining('로드뷰를 열지 못했어요'), findsNothing);
        expect(find.textContaining('시설 좌표를 확인하지 못했어요'), findsNothing);
      }
    },
  );
}
