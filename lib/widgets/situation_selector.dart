import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';

/// One row on ordinary phone text sizes; reflows without shrinking large text.
class SituationSelector extends StatelessWidget {
  const SituationSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final UserSetting value;
  final ValueChanged<UserSetting> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              '현재 있는 곳',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '선택 초기화',
            onPressed: value == UserSetting.unknown
                ? null
                : () => onChanged(UserSetting.unknown),
            icon: const Icon(Icons.restart_alt, size: 22),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final minimum = MediaQuery.textScalerOf(context).scale(54) + 24;
          final columns = ((constraints.maxWidth + 8) / (minimum + 8))
              .floor()
              .clamp(1, 3);
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final setting in [
                UserSetting.indoors,
                UserSetting.outdoors,
                UserSetting.vehicle,
              ])
                SizedBox(
                  width: width,
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(setting.label, textAlign: TextAlign.center),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                    selected: value == setting,
                    onSelected: (_) => onChanged(setting),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
