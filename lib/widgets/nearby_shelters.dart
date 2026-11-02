import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/shelter.dart';

/// An immediate, explicitly region-scoped result after one location action.
class NearbyShelters extends StatelessWidget {
  const NearbyShelters({
    super.key,
    required this.catalog,
    required this.position,
    required this.onSelect,
  });
  final ShelterCatalog catalog;
  final Position position;
  final ValueChanged<Shelter> onSelect;
  @override
  Widget build(BuildContext context) {
    final items = catalog
        .nearest(position.latitude, position.longitude)
        .take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          '${catalog.coverage} 내 가까운 대피소',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '직선거리순 · 인접 지역 제외 · 개방 여부는 현장 확인',
          style: TextStyle(fontSize: 13),
        ),
        if (catalog.deliveryStatus == 'stale')
          const Text(
            '원본 재조회 실패 · 이전 자료입니다.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        if (items.isEmpty) const Text('조회된 시설이 없어요. 다른 지역이나 정부 안내를 확인하세요.'),
        for (final shelter in items)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(
                shelter.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${shelter.address}\n직선거리 ${_distance(shelter)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelect(shelter),
            ),
          ),
      ],
    );
  }

  String _distance(Shelter shelter) {
    final meters = shelter.distanceFrom(position.latitude, position.longitude);
    return meters < 1000
        ? '${meters.round()}m'
        : '${(meters / 1000).toStringAsFixed(1)}km';
  }
}
