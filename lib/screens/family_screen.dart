import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../widgets/common.dart';
import 'meeting_point_screen.dart';
import 'meeting_share_screen.dart';
import '../services/meeting_share.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, this.store});
  final LocalStore? store;
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late final LocalStore _store = widget.store ?? LocalStore();
  final _fields = List.generate(7, (_) => TextEditingController());
  bool _loading = true, _saving = false, _loadFailed = false, _dirty = false;
  String? _message;
  FamilyPlan _savedPlan = const FamilyPlan();
  bool _editing = true;
  MeetingPoint? _meetingPoint, _backupPoint;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plan = await _store.load();
      if (!mounted) return;
      final values = [
        plan.contactName,
        plan.phone,
        plan.meetingPlace,
        plan.backupPlace,
        plan.note,
        plan.backupContactName,
        plan.backupPhone,
      ];
      for (var i = 0; i < values.length; i++) {
        _fields[i].text = values[i];
      }
      setState(() {
        _loading = false;
        _loadFailed = false;
        _savedPlan = plan;
        _editing = !plan.hasMeetingPlan;
        _meetingPoint = plan.meetingPoint;
        _backupPoint = plan.backupPoint;
        _message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _message = '저장된 계획을 읽을 수 없습니다. 기존 내용을 보호하기 위해 저장을 멈췄습니다.';
        });
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final plan = FamilyPlan(
        contactName: _savedPlan.contactName,
        phone: _savedPlan.phone,
        meetingPlace: _fields[2].text.trim(),
        backupPlace: _fields[3].text.trim(),
        note: _fields[4].text.trim(),
        backupContactName: _savedPlan.backupContactName,
        backupPhone: _savedPlan.backupPhone,
        meetingPoint: _meetingPoint,
        backupPoint: _backupPoint,
      );
      await _store.save(plan);
      if (mounted) {
        setState(() {
          _dirty = false;
          _savedPlan = plan;
          _editing = !plan.hasMeetingPlan;
          _message = '만남 장소를 이 기기에 저장했습니다. 가족에게도 미리 알려 주세요.';
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('계획 저장 완료')));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = '저장하지 못했습니다. 입력 내용은 화면에 남아 있습니다. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('만남 장소를 삭제할까요?'),
        content: const Text('만남 장소·지도 핀·약속을 삭제합니다. 기존 연락처는 보존합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final preserved = FamilyPlan(
        contactName: _savedPlan.contactName,
        phone: _savedPlan.phone,
        backupContactName: _savedPlan.backupContactName,
        backupPhone: _savedPlan.backupPhone,
      );
      await _store.save(preserved);
      if (!mounted) return;
      for (final field in _fields) {
        field.clear();
      }
      setState(() {
        _loadFailed = false;
        _dirty = false;
        _savedPlan = preserved;
        _meetingPoint = null;
        _backupPoint = null;
        _editing = true;
        _message = '저장된 계획을 삭제했습니다.';
      });
    } catch (_) {
      if (mounted) setState(() => _message = '삭제하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmExit() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장하지 않은 변경이 있습니다'),
        content: const Text('계속 작성하거나 저장한 뒤 나갈 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경 버리고 나가기'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      Navigator.pop(context);
    }
  }

  Future<void> _pickPoint(int index) async {
    final point = await Navigator.push<MeetingPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingPointScreen(
          title: index == 2 ? '첫 번째 만남 장소' : '대체 만남 장소',
          initialPoint: index == 2 ? _meetingPoint : _backupPoint,
        ),
      ),
    );
    if (point == null || !mounted) return;
    setState(() {
      if (index == 2) {
        _meetingPoint = point;
      } else {
        _backupPoint = point;
      }
      _dirty = true;
    });
  }

  Widget _pointSummary(MeetingPoint point, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '좌표 ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MeetingPointScreen(
              title: title,
              initialPoint: point,
              readOnly: true,
            ),
          ),
        ),
        icon: const Icon(Icons.map_outlined),
        label: Text('$title 지도 보기'),
      ),
      const Text(
        '온라인 지도 · IP와 조회 범위가 지도 제공자에게 전달됩니다.',
        style: TextStyle(fontSize: 13),
      ),
    ],
  );

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _confirmExit();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('가족 만남 장소')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                const Notice('가족끼리 정한 장소입니다. 공식 대피시설이나 안전한 이동 경로를 보장하지 않습니다.'),
                const PageIntro(
                  eyebrow: '가족과 미리 약속',
                  title: '어디서 다시 만날까요?',
                  subtitle: '통신이 끊기면 만날 장소와 대체 장소를 정하세요.',
                ),
                const ExpansionTile(
                  title: Text('저장·보관 안내'),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        '장소와 좌표는 기기에만 저장됩니다. 지도는 온라인이며 지도 제공자에게 IP와 조회 범위가 전달됩니다. 가족에게 자동 공유되지 않습니다. 기존 연락처는 수정·삭제하지 않고 보존합니다.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_message != null)
                  Semantics(liveRegion: true, child: Notice(_message!)),
                if (_loadFailed)
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('저장 내용 다시 읽기'),
                  ),
                if (_savedPlan.hasMeetingPlan) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '저장된 가족 계획',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SelectableText(
                            '첫 번째 만남 장소\n${_savedPlan.meetingPlace.isEmpty ? '아직 정하지 않았어요' : _savedPlan.meetingPlace}',
                          ),
                          if (_savedPlan.meetingPoint != null)
                            _pointSummary(
                              _savedPlan.meetingPoint!,
                              '첫 번째 만남 장소',
                            ),
                          const SizedBox(height: 12),
                          SelectableText(
                            '두 번째 만남 장소\n${_savedPlan.backupPlace.isEmpty ? '아직 정하지 않았어요' : _savedPlan.backupPlace}',
                          ),
                          if (_savedPlan.backupPoint != null)
                            _pointSummary(_savedPlan.backupPoint!, '대체 만남 장소'),
                          if (_savedPlan.note.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SelectableText(_savedPlan.note),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (canShareMeetingPlan(_savedPlan)) ...[
                    FilledButton.icon(
                      onPressed: _dirty || _saving
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MeetingShareScreen(plan: _savedPlan),
                              ),
                            ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('가족에게 공유'),
                    ),
                    if (_dirty) const Text('수정한 내용을 먼저 저장한 뒤 공유하세요.'),
                    const SizedBox(height: 8),
                  ],
                  if (!_editing)
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('만남 장소 수정'),
                    ),
                  const SizedBox(height: 16),
                ],
                if (_editing) ...[
                  for (final index in [2, 3, 4]) ...[
                    if ([2, 3, 4].contains(index))
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        child: Text(
                          switch (index) {
                            2 => '01  첫 번째 만남 장소',
                            3 => '02  대체 만남 장소',
                            _ => '가족끼리 정한 약속',
                          },
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        key: ValueKey('family-field-$index'),
                        controller: _fields[index],
                        onChanged: (_) => setState(() {
                          _dirty = true;
                          _message = null;
                        }),
                        enabled: !_saving && !_loadFailed,
                        keyboardType: index == 1 || index == 6
                            ? TextInputType.phone
                            : TextInputType.multiline,
                        minLines: index == 4 ? 3 : 1,
                        maxLines: index == 1 || index == 6 ? 1 : null,
                        maxLength: index == 4 ? 1000 : 160,
                        decoration: InputDecoration(
                          labelText: [
                            '비상연락처 이름',
                            '비상연락처 전화번호',
                            '첫 번째 만남 장소',
                            '연락이 안 될 때 두 번째 장소',
                            '가족끼리 정한 약속',
                            '추가 연락처 이름',
                            '추가 연락처 전화번호',
                          ][index],
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    if (index != 4) ...[
                      const Text(
                        '온라인 지도 · IP와 조회 범위가 지도 제공자에게 전달됩니다.',
                        style: TextStyle(fontSize: 13),
                      ),
                      if ((index == 2 ? _meetingPoint : _backupPoint)
                          case final point?)
                        Text(
                          '선택 좌표 ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                        ),
                      OutlinedButton.icon(
                        onPressed: _saving || _loadFailed
                            ? null
                            : () => _pickPoint(index),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(
                          index == 2 ? '첫 번째 장소 지도에서 지정' : '대체 장소 지도에서 지정',
                        ),
                      ),
                      if ((index == 2 ? _meetingPoint : _backupPoint) != null)
                        TextButton(
                          onPressed: _saving || _loadFailed
                              ? null
                              : () => setState(() {
                                  if (index == 2) {
                                    _meetingPoint = null;
                                  } else {
                                    _backupPoint = null;
                                  }
                                  _dirty = true;
                                }),
                          child: const Text('이 핀 지우기'),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  const Text(
                    '지도는 온라인입니다. 지도 제공자에게 IP와 조회 범위가 전달됩니다. 이름만 저장할 수도 있어요.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving || _loadFailed ? null : _save,
                    child: Text(_saving ? '저장 중…' : '기기에 저장'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _saving || _loadFailed ? null : _clear,
                  child: const Text('저장된 계획 삭제'),
                ),
              ],
            ),
    ),
  );
}
