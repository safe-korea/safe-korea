import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';

final kbsRadioUri = Uri.https('radio.kbs.co.kr', '/kong.html');

class RadioLinkCard extends StatefulWidget {
  const RadioLinkCard({super.key, this.open, this.compact = false});
  final bool compact;
  final Future<bool> Function(Uri)? open;
  @override
  State<RadioLinkCard> createState() => _RadioLinkCardState();
}

class _RadioLinkCardState extends State<RadioLinkCard> {
  bool _busy = false;
  String? _error;
  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened =
          await (widget.open?.call(kbsRadioUri) ??
              launchUrl(kbsRadioUri, mode: LaunchMode.externalApplication));
      if (!opened && mounted) {
        setState(() => _error = '연결을 열지 못했어요. 다시 시도하거나 주소를 복사하세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '연결을 열지 못했어요. 다시 시도하거나 주소를 복사하세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: kbsRadioUri.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('KBS 공식 주소를 복사했습니다.')));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = '주소를 복사하지 못했어요. radio.kbs.co.kr/kong.html을 직접 입력하세요.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.compact) ...[
            const IconTextBlock(
              icon: Icons.radio_outlined,
              title: '라디오 연결',
              body: Text('KBS 공식 서비스 · 인터넷 필요'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.open_in_new),
            label: Text(_busy ? '연결 여는 중…' : 'KBS 라디오 연결'),
          ),
          const SizedBox(height: 8),
          Text(
            widget.compact
                ? '인터넷 필요 · 공식 이용·설치 안내'
                : '공식 사이트에서 이용·설치 안내를 확인하세요. 방송이 자동 재생되지는 않습니다.',
            style: const TextStyle(fontSize: 14),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: const Text('공식 주소 복사'),
            ),
          ],
          if (!widget.compact)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('통신이 끊겼다면'),
              children: const [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '휴대용 라디오나 FM을 지원하는 휴대폰의 기본 라디오를 이용하세요. 기기에 따라 유선 이어폰이 필요합니다. 이 앱의 연결 버튼은 오프라인 방송을 수신하지 않습니다.',
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
