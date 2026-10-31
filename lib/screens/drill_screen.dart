import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'guidelines_screen.dart';
import 'shelters_screen.dart';

class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key});
  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  final _checked = <int>{};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('훈련 / 테스트'),
      backgroundColor: const Color(0xFFFFE9DB),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          child: const Text('훈련 종료 · 홈으로'),
        ),
      ),
    ),
    body: PageBody(
      children: [
        const Notice(
          '훈련 / 테스트\n실제 공습경보가 아닙니다. 알림이나 사이렌을 발송하지 않습니다.',
          urgent: true,
        ),
        const Icon(Icons.shield_outlined, size: 64, color: ink),
        const SizedBox(height: 16),
        const Text(
          '공습 대피 행동을\n차근차근 연습하세요',
          style: TextStyle(
            fontSize: 30,
            height: 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '1. 가까운 대피 장소 확인',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const Text('민방위 대피소·지하시설 또는 콘크리트 건물의 유리창 없는 공간을 확인하세요.'),
        const SizedBox(height: 20),
        const Text(
          '2. 계단으로 이동',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const Text('고층 건물에서는 계단을 이용하세요. 침수 위험이 있는 지하시설은 피하세요.'),
        const SizedBox(height: 20),
        const Text(
          '3. 정부 안내 계속 확인',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const Text('실제 상황에서는 재난문자·TV·라디오와 현장 안내를 따르세요.'),
        const SizedBox(height: 24),
        const Notice('화학 공격은 대피 방법이 다릅니다. 상황별 행동강령을 확인하세요.'),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SheltersScreen()),
          ),
          icon: const Icon(Icons.near_me),
          label: const Text('대피시설 확인'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const GuidelinesScreen()),
          ),
          child: const Text('상황별 행동강령 보기'),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 16),
        const Text(
          '연습 체크 · 선택 사항',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
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
              if (value!) {
                _checked.add(index);
              } else {
                _checked.remove(index);
              }
            }),
          ),
        if (_checked.length == 3)
          const Notice('대피 행동 연습을 마쳤어요. 실제 상황에서는 최신 정부·현장 안내에 따라 행동하세요.'),
        const SizedBox(height: 12),
        const Text('출처: 행정안전부 국민안전24\n비상시 행동요령 · 원문 확인 2026-10-31'),
      ],
    ),
  );
}
