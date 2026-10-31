import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/shelter.dart';

Map<String, dynamic> record(String id, double lat) => {
  'id': id,
  'name': '테스트 전용',
  'address': '가상 테스트 주소',
  'latitude': lat,
  'longitude': 127.0,
  'updatedAt': '2026-01-01',
  'status': 'designated',
};
Map<String, dynamic> catalog(List<Map<String, dynamic>> items) => {
  'schemaVersion': 1,
  'sourceName': '테스트 전용',
  'sourceUrl': 'https://www.data.go.kr/data/15021098/standard.do',
  'retrievedAt': '2026-10-31',
  'coverage': '테스트 전용',
  'status': 'verified',
  'items': items,
};
void main() {
  test('bundled catalog honestly has no unverified facilities', () {
    final json = jsonDecode(
      File('assets/shelters.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final data = ShelterCatalog.fromJson(json);
    if (json['status'] == 'unavailable') expect(data.shelters, isEmpty);
  });
  test('distance is meters and nearest sorting does not mutate original', () {
    final data = ShelterCatalog.fromJson(
      catalog([record('far', 37.6), record('near', 37.501)]),
    );
    expect(data.nearest(37.5, 127).first.id, 'near');
    expect(data.shelters.first.id, 'far');
    expect(data.shelters.last.distanceFrom(37.5, 127), closeTo(111.2, 1));
    expect(data.shelters.last.distanceFrom(37.501, 127), 0);
  });
  test('projected, missing, released and duplicate facilities rejected', () {
    for (final row in [
      record('x', 200000),
      record('x', double.nan),
      {...record('x', 37.5), 'status': 'released'},
      {...record('x', 37.5), 'name': ''},
    ]) {
      expect(
        () => ShelterCatalog.fromJson(catalog([row])),
        throwsFormatException,
      );
    }
    expect(
      () => ShelterCatalog.fromJson(
        catalog([record('x', 37.5), record('x', 37.6)]),
      ),
      throwsFormatException,
    );
    expect(
      () => ShelterCatalog.fromJson({
        ...catalog([record('x', 37.5)]),
        'retrievedAt': null,
      }),
      throwsFormatException,
    );
  });
}
