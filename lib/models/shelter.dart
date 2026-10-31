import 'dart:math';

class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });
  final String id, name, address, updatedAt;
  final double latitude, longitude;

  factory Shelter.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num).toDouble();
    final lon = (json['longitude'] as num).toDouble();
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 33 ||
        lat > 39.5 ||
        lon < 124 ||
        lon > 132) {
      throw const FormatException('대한민국 범위를 벗어난 좌표');
    }
    for (final key in ['id', 'name', 'address', 'updatedAt']) {
      if (json[key] is! String || (json[key] as String).trim().isEmpty) {
        throw FormatException('시설 필수 정보 누락: $key');
      }
    }
    if (json['status'] != 'designated') {
      throw const FormatException('지정 상태가 확인되지 않은 시설');
    }
    DateTime.parse(json['updatedAt'] as String);
    return Shelter(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: lat,
      longitude: lon,
      updatedAt: json['updatedAt'],
    );
  }

  double distanceFrom(double lat, double lon) {
    double radians(double value) => value * pi / 180;
    final a =
        pow(sin(radians(latitude - lat) / 2), 2) +
        cos(radians(lat)) *
            cos(radians(latitude)) *
            pow(sin(radians(longitude - lon) / 2), 2);
    return 6371000 * 2 * atan2(sqrt(a.clamp(0, 1)), sqrt((1 - a).clamp(0, 1)));
  }
}

class ShelterCatalog {
  ShelterCatalog.fromJson(Map<String, dynamic> json)
    : sourceName = json['sourceName'] as String,
      sourceUrl = json['sourceUrl'] as String,
      retrievedAt = json['retrievedAt'] as String?,
      coverage = json['coverage'] as String,
      shelters = [] {
    if (json['schemaVersion'] != 1 ||
        sourceUrl != 'https://www.data.go.kr/data/15021098/standard.do') {
      throw const FormatException('지원하지 않는 데이터 출처 또는 버전');
    }
    if ((json['items'] as List).isNotEmpty &&
        (retrievedAt == null || json['status'] != 'verified')) {
      throw const FormatException('공식 자료 확인 정보 누락');
    }
    final ids = <String>{};
    for (final item in json['items'] as List) {
      final shelter = Shelter.fromJson(Map<String, dynamic>.from(item as Map));
      if (!ids.add(shelter.id)) throw const FormatException('중복 시설 ID');
      shelters.add(shelter);
    }
  }
  final String sourceName, sourceUrl, coverage;
  final String? retrievedAt;
  final List<Shelter> shelters;
  List<Shelter> nearest(double lat, double lon) => [...shelters]
    ..sort(
      (a, b) => a.distanceFrom(lat, lon).compareTo(b.distanceFrom(lat, lon)),
    );
}
