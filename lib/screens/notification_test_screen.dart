import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/drill_notifications.dart';
import '../models/alert_guidance.dart';
import 'drill_screen.dart';
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
  AlertKind _kind = AlertKind.air;
  DrillNotifications get _notifications =>
      widget.notifications ?? DrillNotifications.instance;

  Future<void> _perform({
    bool cancel = false,
    bool responseTest = false,
  }) async {
    setState(() {
      _busy = true;
      if (responseTest) {
        _status = '권한 허용 후 5초 뒤 테스트합니다. 홈 버튼으로 앱을 나간 뒤 알림을 눌러보세요.';
      }
    });
    String message;
    try {
      if (cancel) {
        await _notifications.cancel();
        message = '테스트 알림을 지웠습니다.';
      } else {
        final allowed = await _notifications.send(
          sound: responseTest || _sound,
          kind: responseTest ? AlertKind.air : _kind,
          responseTest: responseTest,
          vibration: _vibration,
        );
        message = allowed
            ? responseTest
                  ? '알림을 누르면 테스트 표시가 있는 빨간 대피 안내 화면이 열립니다.'
                  : '알림 센터에서 테스트 알림을 눌러 훈련을 시작하세요. 표시·소리·진동은 기기 설정에 따라 달라집니다.'
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
          title: '경보 구분 연습',
          subtitle: '직접 보내는 연습 알림 · 실제 경보 아님',
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _perform(responseTest: true),
          icon: const Icon(Icons.open_in_new),
          label: const Text('사이렌으로 대응 화면 테스트'),
        ),
        const SizedBox(height: 8),
        const Text(
          '5초 뒤 사이렌·공습경보 테스트 알림 · 앱 사용 중에는 바로 화면 전환, 앱 밖에서는 알림을 눌러 확인',
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<AlertKind>(
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '연습할 경보'),
          items: [
            for (final kind in AlertKind.values)
              DropdownMenuItem(value: kind, child: Text(kind.label)),
          ],
          onChanged: _busy
              ? null
              : (kind) => setState(() {
                  _kind = kind!;
                  _sound = false;
                }),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_kind.hasSiren ? '사이렌 켜기' : '음성 안내 켜기'),
          subtitle: Text(
            _kind.hasSiren ? '8초 훈련용 합성음' : '훈련용 합성 음성 · 정부 방송 아님',
          ),
          value: _sound,
          onChanged: _busy ? null : (value) => setState(() => _sound = value),
        ),
        if (defaultTargetPlatform == TargetPlatform.android)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('진동 켜기'),
            value: _vibration,
            onChanged: _busy
                ? null
                : (value) => setState(() => _vibration = value),
          ),
        const SizedBox(height: 12),
        const Text('소리는 기기의 무음·집중 모드 설정을 따릅니다.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : () => _perform(),
          icon: const Icon(Icons.notifications_outlined),
          label: Text(_busy ? '처리 중…' : '알림 보내기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _perform(cancel: true),
          child: const Text('알림 지우기'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DrillScreen(kind: _kind),
                  ),
                ),
          child: const Text('소리 없이 행동 연습'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Semantics(liveRegion: true, child: Notice(_status!)),
        ],
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('소리 안내 자세히'),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            Text(_kind.signal),
            const SizedBox(height: 8),
            const Text(
              '공습·핵 경보는 같은 사이렌입니다. 종류는 문자·방송으로 확인하세요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '테스트 소리는 실제 신호의 일부를 재현한 합성음입니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    ),
  );
}
