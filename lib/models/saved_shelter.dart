import 'shelter.dart';

enum ShelterRole { none, primary, alternate }

extension ShelterRoleLabel on ShelterRole {
  String get label => switch (this) {
    ShelterRole.none => '일반 저장',
    ShelterRole.primary => '주 대피소',
    ShelterRole.alternate => '대체 대피소',
  };
}

class ShelterPhoto {
  const ShelterPhoto({
    required this.data,
    required this.addedAt,
    this.mapSource,
  });

  /// User supplied reference image, never an automatically captured SDK map.
  final String? mapSource;
  bool get isReferenceMap => mapSource != null;
  final String data;
  final DateTime addedAt;
  Map<String, dynamic> toJson() => {
    'data': data,
    'addedAt': addedAt.toIso8601String(),
    if (mapSource != null) 'mapSource': mapSource,
  };
  factory ShelterPhoto.fromJson(Map<String, dynamic> json) => ShelterPhoto(
    data: json['data'] as String,
    addedAt: DateTime.parse(json['addedAt'] as String),
    mapSource: json['mapSource'] as String?,
  );
}

enum ShelterCheck { confirmed, changed, notFound, incomplete }

/// An explicit saved snapshot, including the source and original retrieval time.
class SavedShelter {
  SavedShelter._(
    this.snapshot,
    this.savedAt, {
    this.checkedAt,
    this.check,
    this.keyVersion = 2,
    this.role = ShelterRole.none,
    this.entranceNote = '',
    this.photos = const [],
    this.offlineMap,
  });
  final Map<String, dynamic>? offlineMap;
  SavedShelter withOfflineMap(Map<String, dynamic> map) => SavedShelter._(
    snapshot,
    savedAt,
    checkedAt: checkedAt,
    check: check,
    keyVersion: keyVersion,
    role: role,
    entranceNote: entranceNote,
    photos: photos,
    offlineMap: map,
  );
  final ShelterRole role;
  final String entranceNote;
  final List<ShelterPhoto> photos;
  SavedShelter withPersonal({
    required ShelterRole role,
    required String note,
    required List<ShelterPhoto> photos,
  }) => SavedShelter._(
    snapshot,
    savedAt,
    checkedAt: checkedAt,
    check: check,
    keyVersion: keyVersion,
    role: role,
    entranceNote: note,
    photos: List.unmodifiable(photos),
    offlineMap: offlineMap,
  );
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
    role: role,
    entranceNote: entranceNote,
    photos: photos,
    offlineMap:
        shelter.latitude == catalog.shelters.single.latitude &&
            shelter.longitude == catalog.shelters.single.longitude
        ? offlineMap
        : null,
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
      offlineMap: json['offlineMap'] == null
          ? null
          : Map<String, dynamic>.from(json['offlineMap'] as Map),
      keyVersion: keyVersion,
      role: ShelterRole.values.byName(json['role'] as String? ?? 'none'),
      entranceNote: json['entranceNote'] as String? ?? '',
      photos: List.unmodifiable(
        (json['photos'] as List? ?? []).map(
          (p) => ShelterPhoto.fromJson(Map<String, dynamic>.from(p as Map)),
        ),
      ),
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String).toUtc(),
      check: json['check'] == null
          ? null
          : ShelterCheck.values.byName(json['check'] as String),
    );
  }
  Map<String, dynamic> toJson() => {
    if (offlineMap != null) 'offlineMap': offlineMap,
    'schemaVersion': 1,
    'keyVersion': keyVersion,
    'savedAt': savedAt.toIso8601String(),
    'catalog': snapshot.toJson(),
    'checkedAt': checkedAt?.toIso8601String(),
    'check': check?.name,
    'role': role.name,
    'entranceNote': entranceNote,
    'photos': photos.map((p) => p.toJson()).toList(),
  };
}
