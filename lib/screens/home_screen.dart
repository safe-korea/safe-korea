import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'SAFE KOREA',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    ),
    body: PageBody(
      children: [
        const Text(
          '미리 준비하고,\n바로 대피하세요',
          style: TextStyle(
            fontSize: 30,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '비공식 대비 앱 · 실제 정부 경보 수신 기능 없음',
          style: TextStyle(fontSize: 13, color: AppPalette.muted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.ink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '어디로 대피할까요?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '공식 대피소를 지도와 목록으로 확인하세요.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppPalette.ink,
                ),
                onPressed:
                    onShelters ?? () => _open(context, const SheltersScreen()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('주변 대피시설'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.alertBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.alert.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.alert,
                ),
                onPressed: () => _open(context, const DrillScreen()),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('모의 공습경보 시작'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '나의 비상 준비',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ActionTile(
          icon: Icons.bookmark_outline,
          title: '저장한 대피소',
          subtitle: '미리 저장한 시설 확인',
          onTap: () => _open(context, const SavedSheltersScreen()),
        ),
        ActionTile(
          icon: Icons.people_outline,
          title: '가족 만남 장소',
          subtitle: '만남 장소 · 지도 핀',
          onTap: () => _open(context, const FamilyScreen()),
        ),
        ActionTile(
          icon: Icons.menu_book_outlined,
          title: '상황별 행동강령',
          subtitle: '인터넷 없이 확인',
          onTap: onGuidelines ?? () => _open(context, const GuidelinesScreen()),
        ),
        ActionTile(
          icon: Icons.backpack_outlined,
          title: '비상배낭 체크리스트',
          subtitle: '평소에 하나씩 준비',
          onTap: onReadiness ?? () => _open(context, const ReadinessScreen()),
        ),
        ActionTile(
          icon: Icons.notifications_outlined,
          title: '테스트 알림 설정',
          subtitle: '사이렌 · 진동 · 권한',
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
