import 'dart:convert';

import 'package:flutter/services.dart';

import 'shelter.dart';

class OfflineArea {
  OfflineArea(this.map, this.catalog);
  final Map<String, dynamic> map;
  final ShelterCatalog catalog;
  static const west = 127.088, south = 37.505, east = 127.112, north = 37.522;
  static bool covers(Shelter s) =>
      s.longitude >= west &&
      s.longitude <= east &&
      s.latitude >= south &&
      s.latitude <= north;
  static Future<OfflineArea>? _cached;
  static Future<OfflineArea> load() => _cached ??= _read();
  static Future<OfflineArea> _read() async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/offline_maps/jamsil-map.json'),
    ) as Map<String, dynamic>;
    final catalog = ShelterCatalog.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/offline_maps/jamsil-shelters.json'),
      ) as Map<String, dynamic>,
    );
    if (raw['schemaVersion'] != 1 || catalog.shelters.any((s) => !covers(s))) {
      throw const FormatException('오프라인 지도 범위 불일치');
    }
    return OfflineArea(raw, catalog);
  }
}
