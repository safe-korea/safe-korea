import 'shelter.dart';

enum ShelterCheck { confirmed, changed, notFound, incomplete }

/// An explicit saved snapshot, including the source and original retrieval time.
class SavedShelter {
  SavedShelter._(
    this.snapshot,
    this.savedAt, {
    this.checkedAt,
    this.check,
    this.keyVersion = 2,
  });
  final int keyVersion;
  final DateTime? checkedAt;
  final ShelterCheck? check;
  SavedShelter withCheck(
    ShelterCatalog catalog,
    DateTime time,
    ShelterCheck result,
  ) => SavedShelter._(
    catalog,
    savedAt,
    checkedAt: time.toUtc(),
    check: result,
    keyVersion: keyVersion,
  );
  final ShelterCatalog snapshot;
  final DateTime savedAt;
  Shelter get shelter => snapshot.shelters.single;
  String get key => keyVersion == 1
      ? '${snapshot.sourceUrl}|${shelter.id}'
      : '${snapshot.sourceUrl}|${snapshot.areaCode ?? ''}|${shelter.id}';
  factory SavedShelter.fromCatalog(
    ShelterCatalog catalog,
    String id,
    DateTime savedAt,
  ) {
    if (catalog.retrievedAt == null) throw const FormatException('공식 조회 시각 누락');
    DateTime.parse(catalog.retrievedAt!);
    final json = catalog.toJson();
    final matches = (json['items'] as List)
        .where((item) => item['id'] == id)
        .toList();
    if (matches.length != 1) {
      throw const FormatException('공식 조회 목록에서 시설을 확인할 수 없습니다.');
    }
    json['items'] = matches;
    return SavedShelter._(ShelterCatalog.fromJson(json), savedAt.toUtc());
  }
  factory SavedShelter.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('지원하지 않는 저장 형식');
    }
    final keyVersion = json['keyVersion'] as int? ?? 1;
    if (keyVersion != 1 && keyVersion != 2) {
      throw const FormatException('지원하지 않는 저장 식별자');
    }
    final catalog = ShelterCatalog.fromJson(
      Map<String, dynamic>.from(json['catalog'] as Map),
    );
    if (catalog.shelters.length != 1 || catalog.retrievedAt == null) {
      throw const FormatException('저장 시설의 출처가 누락되었습니다.');
    }
    DateTime.parse(catalog.retrievedAt!);
    return SavedShelter._(
      catalog,
      DateTime.parse(json['savedAt'] as String).toUtc(),
      keyVersion: keyVersion,
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String).toUtc(),
      check: json['check'] == null
          ? null
          : ShelterCheck.values.byName(json['check'] as String),
    );
  }
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'keyVersion': keyVersion,
    'savedAt': savedAt.toIso8601String(),
    'catalog': snapshot.toJson(),
    'checkedAt': checkedAt?.toIso8601String(),
    'check': check?.name,
  };
}
