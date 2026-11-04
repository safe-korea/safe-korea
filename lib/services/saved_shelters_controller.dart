import 'package:flutter/foundation.dart';

import '../models/saved_shelter.dart';
import '../models/shelter.dart';
import 'local_store.dart';
import 'saved_map_downloader.dart';
import 'shelter_repository.dart';

class SavedSheltersController extends ChangeNotifier {
  SavedSheltersController({LocalStore? store, SavedMapDownloader? maps})
    : _store = store ?? LocalStore(),
      _maps = maps ?? SavedMapDownloader();
  final SavedMapDownloader _maps;
  static final shared = SavedSheltersController();
  final LocalStore _store;
  Map<String, SavedShelter> _entries = {};
  bool loaded = false, loading = false, busy = false;
  String? error;
  String? mapMessage;
  Future<void> _downloadMap(SavedShelter entry) async {
    mapMessage = null;
    try {
      final map = await _maps.fetch(entry.shelter);
      final next = entry.withOfflineMap(map);
      await _store.saveSavedShelter(next.key, next.toJson());
      _entries[next.key] = next;
      mapMessage = '대피소와 주변 지도를 저장했습니다.';
    } catch (_) {
      mapMessage = '대피소는 저장했지만 지도는 저장하지 못했어요. 인터넷 연결 후 다시 저장해 주세요.';
    }
  }

