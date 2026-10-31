import 'package:flutter/foundation.dart';

import '../models/saved_shelter.dart';
import '../models/shelter.dart';
import 'local_store.dart';

class SavedSheltersController extends ChangeNotifier {
  SavedSheltersController({LocalStore? store}) : _store = store ?? LocalStore();
  static final shared = SavedSheltersController();
  final LocalStore _store;
  Map<String, SavedShelter> _entries = {};
  bool loaded = false, loading = false, busy = false;
  String? error;
  Future<void>? _pending;
  List<SavedShelter> get entries => List.unmodifiable(
    _entries.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt)),
  );
  bool contains(ShelterCatalog catalog, String id) =>
      _entries.containsKey('${catalog.sourceUrl}|$id');
  Future<void> ensureLoaded() => loaded ? Future.value() : load();
  Future<void> load() =>
      _pending ??= _load().whenComplete(() => _pending = null);
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

  Future<bool> toggle(ShelterCatalog catalog, String id) async {
    if (!loaded || busy || loading) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final key = '${catalog.sourceUrl}|$id';
      if (_entries.containsKey(key)) {
        await _store.removeSavedShelter(key);
        _entries.remove(key);
      } else {
        final entry = SavedShelter.fromCatalog(catalog, id, DateTime.now());
        await _store.saveSavedShelter(entry.key, entry.toJson());
        _entries[entry.key] = entry;
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
