import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../widgets/alert_actions.dart';
import '../widgets/common.dart';
import 'shelters_screen.dart';

class AlertGuideScreen extends StatefulWidget {
  const AlertGuideScreen({super.key, this.initialKind = AlertKind.air});
  final AlertKind initialKind;
  @override
  State<AlertGuideScreen> createState() => _AlertGuideScreenState();
}

class _AlertGuideScreenState extends State<AlertGuideScreen> {
  late AlertKind _kind = widget.initialKind;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 상황별 행동요령')),
    body: PageBody(
      children: [
        const Text(
          '받은 정부 경보를 선택하세요. 앱이 경보를 수신하거나 위치 상황을 판단하지 않습니다.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AlertKind>(
          key: ValueKey(_kind),
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '경보·공격 종류'),
          items: [
            for (final kind in AlertKind.values)
              DropdownMenuItem(value: kind, child: Text(kind.label)),
          ],
          onChanged: (kind) {
            if (kind != null) setState(() => _kind = kind);
          },
        ),
        const SizedBox(height: 20),
        Text(
          _kind.headline,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        AlertActions(
          kind: _kind,
          onKindChanged: (kind) => setState(() => _kind = kind),
        ),
        if (_kind.offersShelters)
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SheltersScreen()),
            ),
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('대피시설 확인'),
          ),
        const SizedBox(height: 12),
        const Text('정부 방송·현장 지시를 우선하세요.', style: TextStyle(fontSize: 14)),
        ExpansionTile(
          title: const Text('경보 신호와 출처'),
          children: [
            Text(_kind.signal),
            const Text('공습·핵 경보의 사이렌은 같습니다. 소리만으로 공격 종류를 판단하지 마세요.'),
            const Text('행정안전부 행동요령을 앱에서 요약 · 확인 2026-11-01'),
            TextButton(
              onPressed: () => openExternal(context, Uri.parse(guidanceSource)),
              child: const Text('정부 행동요령 원문'),
            ),
            TextButton(
              onPressed: () => openExternal(context, Uri.parse(signalSource)),
              child: const Text('공식 경보 신호 규정'),
            ),
          ],
        ),
      ],
    ),
  );
}
