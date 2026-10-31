import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'drill_screen.dart';
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
        Text(
          '대피소를 미리\n확인해 두세요',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('가까운 대피소와 가족의 만남 장소를 평소에 정해 두세요.'),
        const SizedBox(height: 12),
        const Text(
          '비공식 대비 앱 · 실제 정부 경보 수신 기능 없음',
          style: TextStyle(fontSize: 14, color: AppPalette.muted),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: teal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.home_work_outlined, color: Colors.white, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '공식 대피소 찾기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '원하는 지역을 고르면 민방위 대피소를 지도와 목록에서 확인할 수 있어요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: teal,
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
        OutlinedButton.icon(
          onPressed: () => _open(context, const SavedSheltersScreen()),
          icon: const Icon(Icons.bookmark_outline),
          label: const Text('저장한 대피소'),
        ),
        const SizedBox(height: 24),
        Text('평소에 준비할 일', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Material(
          color: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _row(
                Icons.menu_book_outlined,
                '상황별 행동강령',
                '인터넷 없이 읽는 대피 행동',
                onGuidelines ?? () => _open(context, const GuidelinesScreen()),
              ),
              const Divider(height: 1, indent: 60),
              _row(
                Icons.people_outline,
                '가족 안전 계획',
                '비상연락처와 만남 장소',
                () => _open(context, const FamilyScreen()),
              ),
              const Divider(height: 1, indent: 60),
              _row(
                Icons.checklist,
                '비상배낭 체크리스트',
                '필요한 준비물을 하나씩 확인',
                onReadiness ?? () => _open(context, const ReadinessScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.caution.withValues(alpha: 0.05),
            border: Border.all(
              color: AppPalette.caution.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '미리 해보는 대피 연습',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.caution,
                ),
              ),
              const SizedBox(height: 8),
              const Text('실제 경보가 아닌 훈련입니다. 소리 없이 대피 행동을 익혀 보세요.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _open(context, const DrillScreen()),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('모의 공습경보 시작'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '실제 상황에서는 재난문자·정부 방송과 현장 안내를 우선하세요.',
          style: TextStyle(color: AppPalette.muted, fontSize: 14),
        ),
      ],
    ),
  );
  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    leading: Icon(icon, color: teal, size: 28),
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 14, color: AppPalette.muted),
    ),
    trailing: const Icon(Icons.chevron_right, color: AppPalette.muted),
    onTap: onTap,
  );
}
