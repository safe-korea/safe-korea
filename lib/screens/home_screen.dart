import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/received_alert_banner.dart';
import 'alert_guide_screen.dart';
import 'system_civil_alert_settings_screen.dart';
import 'offline_hub_screen.dart';
import 'drill_screen.dart';
import 'notification_test_screen.dart';
import 'guidelines_screen.dart';
import 'family_screen.dart';
import 'shelters_screen.dart';
import 'readiness_screen.dart';
import 'saved_shelters_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onShelters,
    this.onGuidelines,
    this.onReadiness,
  });
  final VoidCallback? onShelters, onGuidelines, onReadiness;
  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Widget _shortcut({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(title),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/branding/app-icon.png',
                width: 36,
                height: 36,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'SAFE KOREA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
    body: PageBody(
      children: [
        const ReceivedAlertBanner(),
        const Text(
          '지금 필요한 안내',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          '경보를 들었다면, 지금 할 행동부터',
          style: TextStyle(fontSize: 13, color: AppPalette.muted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.alert,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onPressed: () => _open(
            context,
            const AlertGuideScreen(requireKindSelection: true),
          ),
          icon: const Icon(Icons.touch_app_outlined),
          label: const Text('지금 할 행동 보기'),
        ),
        const SizedBox(height: 8),
        const Text(
          '경보 종류와 실내·실외·차량을 직접 선택하세요.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 20),
        const Text(
          '미리 저장한 준비',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _shortcut(
          icon: Icons.bookmark_outline,
          title: '저장한 대피소',
          onTap: () => _open(context, const SavedSheltersScreen()),
        ),
        _shortcut(
          icon: Icons.people_outline,
          title: '가족 만남 장소',
          onTap: () => _open(context, const FamilyScreen()),
        ),
        _shortcut(
          icon: Icons.backpack_outlined,
          title: '비상배낭 체크리스트',
          onTap: onReadiness ?? () => _open(context, const ReadinessScreen()),
        ),
        const Text(
          '이 기기에 저장한 내용 · 인터넷 없이 확인',
          style: TextStyle(fontSize: 13, color: AppPalette.muted),
        ),
        const SizedBox(height: 20),
        ActionTile(
          icon: Icons.near_me_outlined,
          title: '주변 대피시설',
          subtitle: '새 시설 조회·지도 · 인터넷 필요',
          onTap: onShelters ?? () => _open(context, const SheltersScreen()),
        ),
        const SizedBox(height: 20),
        const Text(
          '평소에 익혀 두세요',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _open(context, const DrillScreen()),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('모의 공습경보 시작'),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.menu_book_outlined,
          title: '상황별 행동강령',
          subtitle: '전체 안내 · 인터넷 없이 확인',
          onTap: onGuidelines ?? () => _open(context, const GuidelinesScreen()),
        ),
        ActionTile(
          icon: Icons.wifi_off,
          title: '오프라인 기능 모아보기',
          subtitle: '통신이 끊겨도 쓸 수 있는 기능',
          onTap: () => _open(context, const OfflineHubScreen()),
        ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ActionTile(
            icon: Icons.notifications_active_outlined,
            title: '휴대전화 경보 연결',
            subtitle: '시스템 민방공 알림 · 직접 동의 필요',
            onTap: () => _open(context, const SystemCivilAlertSettingsScreen()),
          ),
        if (!kIsWeb)
          ActionTile(
            icon: Icons.notifications_outlined,
            title: '테스트 알림 설정',
            subtitle: '훈련용 사이렌 · 진동 · 권한',
            onTap: () => _open(context, const NotificationTestScreen()),
          ),
        const SizedBox(height: 16),
        const Text(
          '실제 상황에서는 재난문자·정부 방송과 현장 안내를 우선하세요.',
          style: TextStyle(fontSize: 14, color: AppPalette.muted),
        ),
      ],
    ),
  );
}
