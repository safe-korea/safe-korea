import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/system_civil_alert_link.dart';
import 'notification_test_screen.dart';
import '../widgets/common.dart';

class SystemCivilAlertSettingsScreen extends StatefulWidget {
  const SystemCivilAlertSettingsScreen({super.key});
  @override
  State<SystemCivilAlertSettingsScreen> createState() =>
      _SystemCivilAlertSettingsScreenState();
}

class _SystemCivilAlertSettingsScreenState
    extends State<SystemCivilAlertSettingsScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _status = {};
  bool _consent = false, _busy = false;
  String? _error;
  final _link = SystemCivilAlertLink.shared;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await _link.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _error = '이 기기에서 연결 상태를 확인하지 못했어요.');
    }
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      await _link.setEnabled(true);
      await _link.start();
      await _link.openSettings();
    } catch (_) {
      if (mounted) setState(() => _error = '기기 설정을 열지 못했어요. 다시 시도하세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('휴대전화 경보 연결')),
    body: PageBody(
      children: [
        const Text(
          '시스템 재난문자와 행동 안내 연결',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Notice(
          'Android 기기 내 연결 · 실험 기능\n휴대전화에 표시된 민방공 경보를 선별해 행동 안내로 연결합니다.',
        ),
        const SizedBox(height: 12),
        const Text(
          '• 앱 사용 중에는 대피 안내 화면을 엽니다.\n• 다른 앱 사용 중에는 안내 알림을 눌러 들어옵니다.\n• 원래 재난문자의 사이렌·표시를 제어하지 않습니다.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationTestScreen(),
            ),
          ),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('테스트 알림으로 대응 화면 확인'),
        ),
        const SizedBox(height: 16),
        Text(
          _status['enabled'] == true && _status['accessGranted'] == true
              ? '기기 연결 사용 중'
              : '기기 연결 꺼짐 또는 권한 동의 대기',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (_status['sourceInstalled'] == false)
          const Notice(
            '지원 확인된 시스템 재난문자 앱을 찾지 못했어요. 제조사별 호환성 확인이 필요합니다.',
            warning: true,
          ),
        const SizedBox(height: 16),
        const Text(
          '권한 범위를 먼저 확인하세요',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text(
          '‘알림 접근 권한’은 다른 앱 알림에도 접근할 수 있는 권한입니다. safeKor는 발신 앱을 먼저 확인하고, 지원된 시스템 재난문자의 명확한 경보 발령 문구만 처리합니다. 개인 알림 내용은 읽거나 저장·전송하지 않습니다. 경보 원문도 서버에 보내지 않습니다.',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          title: const Text('권한 범위와 기기 내 선별 처리를 확인했습니다'),
        ),
        FilledButton.icon(
          onPressed: _consent && !_busy && _status['sourceInstalled'] == true
              ? _enable
              : null,
          icon: const Icon(Icons.settings_outlined),
          label: Text(_busy ? '설정 여는 중…' : '알림 접근 설정에서 연결 허용'),
        ),
        OutlinedButton(
          onPressed: () async {
            await FlutterLocalNotificationsPlugin()
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();
            await _refresh();
          },
          child: const Text('대피 안내 알림 표시 허용'),
        ),
        if (_status['enabled'] == true)
          TextButton(
            onPressed: () async {
              await _link.setEnabled(false);
              await _refresh();
            },
            child: const Text('이 기기 연결 끄기'),
          ),
        const Text(
          '연결을 꺼도 Android의 알림 접근 권한은 남을 수 있어요. 완전히 철회하려면 기기 설정에서 safeKor의 알림 접근을 해제하세요.',
        ),
        TextButton(
          onPressed: () async {
            try {
              await _link.openSettings();
            } catch (_) {
              if (mounted) setState(() => _error = '기기 설정을 열지 못했어요.');
            }
          },
          child: const Text('기기 알림 접근 설정 열기'),
        ),
        if (_error != null) Notice(_error!, warning: true),
        const SizedBox(height: 12),
        const Text(
          'Google/AOSP 시스템 재난문자 앱을 확인한 기기에서만 연결합니다. 훈련·예고·해제·일반 재난 및 문맥이 불명확한 알림은 자동 연결하지 않습니다. 원본 재난문자·정부 방송을 함께 확인하세요.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}
