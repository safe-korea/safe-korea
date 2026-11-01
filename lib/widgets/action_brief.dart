import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../theme/app_theme.dart';

/// Short presentation of existing guidance. Conditions remain visible, never
/// hidden behind an icon, truncation or a disclosure control.
class ActionBrief {
  const ActionBrief(this.icon, this.title, this.detail);
  final IconData icon;
  final String title, detail;
}

List<ActionBrief> actionBriefs(
  AlertKind kind,
  UserSetting setting,
) => switch (kind) {
  AlertKind.air => [
    switch (setting) {
      UserSetting.indoors => const ActionBrief(
        Icons.stairs_outlined,
        '계단으로 이동',
        '지하나 아래층으로 대피하세요.',
      ),
      UserSetting.outdoors => const ActionBrief(
        Icons.apartment_outlined,
        '가까운 건물로 대피',
        '지하시설 또는 콘크리트 건물 안으로.',
      ),
      UserSetting.vehicle => const ActionBrief(
        Icons.directions_car_outlined,
        '운전 중이면 정차 후 대피',
        '공터나 도로 오른쪽에 차를 세우세요.',
      ),
      UserSetting.unknown => const ActionBrief(
        Icons.home_work_outlined,
        '가까운 대피소로 이동',
        '민방위 대피소나 지하시설로 즉시 대피.',
      ),
    },
    const ActionBrief(
      Icons.window_outlined,
      '유리창에서 떨어지세요',
      '침수 우려가 있는 지하는 피하세요.',
    ),
    const ActionBrief(
      Icons.radio_outlined,
      '대피 후 방송 확인',
      '정부 방송·재난문자를 계속 확인하세요.',
    ),
  ],
  AlertKind.watch => [
    const ActionBrief(Icons.radio_outlined, '발령 이유 확인', '정부 방송·재난문자를 확인하세요.'),
    ActionBrief(
      Icons.backpack_outlined,
      '대피 준비',
      setting == UserSetting.indoors
          ? '준비된 배낭·보호장비를 챙기세요.'
          : '주변 대피 장소를 확인하세요.',
    ),
    const ActionBrief(
      Icons.groups_outlined,
      '함께 이동 준비',
      '어린이·노약자를 돕고 정부 지시를 따르세요.',
    ),
  ],
  AlertKind.cbrn => [
    const ActionBrief(
      Icons.campaign_outlined,
      '공격 종류 확인',
      '방송·문자에서 화학·생물학 등을 확인하세요.',
    ),
    const ActionBrief(Icons.masks_outlined, '호흡기·피부 보호', '오염지역에 접근하지 마세요.'),
    const ActionBrief(Icons.alt_route, '종류별 대피 안내 확인', '공격 종류에 따라 대피 장소가 달라요.'),
  ],
  AlertKind.chemical => [
    setting == UserSetting.indoors
        ? const ActionBrief(
            Icons.sensor_door_outlined,
            '문·창문 닫기',
            '외부 공기 유입을 차단하세요.',
          )
        : const ActionBrief(
            Icons.apartment_outlined,
            '높은 층 실내로 대피',
            '외부 공기를 차단할 수 있는 곳으로.',
          ),
    const ActionBrief(Icons.masks_outlined, '호흡기·피부 보호', '방독면 등 보호장비를 사용하세요.'),
    const ActionBrief(
      Icons.warning_amber_rounded,
      '무조건 지하로 가지 마세요',
      '정부의 오염지역·이동 안내를 따르세요.',
    ),
  ],
  AlertKind.biological => [
    const ActionBrief(Icons.masks_outlined, '코·입 보호', '오염물질과 접촉하지 마세요.'),
    ActionBrief(
      Icons.home_outlined,
      '지정 장소 안내 확인',
      setting == UserSetting.indoors
          ? '실내에서 정부의 이동 안내를 확인하세요.'
          : '정부가 안내한 장소로 대피하거나 귀가하세요.',
    ),
    const ActionBrief(
      Icons.health_and_safety_outlined,
      '보건 안내 따르기',
      '검사·치료 안내를 확인하세요.',
    ),
  ],
  AlertKind.nuclear => [
    const ActionBrief(
      Icons.shield_outlined,
      '섬광·폭발을 봤다면 엎드리기',
      '이동보다 즉시 몸 보호가 먼저입니다.',
    ),
    const ActionBrief(
      Icons.home_work_outlined,
      '폭발 전 경보라면 대피',
      '가까운 지하시설로 즉시 이동하세요.',
    ),
    const ActionBrief(
      Icons.apartment_outlined,
      '폭발 후에는 낙진 피하기',
      '콘크리트 건물 안·깊은 지하에서 방송 확인.',
    ),
  ],
  AlertKind.release => [
    const ActionBrief(
      Icons.campaign_outlined,
      '해제·이동 지시 확인',
      '정부의 지역별 안내를 확인하세요.',
    ),
    const ActionBrief(Icons.radio_outlined, '방송 계속 듣기', '추가 공격 가능성에 대비하세요.'),
    const ActionBrief(
      Icons.groups_outlined,
      '현장 안내에 따라 이동',
      '도움이 필요한 사람을 살피세요.',
    ),
  ],
};

class ActionBriefTile extends StatelessWidget {
  const ActionBriefTile({super.key, required this.brief, this.primary = false});
  final ActionBrief brief;
  final bool primary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary ? AppPalette.alert : AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              brief.icon,
              size: 28,
              color: primary ? Colors.white : AppPalette.ink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                brief.title,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                brief.detail,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppPalette.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
