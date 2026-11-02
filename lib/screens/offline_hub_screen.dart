import 'package:flutter/material.dart';

import '../services/connection_monitor.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'alert_guide_screen.dart';
import 'saved_shelters_screen.dart';
import 'family_screen.dart';
import 'readiness_screen.dart';

class OfflineHubScreen extends StatelessWidget {
  const OfflineHubScreen({super.key, this.monitor});
  final ConnectionMonitor? monitor;
  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final connection = monitor ?? ConnectionMonitor.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('오프라인 기능')),
      body: ValueListenableBuilder<LinkStatus>(
        valueListenable: connection,
        builder: (context, status, _) => PageBody(
          children: [
            Text(
              switch (status) {
                LinkStatus.offline => '네트워크 연결이 없어요',
                LinkStatus.limited => '데이터 서버에 연결하지 못했어요',
                _ => '통신이 끊겨도 바로 확인하세요',
              },
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('행동요령과 이 기기에 저장한 내용을 사용할 수 있어요.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.alert),
              onPressed: () => _open(
                context,
                const AlertGuideScreen(requireKindSelection: true),
              ),
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('지금 할 행동 보기'),
            ),
            const SizedBox(height: 8),
            ActionTile(
              icon: Icons.bookmark_outline,
              title: '저장한 대피소',
              subtitle: '주소 · 저장한 약도·사진 · 출입구 메모',
              onTap: () => _open(context, const SavedSheltersScreen()),
            ),
            ActionTile(
              icon: Icons.people_outline,
              title: '가족 만남 장소',
              subtitle: '저장한 장소와 약속 · 전송은 연결 후',
              onTap: () => _open(context, const FamilyScreen()),
            ),
            ActionTile(
              icon: Icons.backpack_outlined,
              title: '비상배낭 체크리스트',
              subtitle: '준비물과 체크한 내용',
              onTap: () => _open(context, const ReadinessScreen()),
            ),
            const SizedBox(height: 16),
            const Notice('온라인 지도·새 시설 조회·메시지 전송은 연결 후 이용하세요.'),
            const SizedBox(height: 12),
            const Text(
              '미리 준비하기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '대피소를 저장하고 사진·약도·메모를 추가해 두세요. 저장하지 않은 자료는 오프라인에서 볼 수 없어요.',
            ),
            if (status == LinkStatus.limited)
              const Text('네트워크는 감지됐지만 서버 응답을 확인하지 못했어요. 인터넷 또는 서버 문제일 수 있어요.'),
            OutlinedButton.icon(
              onPressed: connection.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('연결 다시 확인'),
            ),
          ],
        ),
      ),
    );
  }
}
