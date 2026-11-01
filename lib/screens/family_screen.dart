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
        label: Semantics(
          label: '$title 지도 보기',
          excludeSemantics: true,
          child: const Text('지도 보기'),
        ),
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
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDCE7E1))),
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_editing) ...[
                              FilledButton.icon(
                                onPressed: _saving || _loadFailed
                                    ? null
                                    : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_saving ? '저장 중…' : '기기에 저장'),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_loadFailed ||
                                _dirty ||
                                !canShareMeetingPlan(_savedPlan))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _loadFailed
                                      ? '저장 내용을 다시 읽은 뒤 공유할 수 있어요.'
                                      : _dirty
                                      ? '수정한 내용을 먼저 저장한 뒤 공유하세요.'
                                      : '장소를 하나 저장하면 공유할 수 있어요.',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            FilledButton.icon(
                              onPressed:
                                  _loadFailed ||
                                      _dirty ||
                                      _saving ||
                                      !canShareMeetingPlan(_savedPlan)
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => MeetingShareScreen(
                                          plan: _savedPlan,
                                        ),
                                      ),
                                    ),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('가족에게 공유'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                if (!_savedPlan.hasMeetingPlan) ...[
                  const Text(
                    '만날 장소를 정하세요',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  '가족 약속용 · 공식 대피시설과는 달라요.',
                  style: TextStyle(fontSize: 14),
                ),
                const Text(
                  '온라인 지도 이용 시 IP·조회 범위가 지도 제공자에게 전달됩니다.',
                  style: TextStyle(fontSize: 13),
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
                  for (final place in [
                    (
                      label: '첫 번째 만남 장소',
                      name: _savedPlan.meetingPlace,
                      point: _savedPlan.meetingPoint,
                    ),
                    (
                      label: '대체 장소',
                      name: _savedPlan.backupPlace,
                      point: _savedPlan.backupPoint,
                    ),
                  ])
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
                            SelectableText(
                              place.name.isEmpty ? '아직 정하지 않았어요' : place.name,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (place.point != null)
                              _pointSummary(place.point!, place.label),
                          ],
                        ),
                      ),
                    ),
                  if (_savedPlan.note.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('가족 약속 보기'),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [SelectableText(_savedPlan.note)],
                    ),
                  const SizedBox(height: 12),
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
                            '대체 장소',
                            '가족끼리 정한 약속',
                            '추가 연락처 이름',
                            '추가 연락처 전화번호',
                          ][index],
                          prefixIcon: Icon(switch (index) {
                            2 => Icons.place_outlined,
                            3 => Icons.alt_route,
                            _ => Icons.edit_note_outlined,
                          }),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    if (index != 4) ...[
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
                ],
                if (_savedPlan.meetingPoint != null ||
                    _savedPlan.backupPoint != null)
                  ExpansionTile(
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    tilePadding: EdgeInsets.zero,
                    title: const Text('저장된 좌표 상세'),
                    children: [
                      for (final entry in [
                        (label: '첫 번째 장소', point: _savedPlan.meetingPoint),
                        (label: '대체 장소', point: _savedPlan.backupPoint),
                      ])
                        if (entry.point case final point?)
                          SelectableText(
                            '${entry.label}: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                          ),
                    ],
                  ),
                const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('저장·보관 안내'),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
                OutlinedButton(
                  onPressed: _saving || _loadFailed ? null : _clear,
                  child: const Text('저장된 계획 삭제'),
                ),
              ],
            ),
    ),
  );
}
