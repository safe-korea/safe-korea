import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual headings organize the bundled instructions without replacing them.
class GuidelineStep extends StatelessWidget {
  const GuidelineStep({
    super.key,
    required this.kind,
    required this.index,
    required this.text,
  });
  final String kind, text;
  final int index;

  static const _headings = <String, List<(String, IconData)>>{
    'air': [
      ('대피 장소', Icons.home_work_outlined),
      ('계단 이용', Icons.stairs_outlined),
      ('침수 주의', Icons.water_outlined),
      ('방송 확인', Icons.radio_outlined),
    ],
    'watch': [
      ('정부 안내', Icons.radio_outlined),
      ('야외활동 주의', Icons.warning_amber_rounded),
      ('함께 준비', Icons.groups_outlined),
      ('대피 지시', Icons.campaign_outlined),
    ],
    'cbrn': [
      ('공격 종류 확인', Icons.campaign_outlined),
      ('호흡기·피부 보호', Icons.masks_outlined),
    ],
    'chemical': [
      ('보호장비', Icons.masks_outlined),
      ('이동 장소 확인', Icons.apartment_outlined),
      ('외부 공기 차단', Icons.window_outlined),
      ('보호 한계 확인', Icons.warning_amber_rounded),
    ],
    'biological': [
      ('접촉 피하기', Icons.masks_outlined),
      ('불필요한 이동 줄이기', Icons.home_outlined),
      ('보건 안내', Icons.medical_services_outlined),
    ],
    'nuclear': [
      ('폭발 전', Icons.home_work_outlined),
      ('섬광·폭발을 인지했다면', Icons.shield_outlined),
      ('폭발 후', Icons.apartment_outlined),
    ],
    'release': [
      ('추가 안내 확인', Icons.radio_outlined),
      ('주변 사람 돕기', Icons.groups_outlined),
    ],
    'pet': [
      ('동반 가능 여부 확인', Icons.pets_outlined),
      ('갈 곳 정하기', Icons.map_outlined),
      ('이동장·재난 키트', Icons.backpack_outlined),
    ],
    'prepare': [
      ('대피 장소', Icons.map_outlined),
      ('생존배낭', Icons.backpack_outlined),
      ('가족 약속', Icons.groups_outlined),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final options = _headings[kind];
    final heading = options != null && index < options.length
        ? options[index]
        : ('확인할 내용', Icons.info_outline);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  heading.$1,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Icon(heading.$2, size: 28, color: AppPalette.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

/// Items whose own source is not yet checked against the original are shown
/// as drafts, never as authoritative guidance.
class GuidelineDraftNotice extends StatelessWidget {
  const GuidelineDraftNotice({super.key, required this.item, this.onOpen});
  final Map<String, dynamic> item;
  final ValueChanged<Uri>? onOpen;
  @override
  Widget build(BuildContext context) {
    final source = item['source'] as Map<String, dynamic>?;
    if (item['draft'] != true || source == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.cautionBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '초안 · ${source['status']}',
            style: const TextStyle(
              color: AppPalette.caution,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text('출처: ${source['name']}', style: const TextStyle(fontSize: 14)),
          if (onOpen != null)
            TextButton(
              onPressed: () => onOpen!(Uri.parse(source['url'] as String)),
              child: const Text('원문 열기'),
            ),
        ],
      ),
    );
  }
}
