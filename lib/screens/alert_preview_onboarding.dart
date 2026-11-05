import 'package:flutter/material.dart';

import '../models/alert_guidance.dart';
import '../services/civil_alert_ingress.dart';
import '../theme/app_theme.dart';
import 'civil_alert_screen.dart';
import 'system_civil_alert_settings_screen.dart';

/// First-run screen: shows what opens when an air-raid alert reaches the
/// phone, so people know why to keep the app. Always labelled as an example;
/// never claims to receive government alerts by itself.
class AlertPreviewOnboarding extends StatelessWidget {
  const AlertPreviewOnboarding({super.key, required this.onDone});
  final VoidCallback onDone;

  static CivilAlertNotice example() {
    final now = DateTime.now();
    return CivilAlertNotice(
      id: 'response-test/onboarding',
      revision: 'test',
      kind: AlertKind.air,
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 2)),
      agency: '앱 소개용 예시',
      area: '예시 화면 · 실제 경보 아님',
      testOnly: true,
    );
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onDone, child: const Text('건너뛰기')),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Text(
                  '공습경보가 울리면\n이 화면이 열려요',
                  // Large titles broke mid-word at 200%; body text still scales.
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.4),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '휴대전화에 민방공 재난문자가 오면 safeKor가 지금 할 행동과 대피소를 바로 보여줘요.',
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: '예시 화면: 공습경보 대응 화면 미리보기. 실제 경보 아님',
                  child: ExcludeSemantics(
                    child: Center(child: _PhonePreview(notice: example())),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '‘휴대전화 경보 연결’을 켜야 동작해요. 다른 앱을 쓰는 중에는 알림을 눌러 들어와요. 정부 경보를 대신 받는 앱은 아니며, 재난문자·정부 방송이 우선이에요.',
                  style: TextStyle(fontSize: 14, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.alert,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    // Open settings first; finishing replaces this screen.
                    _push(context, const SystemCivilAlertSettingsScreen());
                    onDone();
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('휴대전화 경보 연결하기'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _push(context, CivilAlertScreen(notice: example())),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('소리 없이 직접 눌러 보기'),
                ),
                TextButton(onPressed: onDone, child: const Text('나중에 할게요')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The real response screen, scaled down and inert, inside a phone outline.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.notice});
  final CivilAlertNotice notice;
  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    height: 400,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF17352D),
      borderRadius: BorderRadius.circular(28),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 390,
            height: 710,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(390, 710),
                textScaler: TextScaler.noScaling,
                padding: EdgeInsets.zero,
              ),
              child: CivilAlertScreen(notice: notice),
            ),
          ),
        ),
      ),
    ),
  );
}
