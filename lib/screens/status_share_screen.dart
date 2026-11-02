import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/common.dart';

class StatusShareScreen extends StatefulWidget {
  const StatusShareScreen({super.key, this.training = false, this.shareText});
  final bool training;
  final Future<void> Function(String, Rect)? shareText;
  @override
  State<StatusShareScreen> createState() => _StatusShareScreenState();
}

class _StatusShareScreenState extends State<StatusShareScreen> {
  final _place = TextEditingController();
  String? _status, _message;
  bool _busy = false;
  String get _text =>
      '${widget.training ? '[훈련 / 테스트] 실제 상황이 아닙니다.\n' : ''}$_status${_place.text.trim().isEmpty ? '' : '\n장소: ${_place.text.trim()}'}\n직접 작성한 상태입니다. 위치·안전 여부는 앱에서 확인하지 않습니다.';
  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext context) async {
    if (_status == null) return;
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final text = _text;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (widget.shareText != null) {
        await widget.shareText!(text, origin);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, sharePositionOrigin: origin),
        );
      }
      if (mounted) setState(() => _message = '전송 여부는 선택한 앱에서 확인하세요.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = '공유 창을 열지 못했어요. 미리보기 내용을 길게 눌러 복사해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.training ? '훈련 · 내 상태 공유' : '내 상태 공유')),
    body: PageBody(
      children: [
        const IconTextBlock(
          icon: Icons.chat_bubble_outline,
          title: '알릴 상태를 직접 선택하세요',
          body: Text('자동 전송하지 않아요. 카카오톡 등에서 받는 사람을 선택해 보내세요.'),
        ),
        const SizedBox(height: 16),
        for (final status in ['대피 중입니다.', '이 장소에 도착했습니다.'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(status, textAlign: TextAlign.center),
              ),
              selected: _status == status,
              showCheckmark: true,
              onSelected: _busy
                  ? null
                  : (_) => setState(() => _status = status),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _place,
          enabled: !_busy,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: '알릴 장소 · 선택',
            hintText: '직접 확인한 장소 이름',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text(
          '보낼 내용',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_status == null ? '위에서 상태를 선택해 주세요.' : _text),
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) => FilledButton.icon(
            onPressed: _busy || _status == null ? null : () => _share(context),
            icon: const Icon(Icons.share_outlined),
            label: Text(_busy ? '공유 창 여는 중…' : '확인하고 공유 앱 열기'),
          ),
        ),
        if (_message != null)
          Semantics(liveRegion: true, child: Notice(_message!)),
      ],
    ),
  );
}
