import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/web_push_bridge.dart';

import 'package:flutter/services.dart';

import '../services/civil_alert_ingress.dart';
import '../models/alert_guidance.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_actions.dart';
import '../widgets/common.dart';
import '../widgets/received_alert_banner.dart';
import '../widgets/response_parts.dart';

/// Response UI for an authenticated, recipient-matched official notice.
/// Own-device response previews share this layout with a persistent test label.
class CivilAlertScreen extends StatefulWidget {
  const CivilAlertScreen({super.key, required this.notice});
  final CivilAlertNotice notice;
  @override
  State<CivilAlertScreen> createState() => _CivilAlertScreenState();
}

class _CivilAlertScreenState extends State<CivilAlertScreen> {
  AlertKind? _selected;
  CivilAlertNotice get notice => widget.notice;
  @override
  void dispose() {
    if (kIsWeb && notice.testOnly) stopWebTestSiren();
    super.dispose();
  }

  @override
  void didUpdateWidget(CivilAlertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && oldWidget.notice.testOnly && !notice.testOnly) {
      stopWebTestSiren();
    }
    if (oldWidget.notice.id != notice.id ||
        oldWidget.notice.revision != notice.revision) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.backgroundForAlert(notice.kind),
    appBar: AppBar(
      title: Text(
        notice.testOnly ? '훈련 / 테스트 · ${notice.kind.label}' : notice.kind.label,
      ),
      backgroundColor: AppPalette.forAlert(notice.kind),
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    body: PageBody(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.forAlert(notice.kind),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice.testOnly) ...[
                TrainingBadge(color: AppPalette.forAlert(notice.kind)),
                const SizedBox(height: 12),
              ],
              Text(
                notice.kind.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notice.kind.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (notice.kind == AlertKind.air) ...[
                const SizedBox(height: 8),
                const Text(
                  '물품을 찾느라 지체하지 마세요',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
              const SizedBox(height: 8),
              Text(notice.area, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                receivedAtLabel(notice, DateTime.now()),
                style: const TextStyle(color: Colors.white),
              ),
              if (!notice.freshAt(DateTime.now()))
                const Text(
                  '받은 지 시간이 지났어요. 해제 여부는 재난문자·정부 방송으로 확인하세요.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        if (notice.testOnly && kIsWeb) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final played = await playWebTestSiren();
                    if (!played && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('소리를 재생하지 못했어요. 볼륨·브라우저 설정을 확인하세요.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('사이렌 듣기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: stopWebTestSiren,
                  icon: const Icon(Icons.volume_off_outlined),
                  label: const Text('소리 끄기'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        ResponseShelterButtons(
          kind: _selected ?? notice.kind,
          color: AppPalette.forAlert(_selected ?? notice.kind),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AlertActions(
            key: ValueKey('${notice.id}/${notice.revision}'),
            kind: _selected ?? notice.kind,
            training: notice.testOnly,
            onKindChanged: (kind) => setState(() => _selected = kind),
          ),
        ),
        if (_selected != null)
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: const Text('공격 종류 다시 확인'),
          ),
        const SizedBox(height: 12),
        const Text('재난문자·정부 방송과 현장 지시를 우선하세요.'),
        ExpansionTile(
          title: Text(notice.testOnly ? '테스트 출처와 시각' : '경보 출처와 시각'),
          children: [
            InfoLine(label: '알림 출처', value: notice.agency),
            InfoLine(
              label: '알림 시각',
              value: notice.issuedAt.toLocal().toString(),
            ),
            InfoLine(label: '대상지역', value: notice.area),
          ],
        ),
      ],
    ),
  );
}
