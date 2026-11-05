import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../screens/saved_shelters_screen.dart';
import '../screens/shelters_screen.dart';
import '../services/saved_shelters_controller.dart';

/// Shared by the drill and the real response screen so practice matches reality.

/// High-contrast drill label placed inside the red response card.
class TrainingBadge extends StatelessWidget {
  const TrainingBadge({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '훈련 / 테스트 · 실제 경보 아님',
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// Where to go next. Saved shelters first when the user prepared them;
/// otherwise the shelter search, which keeps the last fetched list offline.
class ResponseShelterButtons extends StatefulWidget {
  const ResponseShelterButtons({
    super.key,
    required this.kind,
    required this.color,
  });
  final AlertKind kind;
  final Color color;
  @override
  State<ResponseShelterButtons> createState() => _ResponseShelterButtonsState();
}

class _ResponseShelterButtonsState extends State<ResponseShelterButtons> {
  @override
  void initState() {
    super.initState();
    // Loading notifies listeners; never do that while another listener of the
    // shared controller is being built (e.g. preview + real screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SavedSheltersController.shared.ensureLoaded().catchError((Object _) {});
    });
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    if (!widget.kind.offersShelters) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: SavedSheltersController.shared,
      builder: (context, _) {
        final saved = SavedSheltersController.shared.entries.length;
        final primary = FilledButton.styleFrom(
          backgroundColor: widget.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        );
        final search = saved == 0
            ? FilledButton.icon(
                style: primary,
                onPressed: () => _open(const SheltersScreen()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('주변 대피소 보기'),
              )
            : OutlinedButton.icon(
                onPressed: () => _open(const SheltersScreen()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('주변 대피소 보기'),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saved > 0) ...[
              FilledButton.icon(
                style: primary,
                onPressed: () => _open(const SavedSheltersScreen()),
                icon: const Icon(Icons.bookmark),
                label: Text('저장한 대피소 보기 ($saved곳)'),
              ),
              const SizedBox(height: 8),
            ],
            search,
          ],
        );
      },
    );
  }
}
