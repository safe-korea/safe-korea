import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import 'action_brief.dart';

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

      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth < MediaQuery.textScalerOf(context).scale(230)
              ? 1
              : 2;
          final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final setting in [
                UserSetting.indoors,
                UserSetting.outdoors,
                UserSetting.vehicle,
                UserSetting.unknown,
              ])
                SizedBox(
                  width: width,
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(setting.label, textAlign: TextAlign.center),
                    ),
                    showCheckmark: true,
                    selected: setting == _setting,
                    onSelected: (_) => setState(() => _setting = setting),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      for (final (index, brief) in actionBriefs(widget.kind, _setting).indexed)
        ActionBriefTile(brief: brief, primary: index == 0),
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
