import 'package:flutter/material.dart';

import '../services/civil_alert_ingress.dart';
import '../models/alert_guidance.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_actions.dart';
import '../widgets/common.dart';
import 'saved_shelters_screen.dart';

/// Response UI for an authenticated, recipient-matched official notice.
/// Manual guidance and drill notification entry points remain separate.
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
  void didUpdateWidget(CivilAlertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice.id != notice.id ||
        oldWidget.notice.revision != notice.revision) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(notice.kind.label),
      backgroundColor: AppPalette.forAlert(notice.kind),
      foregroundColor: Colors.white,
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
              const SizedBox(height: 8),
              Text(notice.area, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AlertActions(
          key: ValueKey('${notice.id}/${notice.revision}'),
          kind: _selected ?? notice.kind,
          onKindChanged: (kind) => setState(() => _selected = kind),
        ),
        if (_selected != null)
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: const Text('공격 종류 다시 확인'),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const SavedSheltersScreen(),
            ),
          ),
          icon: const Icon(Icons.bookmark_outline),
          label: const Text('저장한 대피소 확인'),
        ),
        const SizedBox(height: 12),
        const Text('재난문자·정부 방송과 현장 지시를 우선하세요.'),
        ExpansionTile(
          title: const Text('경보 출처와 시각'),
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
