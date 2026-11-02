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
          kind: _kind,
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
          title: '경보 구분 연습',
          subtitle: '직접 보내는 연습 알림 · 실제 경보 아님',
        ),
        const SizedBox(height: 16),
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
        Text(_kind.signal),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_kind.hasSiren ? '사이렌 켜기' : '음성 안내 켜기'),
          subtitle: Text(
            _kind.hasSiren ? '8초 훈련용 합성음 · 실제 신호의 일부' : '훈련용 합성 음성 · 정부 방송 아님',
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
        const Text('무음·집중 모드에서는 소리가 나지 않을 수 있어요.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : () => _perform(),
          icon: const Icon(Icons.notifications_outlined),
          label: Text(_busy ? '처리 중…' : '지금 테스트 알림 보내기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _perform(cancel: true),
          child: const Text('테스트 알림 지우기'),
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
        const Text(
          '공습·핵 경보는 같은 사이렌입니다. 종류는 문자·방송으로 확인하세요.',
          style: TextStyle(fontSize: 14),
        ),
        if (_status != null) Semantics(liveRegion: true, child: Text(_status!)),
      ],
    ),
  );
}
