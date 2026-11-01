import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/drill_notifications.dart';
import '../widgets/common.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key, this.notifications});
  final DrillNotifications? notifications;
  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _sound = false, _vibration = false, _busy = false;
  String? _status;
  DrillNotifications get _notifications =>
      widget.notifications ?? DrillNotifications.instance;

  Future<void> _perform({bool cancel = false}) async {
    setState(() => _busy = true);
    String message;
    try {
      if (cancel) {
        await _notifications.cancel();
        message = '테스트 알림을 지웠습니다.';
      } else {
        final allowed = await _notifications.send(
          sound: _sound,
          vibration: _vibration,
        );
        message = allowed
            ? '테스트 알림을 요청했습니다. 알림 센터에서 눌러 훈련 화면을 여세요. 표시·소리·진동은 기기 설정에 따라 달라집니다.'
            : '알림 권한이 없습니다. 기기 설정에서 SAFE KOREA 알림을 허용하세요. 알림 없이도 홈에서 훈련할 수 있습니다.';
      }
    } catch (_) {
      message = '알림을 처리하지 못했습니다. 다시 시도하거나 홈에서 훈련을 시작하세요.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _status = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('테스트 알림')),
    body: PageBody(
      children: [
        const PageIntro(
          eyebrow: '훈련 / 테스트',
          title: '사이렌으로 알아차리기',
          subtitle: '직접 보내는 테스트 알림입니다. 실제 정부 경보가 아닙니다.',
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('사이렌 켜기'),
          subtitle: const Text('6초 사이렌 · 테스트 버튼을 누르면 울립니다'),
          value: _sound,
          onChanged: _busy ? null : (value) => setState(() => _sound = value),
        ),
        if (defaultTargetPlatform == TargetPlatform.android)
          SwitchListTile(
            title: const Text('진동 켜기'),
            value: _vibration,
            onChanged: _busy
                ? null
                : (value) => setState(() => _vibration = value),
          ),
        const SizedBox(height: 12),
        const Text('소리·진동은 기기의 무음·집중 모드와 알림 설정을 따릅니다.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : () => _perform(),
          icon: const Icon(Icons.notifications_outlined),
          label: Text(_busy ? '처리 중…' : '지금 테스트 알림 보내기'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _perform(cancel: true),
          child: const Text('테스트 알림 지우기'),
        ),
        if (_status != null) Semantics(liveRegion: true, child: Text(_status!)),
      ],
    ),
  );
}
