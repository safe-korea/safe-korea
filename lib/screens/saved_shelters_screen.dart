import 'offline_map_screen.dart';

import 'package:flutter/material.dart';

import '../models/saved_shelter.dart';
import '../theme/app_theme.dart';
import '../services/saved_shelters_controller.dart';
import '../services/shelter_repository.dart';
import '../widgets/common.dart';
import '../models/public_shelter_photo.dart';
import '../widgets/public_shelter_photo.dart';
import '../widgets/shelter_street_view_button.dart';
import '../widgets/shelter_map.dart';
import 'shelters_screen.dart';
import 'shelter_record_screen.dart';

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
    if (!await confirmPersonalRecordRemoval(context, entry) || !mounted) return;
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
            const Text(
              '저장한 약도·사진·주소는 오프라인으로 볼 수 있어요.\n온라인 지도와 재조회에는 인터넷이 필요해요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_refreshMessage != null)
              Semantics(liveRegion: true, child: Notice(_refreshMessage!)),
            if (_controller.loading)
              const Center(child: CircularProgressIndicator()),
            if (_controller.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Notice(_controller.error!, warning: true),
              ),
              OutlinedButton(
                onPressed: _controller.loading || _controller.busy
                    ? null
                    : _controller.load,
                child: const Text('저장 목록 다시 읽기'),
              ),
            ],
            if (_controller.loaded && _controller.entries.isEmpty) ...[
              const IconTextBlock(
                icon: Icons.bookmark_border,
                title: '저장한 대피소가 아직 없어요.',
                body: Text('대피소 상세에서 저장을 눌러 두세요.'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SheltersScreen(savedShelters: _controller),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text('대피소 찾아서 저장하기'),
              ),
            ],
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
              for (final entry in entries) _entryCard(entry),
              if (entries.isEmpty)
                const Notice('검색 결과가 없습니다. 시설명이나 주소를 바꿔 보세요.'),
            ],
          ],
        );
      },
    ),
  );

  Widget _status(SavedShelter entry) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppPalette.cautionBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 22, color: AppPalette.caution),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.check == ShelterCheck.notFound ||
                    entry.check == ShelterCheck.incomplete
                ? _checkLabel(entry)
                : '개방 여부는 현장에서 확인하세요',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _identity(SavedShelter entry) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.bookmark, size: 18, color: teal),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.snapshot.coverage,
              style: const TextStyle(fontSize: 14, color: teal),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        entry.shelter.name,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(
        entry.shelter.address,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
      const SizedBox(height: 12),
      _status(entry),
    ],
  );

  Widget _entryCard(SavedShelter entry) => Card(
    key: ValueKey(entry.key),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.role != ShelterRole.none) ...[
            Text(
              entry.role.label,
              style: const TextStyle(color: teal, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          _identity(entry),
          OfflineMapLink(shelter: entry.shelter),
          if (entry.entranceNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            IconTextBlock(
              icon: Icons.door_front_door_outlined,
              title: '출입구 메모 · 개인 기록',
              body: Text(entry.entranceNote),
            ),
          ],
          for (var i = 0; i < entry.photos.length; i++)
            if (entry.photos[i].isReferenceMap) ...[
              const SizedBox(height: 16),
              PersonalShelterPhoto(photo: entry.photos[i], index: i + 1),
            ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openMap(entry),
            icon: const Icon(Icons.map_outlined),
            label: const Text('온라인 지도 보기'),
          ),
          const SizedBox(height: 6),
          const Text(
            '지도 이용 시 조회 범위·IP가 지도 제공자에게 전달됩니다.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          if (entry.check != ShelterCheck.notFound &&
              entry.check != ShelterCheck.incomplete &&
              PublicShelterPhoto.match(entry.snapshot, entry.shelter) !=
                  null) ...[
            const SizedBox(height: 16),
            PublicShelterPhotoCard(
              photo: PublicShelterPhoto.match(entry.snapshot, entry.shelter)!,
            ),
          ],
          const SizedBox(height: 12),
          ShelterStreetViewButton(
            shelter: entry.shelter,
            previousLocation:
                entry.check == ShelterCheck.notFound ||
                entry.check == ShelterCheck.incomplete,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: const Text('내 기록 · 선택'),
            children: [
              if (entry.photos.isNotEmpty &&
                  !entry.photos.first.isReferenceMap) ...[
                const SizedBox(height: 16),
                PersonalShelterPhoto(photo: entry.photos.first, index: 1),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    _controller.loaded &&
                        !_controller.busy &&
                        !_controller.loading
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ShelterRecordScreen(
                            entry: entry,
                            controller: _controller,
                          ),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  entry.photos.isEmpty && entry.entranceNote.isEmpty
                      ? '사진·약도·메모 추가'
                      : '사진·약도 ${entry.photos.length}장 관리',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: const Text('조회·저장 정보', style: TextStyle(fontSize: 16)),
            children: [
              InfoLine(label: '자료 상태', value: _checkLabel(entry)),
              InfoLine(
                label: '공식 자료 조회',
                value: _time(entry.snapshot.retrievedAt),
              ),
              InfoLine(
                label: '기기 저장',
                value: _time(entry.savedAt.toIso8601String()),
              ),
              if (entry.checkedAt != null)
                InfoLine(
                  label: '최근 재확인',
                  value: _time(entry.checkedAt!.toIso8601String()),
                ),
              const SizedBox(height: 8),
              const Text(
                '수용 여유·이동 경로 안전은 확인되지 않았습니다.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed:
                    _controller.loaded &&
                        !_controller.busy &&
                        !_controller.loading
                    ? () => _refresh(entry)
                    : null,
                icon: const Icon(Icons.refresh),
                label: Text(_controller.busy ? '저장 목록 처리 중…' : '공식 자료 다시 확인'),
              ),
              const SizedBox(height: 6),
              const Text(
                '재조회 시 지역 코드·IP를 국민안전24에 전달합니다.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    openExternal(context, Uri.parse(entry.snapshot.sourceUrl)),
                icon: const Icon(Icons.open_in_new),
                label: const Text('공식 출처 열기'),
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
  );

  void _openMap(SavedShelter entry) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (mapContext) => Scaffold(
        appBar: AppBar(
          title: Text(
            entry.check == ShelterCheck.notFound ||
                    entry.check == ShelterCheck.incomplete
                ? '이전 저장 정보 지도'
                : '저장한 대피소 지도',
          ),
        ),
        body: SafeArea(
          child: ShelterMap(
            shelters: [entry.shelter],
            onSelected: (_) => showModalBottomSheet<void>(
              context: mapContext,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _identity(entry),
                      OfflineMapLink(shelter: entry.shelter),
                      const SizedBox(height: 12),
                      ShelterStreetViewButton(
                        shelter: entry.shelter,
                        previousLocation:
                            entry.check == ShelterCheck.notFound ||
                            entry.check == ShelterCheck.incomplete,
                      ),
                      const SizedBox(height: 16),
                      InfoLine(
                        label: '공식 자료 조회',
                        value: _time(entry.snapshot.retrievedAt),
                      ),
                      InfoLine(label: '자료 상태', value: _checkLabel(entry)),
                      const Text(
                        '수용 여유·이동 경로 안전 미확인',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
