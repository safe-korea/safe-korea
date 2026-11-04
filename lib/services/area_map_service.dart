import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/shelter.dart';
import 'local_region_service.dart';
import 'local_store.dart';
import 'location_service.dart';
import 'region_suggestion_service.dart';
import 'saved_map_downloader.dart';
import 'shelter_api_client.dart';
import 'shelter_repository.dart';

/// Published cells and their sizes, bundled so the size shown before saving
/// is accurate and empty sea/border cells are never requested.
Future<Map<String, int>> loadMapIndex() async =>
    ((jsonDecode(await rootBundle.loadString('assets/offline_map_index.json'))
                as Map)['cellsKb']
            as Map)
        .map((k, v) => MapEntry(k as String, v as int));

class AreaMapPlan {
  const AreaMapPlan(this.region, this.bounds, this.cells, this.totalKb);
  final RegionSuggestion region;
  final List<double> bounds;
  final List<(int, int)> cells;
  final int totalKb;
  int get cellCount => cells.length;
  String get sizeLabel {
    final mb = totalKb / 1024;
    return mb < 1 ? '1MB 미만' : '약 ${mb.ceil()}MB';
  }
}

/// A saved district map with its official shelter list.
class AreaMap {
  AreaMap(this.record);
  final Map<String, dynamic> record;
  String get regionName => (record['region'] as Map)['name'] as String;
  String get regionCode => (record['region'] as Map)['code'] as String;
  Map<String, dynamic> get map =>
      Map<String, dynamic>.from(record['map'] as Map);
  ShelterCatalog? get catalog => record['catalog'] == null
      ? null
      : ShelterCatalog.fromJson(
          Map<String, dynamic>.from(record['catalog'] as Map),
        );
  DateTime get savedAt => DateTime.parse(record['savedAt'] as String);
}

class AreaMapFailure implements Exception {
  const AreaMapFailure(this.message);
  final String message;
}

/// Near a district boundary: the user picks one of these instead of the app
/// guessing.
class AreaMapChoice implements Exception {
  const AreaMapChoice(this.plans);
  final List<AreaMapPlan> plans;
}

/// Saves the whole district around the current position. The position stays
/// on the device: only the district's public map cells and region code are
/// requested, so the server cannot tell where in the district the user is.
class AreaMapService {
  AreaMapService({
    LocationService? location,
    RegionSuggestionService? regions,
    LocalStore? store,
    ShelterRepository? repository,
    this.baseUrl = shelterApiBaseUrl,
    this.client,
  }) : _location = location ?? LocationService(),
       _regions = regions ?? LocalRegionService(),
       _store = store ?? LocalStore(),
       // ignore: prefer_initializing_formals
       _repository = repository;
  final LocationService _location;
  final RegionSuggestionService _regions;
  final LocalStore _store;
  final ShelterRepository? _repository;
  final String baseUrl;
  final http.Client? client;

  Future<AreaMapPlan> plan({Position? position}) async {
    final here = position ?? await _location.current();
    final provinces =
        ((jsonDecode(await rootBundle.loadString('assets/regions.json'))
                    as Map)['provinces']
                as List)
            .cast<Map<String, dynamic>>();
    final region = await _regions.suggest(here, provinces);
    if (region?.districtCode != null) return _planFor(region!);
    // Near a boundary: offer the nearby districts, never pick one silently.
    final labels = <String, RegionSuggestion>{
      for (final p in provinces)
        for (final d in p['districts'] as List)
          d['code'] as String: RegionSuggestion(
            p['code'] as String,
            d['code'] as String,
            '${p['name']} ${d['name']}',
          ),
    };
    final nearby = _regions is LocalRegionService
        ? await LocalRegionService.codesNear(here)
        : <String>{};
    final plans = <AreaMapPlan>[];
    for (final code in nearby.where(labels.containsKey).take(4)) {
      try {
        plans.add(await _planFor(labels[code]!));
      } on AreaMapFailure {
        // Skip districts without published map cells.
      }
    }
    if (plans.isNotEmpty) throw AreaMapChoice(plans);
    throw const AreaMapFailure(
      '현재 위치의 시·군·구를 확인하지 못했어요. 대피소 화면에서 지역을 선택해 대피소를 저장하세요.',
    );
  }

  Future<AreaMapPlan> _planFor(RegionSuggestion region) async {
    final bounds = await LocalRegionService.boundsOf(region.districtCode!);
    if (bounds == null) {
      throw const AreaMapFailure('이 지역의 지도 범위를 찾지 못했어요.');
    }
    final index = await loadMapIndex();
    final cells = [
      for (final cell in mapCellsFor(bounds))
        if (index.containsKey('${cell.$1}-${cell.$2}')) cell,
    ];
    if (cells.isEmpty) {
      throw const AreaMapFailure('이 지역에는 저장할 지도 자료가 없어요.');
    }
    final kb = cells.fold<int>(0, (sum, c) => sum + index['${c.$1}-${c.$2}']!);
    return AreaMapPlan(region, bounds, cells, kb);
  }

  Future<AreaMap> download(
    AreaMapPlan plan, {
    void Function(int done, int total)? progress,
  }) async {
    final features = await fetchMapFeatures(
      plan.bounds,
      baseUrl: baseUrl,
      client: client,
      cells: plan.cells,
      progress: progress,
    );
    ShelterCatalog? catalog;
    final repository = _repository ?? ShelterRepository();
    try {
      catalog = await repository.fetch(
        plan.region.districtCode!,
        plan.region.label,
      );
    } catch (_) {
      // The map is still useful offline; shelters can be added later.
      catalog = null;
    } finally {
      if (_repository == null) repository.close();
    }
    final record = {
      'schemaVersion': 1,
      'region': {'code': plan.region.districtCode, 'name': plan.region.label},
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'map': mapRecord(plan.bounds, features),
      if (catalog != null) 'catalog': catalog.toJson(),
    };
    await _store.saveAreaMap(record);
    return AreaMap(record);
  }

  Future<AreaMap?> load() async {
    final record = await _store.loadAreaMap();
    if (record == null || record['schemaVersion'] != 1) return null;
    return AreaMap(record);
  }

  Future<void> remove() => _store.removeAreaMap();
}
