import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../widgets/common.dart';

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
        _editing = plan.isEmpty;
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
        contactName: _fields[0].text.trim(),
        phone: _fields[1].text.trim(),
        meetingPlace: _fields[2].text.trim(),
        backupPlace: _fields[3].text.trim(),
        note: _fields[4].text.trim(),
        backupContactName: _fields[5].text.trim(),
        backupPhone: _fields[6].text.trim(),
      );
      await _store.save(plan);
      if (mounted) {
        setState(() {
          _dirty = false;
          _savedPlan = plan;
          _editing = plan.isEmpty;
          _message = '이 기기에 저장했습니다. 종이 연락카드도 준비해 두세요.';
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
        title: const Text('가족 계획을 삭제할까요?'),
        content: const Text('이 기기에 저장된 연락처와 계획을 삭제합니다.'),
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
      await _store.clear();
      if (!mounted) return;
      for (final field in _fields) {
        field.clear();
      }
      setState(() {
        _loadFailed = false;
        _dirty = false;
        _savedPlan = const FamilyPlan();
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
      appBar: AppBar(title: const Text('가족 안전 계획')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                const Notice(
                  '연락처와 계획은 이 기기에만 저장됩니다. 서버 전송·자동 연락·가족 위치 추적은 하지 않습니다.',
                ),
                const Text(
                  '통신이 끊겨도 만날 수 있도록',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '가족과 합의한 장소를 기록하세요. 기기를 잃어버릴 수 있으니 종이 연락카드도 준비하세요. 저장 내용은 앱 내부 평문이며 기기 잠금으로 보호해 주세요.',
                ),
                const SizedBox(height: 20),
                if (_message != null)
                  Semantics(liveRegion: true, child: Notice(_message!)),
                if (_loadFailed)
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('저장 내용 다시 읽기'),
                  ),
                if (!_savedPlan.isEmpty) ...[
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
                          if (_savedPlan.contactName.isNotEmpty ||
                              _savedPlan.phone.isNotEmpty)
                            SelectableText(
                              '비상연락처\n${_savedPlan.contactName}  ${_savedPlan.phone}',
                            ),
                          if (_savedPlan.backupContactName.isNotEmpty ||
                              _savedPlan.backupPhone.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              '추가 연락처\n${_savedPlan.backupContactName}  ${_savedPlan.backupPhone}',
                            ),
                          ],
                          const Divider(height: 32),
                          SelectableText(
                            '첫 번째 만남 장소\n${_savedPlan.meetingPlace.isEmpty ? '아직 정하지 않았어요' : _savedPlan.meetingPlace}',
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            '두 번째 만남 장소\n${_savedPlan.backupPlace.isEmpty ? '아직 정하지 않았어요' : _savedPlan.backupPlace}',
                          ),
                          if (_savedPlan.note.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SelectableText(_savedPlan.note),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!_editing)
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('가족 계획 수정'),
                    ),
                  const SizedBox(height: 16),
                ],
                if (_editing) ...[
                  for (final index in [0, 1, 5, 6, 2, 3, 4]) ...[
                    if ([0, 5, 2, 4].contains(index))
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        child: Text(
                          switch (index) {
                            0 => '비상연락처',
                            5 => '추가 비상연락처',
                            2 => '만남 장소',
                            _ => '메모',
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
                            '대피 계획 · 도움이 필요한 사항',
                            '추가 연락처 이름',
                            '추가 연락처 전화번호',
                          ][index],
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                  FilledButton(
                    onPressed: _saving || _loadFailed ? null : _save,
                    child: Text(_saving ? '저장 중…' : '기기에 저장'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _saving ? null : _clear,
                  child: const Text('저장된 계획 삭제'),
                ),
              ],
            ),
    ),
  );
}
