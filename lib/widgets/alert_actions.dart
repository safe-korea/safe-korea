import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../theme/app_theme.dart';

/// No GPS inference: selection is optional and stays only in this widget.
class AlertActions extends StatefulWidget {
  const AlertActions({super.key, required this.kind, this.onKindChanged});
  final AlertKind kind;
  final ValueChanged<AlertKind>? onKindChanged;
  @override
  State<AlertActions> createState() => _AlertActionsState();
}

class _AlertActionsState extends State<AlertActions> {
  UserSetting _setting = UserSetting.unknown;
  @override
  void didUpdateWidget(AlertActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _setting = UserSetting.unknown;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '지금 어디에 있나요?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const Text(
        '직접 선택 · 선택 전에도 아래 안내를 볼 수 있어요.',
        style: TextStyle(fontSize: 14),
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final setting in [
            UserSetting.indoors,
            UserSetting.outdoors,
            UserSetting.vehicle,
            UserSetting.unknown,
          ])
            ChoiceChip(
              label: Text(setting.label),
              selected: setting == _setting,
              onSelected: (_) => setState(() => _setting = setting),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final (i, step) in immediateActions(widget.kind, _setting).indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.alert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: i == 0 ? 20 : 16,
                    fontWeight: i == 0 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (widget.kind == AlertKind.cbrn && widget.onKindChanged != null)
        Wrap(
          spacing: 8,
          children: [
            for (final kind in [AlertKind.chemical, AlertKind.biological])
              OutlinedButton(
                onPressed: () => widget.onKindChanged!(kind),
                child: Text('${kind.label} 안내'),
              ),
          ],
        ),
    ],
  );
}
