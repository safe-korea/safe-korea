import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/local_store.dart';
import '../services/meeting_share.dart';
import '../widgets/common.dart';

class MeetingShareScreen extends StatefulWidget {
  const MeetingShareScreen({super.key, required this.plan, this.shareText});
  final FamilyPlan plan;
  final Future<void> Function(String text, Rect origin)? shareText;
  @override
  State<MeetingShareScreen> createState() => _MeetingShareScreenState();
}

class _MeetingShareScreenState extends State<MeetingShareScreen> {
  bool _includeNote = false, _busy = false;
  String? _message;
  String get _text =>
      buildMeetingShareText(widget.plan, includeNote: _includeNote);

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
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
          ShareParams(
            text: text,
            title: '가족 만남 장소',
            subject: '우리 가족 만남 장소',
            sharePositionOrigin: origin,
          ),
        );
      }
      if (mounted) {
        setState(
          () => _message = '전송 여부는 선택한 앱에서 확인하세요. 이 앱에서는 도착 여부를 확인할 수 없습니다.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '공유 창을 열지 못했습니다. 내용을 복사해 카카오톡에 붙여 넣어 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _text));
      if (mounted) setState(() => _message = '내용을 복사했습니다. 보낼 대화방에 붙여 넣어 주세요.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = '복사하지 못했습니다. 아래 내용을 길게 눌러 선택해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('가족에게 공유')),
    body: PageBody(
      children: [
        const Text('보낼 장소를 확인하세요.'),
        const SizedBox(height: 12),
        if (widget.plan.note.trim().isNotEmpty)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('가족 약속도 포함'),
            value: _includeNote,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeNote = value ?? false),
          ),
        for (final place in [
          (
            label: '첫 번째 장소',
            name: widget.plan.meetingPlace,
            point: widget.plan.meetingPoint,
          ),
          (
            label: '대체 장소',
            name: widget.plan.backupPlace,
            point: widget.plan.backupPoint,
          ),
        ])
          if (place.name.trim().isNotEmpty || place.point?.isValid == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      place.label,
                      style: const TextStyle(fontSize: 14, color: teal),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.name.trim().isEmpty ? '지도에 지정한 장소' : place.name,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.point?.isValid == true ? '지도 링크 포함' : '지도 위치 미지정',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        if (_includeNote)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(widget.plan.note),
          ),
        const SizedBox(height: 16),
        const Text(
          '장소·지도 링크·선택한 약속을 보냅니다.\n공유 앱과 상대는 직접 선택해요.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            onPressed: _busy || !canShareMeetingPlan(widget.plan)
                ? null
                : () => _share(buttonContext),
            icon: const Icon(Icons.share_outlined),
            label: Text(_busy ? '공유 창 여는 중…' : '카카오톡 등으로 공유'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || !canShareMeetingPlan(widget.plan) ? null : _copy,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('내용 복사'),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('전송 내용 전체 보기'),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(_text),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
      ],
    ),
  );
}
