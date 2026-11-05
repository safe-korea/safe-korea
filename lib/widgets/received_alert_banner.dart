import 'dart:async';

import 'package:flutter/material.dart';

import '../services/civil_alert_ingress.dart';
import '../theme/app_theme.dart';
import 'civil_alert_navigation.dart';

String receivedAtLabel(CivilAlertNotice notice, DateTime now) {
  final local = notice.issuedAt.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final minutes = now.difference(notice.issuedAt).inMinutes;
  return '$time 수신 · ${minutes < 1 ? '방금' : '$minutes분 전'}';
}

/// Keeps a received alert reachable from home after the response screen was
/// closed or the app was opened later than the automatic-open window.
class ReceivedAlertBanner extends StatefulWidget {
  const ReceivedAlertBanner({super.key});
  @override
  State<ReceivedAlertBanner> createState() => _ReceivedAlertBannerState();
}

class _ReceivedAlertBannerState extends State<ReceivedAlertBanner> {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<CivilAlertNotice?>(
        valueListenable: CivilAlertNavigation.recentOf(context),
        builder: (context, notice, _) {
          final now = DateTime.now();
          if (notice == null || !notice.recentAt(now)) {
            return const SizedBox.shrink();
          }
          final color = AppPalette.forAlert(notice.kind);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      notice.testOnly
                          ? '훈련 / 테스트 · ${notice.kind.label}'
                          : '${notice.kind.label} 수신',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receivedAtLabel(notice, now),
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (!notice.testOnly)
                      const Text(
                        '해제 여부는 재난문자·정부 방송으로 확인하세요.',
                        style: TextStyle(color: Colors.white),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          CivilAlertNavigation.reopen(context, notice),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('대응 화면 다시 열기'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
