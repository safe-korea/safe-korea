import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'drill_screen.dart';
import 'guidelines_screen.dart';
import 'family_screen.dart';
import 'shelters_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'SAFE KOREA',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    ),
    body: PageBody(
      children: [
        const Text(
          '평소의 준비가,\n위기의 나를 지킵니다.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: ink,
          ),
        ),
        const SizedBox(height: 16),
        const Notice('비공식 대비 앱 · 실제 정부 경보 수신 기능 없음'),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '미리 연습해 보세요',
                style: TextStyle(
                  color: Color(0xFFA7E2D1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '공습경보가 울린다면?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '실제 경보가 아닌 조용한 대피 연습입니다.',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _open(context, const DrillScreen()),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('모의 공습경보 시작'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '지금 준비할 수 있는 일',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _tile(
          context,
          Icons.near_me_outlined,
          '주변 대피시설',
          '공식 자료 · 위치 · 지도',
          const SheltersScreen(),
        ),
        _tile(
          context,
          Icons.menu_book_outlined,
          '상황별 행동강령',
          '인터넷 없이 읽는 대응 안내',
          const GuidelinesScreen(),
        ),
        _tile(
          context,
          Icons.people_outline,
          '가족 안전 계획',
          '비상연락처와 만남 장소 저장',
          const FamilyScreen(),
        ),
        const SizedBox(height: 16),
        const Text(
          '실제 상황에서는 재난문자, 정부 방송과 현장 통제 안내를 우선하세요. 이 앱은 이동 경로의 안전을 판단하지 않습니다.',
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'SAFE KOREA'),
          child: const Text('오픈소스 라이선스'),
        ),
      ],
    ),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context, page),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32, color: teal),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
