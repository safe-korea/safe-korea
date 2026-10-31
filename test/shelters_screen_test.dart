import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_korea/screens/shelters_screen.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/shelter_repository.dart';

class CacheStore extends LocalStore {
  Map<String, dynamic>? cached;
  @override
  Future<Map<String, dynamic>?> loadShelterCatalog() async => cached;
  @override
  Future<void> saveShelterCatalog(Map<String, dynamic> value) async {
    cached = value;
  }
}

void main() {
  testWidgets(
    'regional query caches results, failure preserves them, reopening needs no network',
    (tester) async {
      final store = CacheStore();
      var requests = 0;
      var fail = false;
      final repository = ShelterRepository(
        store: store,
        client: MockClient((request) async {
          requests++;
          if (fail) return http.Response('unavailable', 503);
          return http.Response(
            jsonEncode({
              'totalCnt': 1,
              'facilitiesVO': {
                'tableNm': 'TFK_CIVIL_EMR_FACL_TEMP',
                'tableKorNm': '민방위대피소',
                'gubun': '2',
                'sggCd': '11110',
              },
              'mapList': [
                {
                  'facilCode': 'test',
                  'facilNm': '합성 테스트 대피소',
                  'facilRdAddr': '테스트 주소',
                  'facilLade': 37,
                  'facilLami': 30,
                  'facilLase': 0,
                  'facilLode': 127,
                  'facilLomi': 0,
                  'facilLose': 0,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SheltersScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
      await tester.tap(find.text('선택 지역 대피소 불러오기'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('합성 테스트 대피소'), findsOneWidget);
      expect(find.textContaining('1건을 받아 기기에 저장했습니다'), findsOneWidget);
      expect(store.cached, isNotNull);
      fail = true;
      await tester.ensureVisible(find.text('지역 변경'));
      await tester.tap(find.text('지역 변경'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('선택 지역 대피소 불러오기'));
      await tester.tap(find.text('선택 지역 대피소 불러오기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('공식 시설 조회에 실패했습니다'), findsOneWidget);
      expect(find.text('합성 테스트 대피소'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: SheltersScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('합성 테스트 대피소'), findsOneWidget);
      expect(find.textContaining('현재 표시 범위: 서울특별시 종로구'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repository.close();
    },
  );
}