  Future<void> retryMap(SavedShelter entry) async {
    if (busy || !loaded) return;
    busy = true;
    notifyListeners();
    try {
      await _downloadMap(_entries[entry.key]!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void>? _pending;
  List<SavedShelter> get entries => List.unmodifiable(
    _entries.values.toList()..sort((a, b) {
      int rank(ShelterRole r) => r == ShelterRole.none ? 2 : r.index - 1;
      final roleOrder = rank(a.role).compareTo(rank(b.role));
      return roleOrder != 0 ? roleOrder : b.savedAt.compareTo(a.savedAt);
    }),
  );
  SavedShelter? _find(ShelterCatalog catalog, String id) {
    for (final entry in _entries.values) {
      if (entry.snapshot.sourceUrl == catalog.sourceUrl &&
          entry.snapshot.areaCode == catalog.areaCode &&
          entry.shelter.id == id) {
        return entry;
      }
    }
    return null;
  }

  SavedShelter? entryFor(ShelterCatalog catalog, String id) =>
      _find(catalog, id);

  bool contains(ShelterCatalog catalog, String id) =>
      _find(catalog, id) != null;
  Future<void> ensureLoaded() => loaded ? Future.value() : load();
  Future<void> load() => busy
      ? Future.value()
      : _pending ??= _load().whenComplete(() => _pending = null);
  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final records = await _store.loadSavedShelters();
      final next = <String, SavedShelter>{};
      for (final raw in records) {
        final entry = SavedShelter.fromJson(raw);
        if (next.containsKey(entry.key)) {
          throw const FormatException('중복 저장 시설');
        }
        next[entry.key] = entry;
      }
      _entries = next;
      loaded = true;
    } catch (_) {
      error = '저장한 대피소를 읽지 못했습니다. 기존 자료를 보호하기 위해 저장 변경을 멈췄습니다.';
      loaded = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> refresh(
    SavedShelter entry,
    ShelterRepository repository,
  ) async {
    if (!loaded || loading || busy || !_entries.containsKey(entry.key)) {
      return '저장 목록을 읽거나 변경 중입니다. 잠시 후 다시 시도해 주세요.';
    }
    final code = entry.snapshot.areaCode;
    if (code == null) return '조회 지역 코드가 없어 다시 확인할 수 없습니다. 공식 출처에서 확인하세요.';
    busy = true;
    error = null;
    notifyListeners();
    try {
      final latest = await repository.fetch(code, entry.snapshot.coverage);
      if (latest.areaCode != code ||
          latest.sourceUrl != entry.snapshot.sourceUrl ||
          latest.retrievedAt == null) {
        throw const FormatException('조회 지역 또는 출처 불일치');
      }
      final checkedAt = DateTime.parse(latest.retrievedAt!);
      final matches = latest.shelters
          .where((s) => s.id == entry.shelter.id)
          .toList();
      late SavedShelter next;
      late String message;
      if (matches.isEmpty) {
        final incomplete = latest.skippedCount > 0;
        next = entry.withCheck(
          entry.snapshot,
          checkedAt,
          incomplete ? ShelterCheck.incomplete : ShelterCheck.notFound,
        );
        message = incomplete
            ? '일부 시설 자료를 해석하지 못해 등재 여부를 확인할 수 없습니다. 기존 정보를 유지합니다.'
            : '이번 지역 조회에서 같은 시설을 찾지 못했습니다. 폐쇄를 뜻하지 않으며 기존 정보를 유지합니다.';
      } else {
        final before = entry.shelter, after = matches.single;
        final changed =
            before.name != after.name ||
            before.address != after.address ||
            before.latitude != after.latitude ||
            before.longitude != after.longitude ||
            before.updatedAt != after.updatedAt;
        final refreshed = SavedShelter.fromCatalog(
          latest,
          after.id,
          entry.savedAt,
        );
        next = entry.withCheck(
          refreshed.snapshot,
          checkedAt,
          changed ? ShelterCheck.changed : ShelterCheck.confirmed,
        );
        message = changed
            ? '공식 조회에서 변경된 시설 정보를 반영했습니다. 현재 개방 여부는 별도 확인이 필요합니다.'
            : '공식 목록에서 같은 시설을 다시 확인했습니다. 현재 개방 여부는 별도 확인이 필요합니다.';
      }
      await _store.saveSavedShelter(next.key, next.toJson());
      _entries[next.key] = next;
      return message;
    } catch (_) {
      error = '공식 자료 재확인 또는 저장에 실패했습니다. 기존 정보를 유지합니다.';
      return error!;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> savePersonal(
    String key,
    ShelterRole role,
    String note,
    List<ShelterPhoto> photos, {
    PetCheck? pet,
  }) async {
    if (!loaded || busy || loading || !_entries.containsKey(key)) return false;
    if (note.length > 300 || photos.length > 3) return false;
    if (pet != null && !pet.valid) return false;
    if (photos.any(
      (p) =>
          p.isReferenceMap &&
          (p.mapSource!.trim().isEmpty || p.mapSource!.length > 120),
    )) {
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final entry = _entries[key]!;
      final changes = <SavedShelter>[
        for (final other in _entries.values)
          if (role != ShelterRole.none &&
              other.role == role &&
              other.key != key)
            other.withPersonal(
              role: ShelterRole.none,
              note: other.entranceNote,
              photos: other.photos,
            ),
        entry.withPersonal(
          role: role,
          note: note.trim(),
          photos: photos,
          pet: pet,
        ),
      ];
      await _store.saveSavedShelters([
        for (final value in changes)
          {...value.toJson(), 'storageKey': value.key},
      ]);
      for (final value in changes) {
        _entries[value.key] = value;
      }
      return true;
    } catch (_) {
      error = '개인 기록을 저장하지 못했습니다. 기존 기록은 유지됩니다.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> toggle(ShelterCatalog catalog, String id) async {
    if (!loaded || busy || loading) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final existing = _find(catalog, id);
      if (existing != null) {
        await _store.removeSavedShelter(existing.key);
        _entries.remove(existing.key);
      } else {
        final entry = SavedShelter.fromCatalog(catalog, id, DateTime.now());
        await _store.saveSavedShelter(entry.key, entry.toJson());
        _entries[entry.key] = entry;
        await _downloadMap(entry);
      }
      return true;
    } catch (_) {
      error = '대피소 저장을 변경하지 못했습니다. 기존 저장 목록은 유지합니다.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
