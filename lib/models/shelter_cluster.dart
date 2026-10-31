import 'dart:math';

import 'shelter.dart';

class ShelterCluster {
  ShelterCluster(List<Shelter> points, this.level)
    : members = List.unmodifiable(
        [...points]..sort((a, b) => a.id.compareTo(b.id)),
      );
  final List<Shelter> members;
  final int level;
  bool get isSingle => members.length == 1;
  String get id => '${isSingle ? 's' : 'c'}:$level:${members.first.id}';
  double get latitude =>
      members.fold(0.0, (sum, p) => sum + p.latitude) / members.length;
  double get longitude =>
      members.fold(0.0, (sum, p) => sum + p.longitude) / members.length;
}

/// Screen-pixel proximity, including neighbours across grid boundaries.
/// Clusters are a display aid only; their centres are not shelter locations.
List<ShelterCluster> clusterShelters(
  List<Shelter> shelters,
  double zoom, {
  double radius = 56,
}) {
  if (!zoom.isFinite || !radius.isFinite || radius <= 0) {
    throw ArgumentError('Invalid map scale');
  }
  if (shelters.isEmpty) return [];
  final level = zoom.floor().clamp(0, 21);
  final world = 256.0 * pow(2, level);
  final pixels = <Point<double>>[];
  final cells = <String, List<int>>{};
  final parents = List.generate(shelters.length, (i) => i);
  int root(int i) {
    while (parents[i] != i) {
      parents[i] = parents[parents[i]];
      i = parents[i];
    }
    return i;
  }

  for (final (index, shelter) in shelters.indexed) {
    final sinLat = sin(shelter.latitude * pi / 180).clamp(-0.9999, 0.9999);
    final p = Point(
      (shelter.longitude + 180) / 360 * world,
      (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * world,
    );
    pixels.add(p);
    final x = (p.x / radius).floor(), y = (p.y / radius).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final previous in cells['${x + dx}:${y + dy}'] ?? <int>[]) {
          final delta = p - pixels[previous];
          if (delta.x * delta.x + delta.y * delta.y <= radius * radius) {
            parents[root(index)] = root(previous);
          }
        }
      }
    }
    (cells['$x:$y'] ??= []).add(index);
  }
  final groups = <int, List<Shelter>>{};
  for (var i = 0; i < shelters.length; i++) {
    (groups[root(i)] ??= []).add(shelters[i]);
  }
  return groups.values.map((items) => ShelterCluster(items, level)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}
