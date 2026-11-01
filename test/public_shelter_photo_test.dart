import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/models/public_shelter_photo.dart';
import 'package:safe_korea/widgets/public_shelter_photo.dart';

Map<String, dynamic> matchedRecord() => {
  'schemaVersion': 1,
  'sourceName': '국민안전24',
  'sourceUrl': officialMapSource,
  'retrievedAt': '2026-11-01T00:00:00Z',
  'coverage': '서울특별시 중구',
  'areaCode': '11140',
  'status': 'verified',
  'items': [
    {
      'id': 'S201200008',
      'name': '서울특별시청 지하1~4층',
      'address': '서울특별시 중구 세종대로 110, 서울특별시청 지하1~4층 민방위 대피시설',
      'latitude': 37.56695,
      'longitude': 126.97794166666667,
      'updatedAt': null,
      'status': 'official_listing',
    },
  ],
};
void main() {
  test(
    'licensed photo requires exact official identity, address and location',
    () {
      var catalog = ShelterCatalog.fromJson(matchedRecord());
      expect(
        PublicShelterPhoto.match(catalog, catalog.shelters.single),
        isNotNull,
      );
      for (final change in <String, dynamic>{
        'id': 'OTHER',
        'name': '서울시청 비슷한 이름',
        'address': '서울특별시 중구 세종대로 1100, 다른 건물',
        'latitude': 37.6,
      }.entries) {
        final raw = matchedRecord();
        (raw['items'] as List).single[change.key] = change.value;
        catalog = ShelterCatalog.fromJson(raw);
        expect(
          PublicShelterPhoto.match(catalog, catalog.shelters.single),
          isNull,
        );
      }
      for (final change in <String, dynamic>{
        'sourceUrl': 'https://www.data.go.kr/data/15021098/standard.do',
        'areaCode': '11110',
      }.entries) {
        final raw = matchedRecord()..[change.key] = change.value;
        catalog = ShelterCatalog.fromJson(raw);
        expect(
          PublicShelterPhoto.match(catalog, catalog.shelters.single),
          isNull,
        );
      }
    },
  );
  testWidgets(
    'bundled public photo renders without network and retains attribution and entrance limitation on enlargement',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicShelterPhotoCard(photo: PublicShelterPhoto.cityHall),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.textContaining('Sadopaul (Gyuwon Lee) · CC BY-SA 4.0'),
        findsOneWidget,
      );
      expect(find.text('촬영 2026-06-03 · 대피 출입구 사진 아님'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('공개 사진 크게 보기'));
      await tester.tap(find.text('공개 사진 크게 보기'));
      await tester.pumpAndSettle();
      expect(find.text('공개 건물 사진 · 출입구 아님'), findsOneWidget);
      expect(
        find.textContaining('촬영 2026-06-03 · Wikimedia Commons'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
