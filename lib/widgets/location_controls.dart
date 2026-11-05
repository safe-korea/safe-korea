import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';

/// Separates the selected search area from the point used to calculate distance.
class LocationControls extends StatelessWidget {
  const LocationControls({
    super.key,
    required this.position,
    required this.busy,
    required this.onLocate,
    required this.onClear,
    this.message,
  });
  final Position? position;
  final bool busy;
  final VoidCallback onLocate, onClear;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final point = position;
    final time = point?.timestamp.toLocal();
    final status = point == null
        ? message ?? '현재 위치로 지역을 찾고 대피소를 조회해요.'
        : '현재 위치 확인 · 오차 약 ${point.accuracy.round()}m\n'
              '${time!.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} 확인 · 실시간 추적 아님';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: AppPalette.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '내 위치',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (point != null)
                  PopupMenuButton<String>(
                    tooltip: '내 위치 옵션',
                    enabled: !busy,
                    onSelected: (_) => onClear(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'clear', child: Text('내 위치 사용 해제')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(status, style: const TextStyle(fontSize: 14)),
            ),
            if (point != null &&
                message != null &&
                !message!.startsWith('현재 위치 확인')) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(message!, style: const TextStyle(fontSize: 14)),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onLocate,
              icon: Icon(point == null ? Icons.my_location : Icons.refresh),
              label: Text(
                busy
                    ? '위치 확인 중…'
                    : point == null
                    ? 'GPS 현재 위치 확인'
                    : '현재 위치 새로고침',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '좌표는 기기에서만 처리해요. 시설 조회에는 연결이 필요해요.',
              style: TextStyle(fontSize: 13, color: AppPalette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
