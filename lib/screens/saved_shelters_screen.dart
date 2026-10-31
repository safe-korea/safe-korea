import 'package:flutter/material.dart';

import '../models/saved_shelter.dart';
import '../services/saved_shelters_controller.dart';
import '../services/shelter_repository.dart';
import '../widgets/common.dart';
import '../widgets/shelter_map.dart';

class SavedSheltersScreen extends StatefulWidget {
  const SavedSheltersScreen({super.key, this.controller, this.repository});
  final ShelterRepository? repository;
  final SavedSheltersController? controller;
  @override
  State<SavedSheltersScreen> createState() => _SavedSheltersScreenState();
}

class _SavedSheltersScreenState extends State<SavedSheltersScreen> {
  late final _controller = widget.controller ?? SavedSheltersController.shared;
  String _query = '';
  String? _refreshMessage;
  late final _repository = widget.repository ?? ShelterRepository();
  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  Future<void> _refresh(SavedShelter entry) async {
    setState(() => _refreshMessage = '공식 자료를 다시 확인하고 있습니다…');
    final message = await _controller.refresh(entry, _repository);
    if (mounted) setState(() => _refreshMessage = message);
  }

  String _checkLabel(SavedShelter entry) => switch (entry.check) {
    ShelterCheck.confirmed => '공식 목록 재확인 · 개방 여부 미확인',
    ShelterCheck.changed => '공식 정보 변경 반영 · 개방 여부 미확인',
    ShelterCheck.notFound => '이번 조회에서 찾지 못함 · 기존 정보 유지',
    ShelterCheck.incomplete => '일부 자료 누락으로 확인 불가 · 기존 정보 유지',
    null => '저장 후 다시 확인하지 않음',
  };
  @override
  void initState() {
    super.initState();
    _controller.ensureLoaded();
  }

  String _time(String? raw) {
    final value = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (value == null) return '미제공';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}.${two(value.month)}.${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _remove(SavedShelter entry) async {
    final result = await _controller.toggle(entry.snapshot, entry.shelter.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ? '저장한 대피소에서 해제했습니다.' : '저장 변경에 실패했습니다. 다시 시도해 주세요.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('저장한 대피소')),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final entries = _controller.entries
            .where(
              (entry) => '${entry.shelter.name} ${entry.shelter.address}'
                  .contains(_query.trim()),
            )
            .toList();
        return PageBody(
          children: [
            const Notice(
              '지역을 바꿔도 이 기기에 보관한 대피소를 볼 수 있습니다. 저장된 정보는 자동 갱신되지 않으므로 출입구와 현재 개방 여부는 다시 확인하세요.',
            ),
            if (_refreshMessage != null)
              Semantics(liveRegion: true, child: Notice(_refreshMessage!)),
            if (_controller.loading)
              const Center(child: CircularProgressIndicator()),
            if (_controller.error != null) ...[
              Semantics(liveRegion: true, child: Notice(_controller.error!)),
              OutlinedButton(
                onPressed: _controller.loading || _controller.busy
                    ? null
                    : _controller.load,
                child: const Text('저장 목록 다시 읽기'),
              ),
            ],
            if (_controller.loaded && _controller.entries.isEmpty)
              const Text(
                '저장한 대피소가 아직 없어요.\n지역 조회 결과나 지도 상세에서 대피소 저장을 눌러 두세요.',
                style: TextStyle(fontSize: 21),
              ),
            if (_controller.entries.isNotEmpty) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: '저장한 시설 검색',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Text(
                '저장한 시설 ${_controller.entries.length}곳 · 검색 결과 ${entries.length}곳',
              ),
              const SizedBox(height: 12),
              const Text('온라인 지도를 열면 조회 지역과 IP가 지도 제공자에게 전달됩니다.'),
              const SizedBox(height: 12),
              for (final entry in entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry.shelter.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(entry.shelter.address),
                        const SizedBox(height: 12),
                        Text(
                          '조회 지역: ${entry.snapshot.coverage}\n공식 자료 조회: ${_time(entry.snapshot.retrievedAt)}\n기기 저장: ${_time(entry.savedAt.toIso8601String())}',
                        ),
                        Text(_checkLabel(entry)),
                        if (entry.checkedAt != null)
                          Text(
                            '최근 재확인: ${_time(entry.checkedAt!.toIso8601String())}',
                          ),
                        const Text('현재 개방·수용 여유·이동 경로 안전 미확인'),
                        const SizedBox(height: 12),
                        const Text('재확인 시 이 시설의 지역 코드와 IP가 국민안전24에 전달됩니다.'),
                        OutlinedButton.icon(
                          onPressed:
                              _controller.loaded &&
                                  !_controller.busy &&
                                  !_controller.loading
                              ? () => _refresh(entry)
                              : null,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _controller.busy ? '저장 목록 처리 중…' : '공식 자료 다시 확인',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text(
                                    entry.check == ShelterCheck.notFound ||
                                            entry.check ==
                                                ShelterCheck.incomplete
                                        ? '이전 저장 정보 지도'
                                        : '저장한 대피소 지도',
                                  ),
                                ),
                                body: SafeArea(
                                  child: ShelterMap(
                                    shelters: [entry.shelter],
                                    onSelected: (_) => showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => SafeArea(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24),
                                          child: SelectableText(
                                            '${entry.shelter.name}\n${entry.shelter.address}\n공식 자료 조회: ${_time(entry.snapshot.retrievedAt)}\n${_checkLabel(entry)}\n현재 개방 여부는 현장에서 확인하세요.',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('온라인 지도 보기'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => openExternal(
                                context,
                                Uri.parse(entry.snapshot.sourceUrl),
                              ),
                              child: const Text('공식 출처 열기'),
                            ),
                            TextButton.icon(
                              onPressed: _controller.loaded && !_controller.busy
                                  ? () => _remove(entry)
                                  : null,
                              icon: const Icon(Icons.bookmark_remove_outlined),
                              label: const Text('저장 해제'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (entries.isEmpty)
                const Notice('검색 결과가 없습니다. 시설명이나 주소를 바꿔 보세요.'),
            ],
          ],
        );
      },
    ),
  );
}
