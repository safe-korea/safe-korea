import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../models/alert_guidance.dart';
import '../widgets/alert_actions.dart';
import '../widgets/common.dart';
import '../widgets/drill_elapsed_timer.dart';
import 'guidelines_screen.dart';
import 'readiness_screen.dart';
import 'saved_shelters_screen.dart';
import 'shelters_screen.dart';
import 'after_arrival_screen.dart';
import '../services/saved_shelters_controller.dart';
import '../models/saved_shelter.dart';

class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key, this.kind = AlertKind.air});
  final AlertKind kind;
  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  final _checked = <int>{};
  late AlertKind _kind = widget.kind;
  @override
  void initState() {
    super.initState();
    SavedSheltersController.shared.ensureLoaded();
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.backgroundForAlert(_kind),
    appBar: AppBar(
      title: const Text('훈련 / 테스트'),
      actions: [
        PopupMenuButton<AlertKind>(
          tooltip: '경보 종류 변경',
          icon: const Icon(Icons.tune),
          onSelected: (kind) => setState(() {
            _kind = kind;
            _checked.clear();
          }),
          itemBuilder: (_) => [
            for (final kind in AlertKind.values)
              PopupMenuItem(value: kind, child: Text(kind.label)),
          ],
        ),
      ],
      backgroundColor: AppPalette.forAlert(_kind),
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.forAlert(_kind),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_kind.label} 연습',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _kind == AlertKind.air ? 18 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _kind == AlertKind.air ? '실제 공습경보가 아닙니다' : '실제 경보가 아닙니다',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (_kind == AlertKind.air) ...[
                const SizedBox(height: 12),
                const Text(
                  '지금 즉시 대피하세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '물품을 찾느라 지체하지 마세요',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white38, height: 1),
              ),
              const DrillElapsedTimer(compact: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_kind == AlertKind.air) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.forAlert(_kind),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _open(const SheltersScreen()),
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('주변 대피소 보기'),
          ),
          ListenableBuilder(
            listenable: SavedSheltersController.shared,
            builder: (context, _) {
              final hasPlan = SavedSheltersController.shared.entries.any(
                (entry) => entry.role != ShelterRole.none,
              );
              return hasPlan
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _open(const SavedSheltersScreen()),
                        icon: const Icon(Icons.bookmark),
                        label: const Text('내 주·대체 대피소 바로 보기'),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AlertActions(
            kind: _kind,
            training: true,
            onKindChanged: (kind) => setState(() => _kind = kind),
          ),
        ),
        if (_kind.offersShelters && _kind != AlertKind.air)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.forAlert(_kind),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _open(const SheltersScreen()),
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('대피시설 확인'),
          ),
        if (_kind == AlertKind.air) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const IconTextBlock(
              icon: Icons.backpack_outlined,
              iconColor: AppPalette.alert,
              title: '손 닿는 곳에 있으면 챙기세요',
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '없으면 바로 대피하세요.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: AppPalette.muted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '준비된 배낭 · 물 · 상비약 · 손전등',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_kind == AlertKind.air)
          OutlinedButton.icon(
            onPressed: () => _open(const AfterArrivalScreen(training: true)),
            icon: const Icon(Icons.task_alt),
            label: const Text('대피 후 할 일·상태 공유'),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('정부 방송·현장 지시를 우선하세요.', style: TextStyle(fontSize: 14)),
        ),
        if (_kind == AlertKind.air)
          ExpansionTile(
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            tilePadding: EdgeInsets.zero,
            title: const Text('행동요령 보기'),
            childrenPadding: const EdgeInsets.symmetric(vertical: 16),
            children: [
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
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Notice(
                      '대피 행동 연습을 마쳤어요. 실제 상황에서는 최신 정부·현장 안내에 따라 행동하세요.',
                    ),
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
      ],
    ),
  );
}
