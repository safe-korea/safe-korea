import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'guidelines_screen.dart';
import 'readiness_screen.dart';
import 'saved_shelters_screen.dart';
import 'shelters_screen.dart';

class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key});
  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  final _checked = <int>{};
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('훈련 / 테스트')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('훈련 종료 · 홈으로'),
        ),
      ),
    ),
    body: PageBody(
      children: [
        const Text(
          '실제 공습경보가 아닙니다 · 공습 대피 연습',
          style: TextStyle(
            color: AppPalette.caution,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.ink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '01  먼저 대피',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: const Text(
                  '가까운 대피 장소로\n이동하세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '민방위 대피소·지하시설로 이동하세요.\n고층 건물에서는 엘리베이터 대신 계단을 이용하세요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppPalette.ink,
                ),
                onPressed: () => _open(const SheltersScreen()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('대피시설 확인'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  '02  챙길 것은 준비된 배낭',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '물품을 찾느라 대피를 늦추지 마세요.',
                style: TextStyle(
                  color: AppPalette.caution,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _KitLine(Icons.water_drop_outlined, '물 · 간편식 · 상비약'),
              const SizedBox(height: 8),
              const _KitLine(Icons.flashlight_on_outlined, '손전등 · 라디오 · 건전지'),
              const SizedBox(height: 8),
              const Text(
                '평소에 미리 넣어 둡니다. 지금 모두 챙길 필요는 없습니다.',
                style: TextStyle(fontSize: 14, color: AppPalette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Notice(
          '화학 공격은 대피 방법이 다릅니다.\n침수 우려가 있는 지하시설은 피하고, 최신 정부·현장 안내를 따르세요.',
        ),
        OutlinedButton.icon(
          onPressed: () => _open(const SavedSheltersScreen()),
          icon: const Icon(Icons.bookmark_outline),
          label: const Text('저장한 대피소 보기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _open(const GuidelinesScreen()),
          child: const Text('상황별 행동강령 보기'),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: const Text(
            '대피한 뒤에는',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '재난문자·TV·라디오로 정부 안내를 계속 확인하세요. 통신이 되지 않아도 이 행동 안내는 읽을 수 있습니다.',
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('대피 장소와 이동 방법 자세히'),
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '가까운 지하시설이나 콘크리트 건물 안 유리창 없는 공간으로 대피하세요. 고층 건물에서는 계단으로 아래층이나 지하로 이동하세요. 대피소가 가깝다는 것만으로 현재 개방 여부나 이동 경로의 안전을 보장하지 않습니다.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('연습 체크 · 선택 사항'),
          subtitle: const Text('체크하지 않아도 모든 기능을 사용할 수 있어요'),
          children: [
            for (final (index, label) in [
              '대피 장소와 출입구를 확인했어요',
              '계단 이동 방법을 살펴봤어요',
              '정부 안내를 확인하는 방법을 익혔어요',
            ].indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label),
                value: _checked.contains(index),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _checked.add(index);
                  } else {
                    _checked.remove(index);
                  }
                }),
              ),
            if (_checked.length == 3)
              const Notice('대피 행동 연습을 마쳤어요. 실제 상황에서는 최신 정부·현장 안내에 따라 행동하세요.'),
          ],
        ),
        TextButton.icon(
          onPressed: () => _open(const ReadinessScreen()),
          icon: const Icon(Icons.backpack_outlined),
          label: const Text('평소에 비상배낭 준비하기'),
        ),
        const SizedBox(height: 16),
        const Text(
          '출처: 행정안전부 비상시 국민행동요령\n준비물·공습 대피 안내 확인 2026-11-01\n대피 우선 문구와 화면 순서는 앱의 편집 안내입니다.',
          style: TextStyle(fontSize: 14, color: AppPalette.muted),
        ),
      ],
    ),
  );
}

class _KitLine extends StatelessWidget {
  const _KitLine(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: Icon(icon, size: 24, color: AppPalette.green)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
