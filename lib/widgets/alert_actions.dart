import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../theme/app_theme.dart';
import 'action_brief.dart';
import 'action_speech_button.dart';
import 'situation_selector.dart';

/// No GPS inference: selection is optional and stays only in this widget.
class AlertActions extends StatefulWidget {
  const AlertActions({
    super.key,
    required this.kind,
    this.onKindChanged,
    this.training = false,
  });
  final bool training;
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
      SituationSelector(
        value: _setting,
        onChanged: (setting) => setState(() => _setting = setting),
      ),
      const SizedBox(height: 8),
      for (final (index, brief) in actionBriefs(widget.kind, _setting).indexed)
        ActionBriefTile(
          brief: brief,
          primary: index == 0,
          accent: AppPalette.forAlert(widget.kind),
        ),
      ActionSpeechButton(
        text:
            '${widget.training ? '훈련 안내입니다. 실제 경보가 아닙니다. ' : '선택한 상황의 행동요령입니다. '}${widget.kind.label}. ${immediateActions(widget.kind, _setting).join(' ')}',
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
