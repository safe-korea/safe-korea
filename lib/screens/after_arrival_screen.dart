import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../widgets/common.dart';
import 'status_share_screen.dart';

/// Air-raid follow-up only; not a location or safety verification.
class AfterArrivalScreen extends StatelessWidget {
  const AfterArrivalScreen({super.key, this.training = false});
  final bool training;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('공습 대피 후 할 일')),
    body: PageBody(
      children: [
        if (training) const Notice('훈련 / 테스트 · 실제 경보가 아닙니다'),
        const IconTextBlock(
          icon: Icons.radio_outlined,
          title: '정부 안내를 계속 확인',
          body: Text('재난문자·TV·라디오와 현장 안내를 확인하세요.'),
        ),
        const SizedBox(height: 20),
        const IconTextBlock(
          icon: Icons.hearing_outlined,
          title: '해제·이동 지시 확인',
          body: Text('도착했다고 안전이 확인된 것은 아니에요. 정부의 경보해제와 지역별 이동 지시를 확인하세요.'),
        ),
        const SizedBox(height: 20),
        const IconTextBlock(
          icon: Icons.people_outline,
          title: '주변 사람 살피기',
          body: Text('현장 안내를 따르며 도움이 필요한 사람을 살피세요.'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => StatusShareScreen(training: training),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('가족에게 내 상태 알리기'),
        ),
        const SizedBox(height: 16),
        const Text(
          '공습·경보해제 행동요령 요약 · 확인 2026-11-01\n화학·생물학 공격은 별도 행동요령을 따르세요.',
          style: TextStyle(fontSize: 14),
        ),
        TextButton(
          onPressed: () => openExternal(context, Uri.parse(guidanceSource)),
          child: const Text('행정안전부 원문 보기'),
        ),
      ],
    ),
  );
}
