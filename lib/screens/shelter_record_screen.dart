import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/saved_shelter.dart';
import '../services/saved_shelters_controller.dart';
import '../services/shelter_photo_importer.dart';
import '../widgets/common.dart';

Future<bool> confirmPersonalRecordRemoval(
  BuildContext context,
  SavedShelter entry,
) async {
  if (entry.photos.isEmpty &&
      entry.entranceNote.isEmpty &&
      entry.role == ShelterRole.none) {
    return true;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('대피소 저장을 해제할까요?'),
          content: const Text('앱에 저장한 사진·메모·우선순위도 삭제됩니다. 사진 보관함 원본은 유지됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('유지하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장 해제'),
            ),
          ],
        ),
      ) ??
      false;
}

class ShelterRecordScreen extends StatefulWidget {
  const ShelterRecordScreen({
    super.key,
    required this.entry,
    required this.controller,
    this.importer,
  });
  final SavedShelter entry;
  final SavedSheltersController controller;
  final ShelterPhotoImporter? importer;
  @override
  State<ShelterRecordScreen> createState() => _ShelterRecordScreenState();
}

class _ShelterRecordScreenState extends State<ShelterRecordScreen> {
  late final _note = TextEditingController(text: widget.entry.entranceNote);
  late final _importer = widget.importer ?? ShelterPhotoImporter();
  late ShelterRole _role = widget.entry.role;
  late final _photos = [...widget.entry.photos];
  bool _busy = false, _dirty = false;
  String? _message;
  ShelterPhoto? _recovered;

  @override
  void initState() {
    super.initState();
    _recover();
  }

  Future<void> _recover() async {
    try {
      final photo = await _importer.recover();
      if (mounted) setState(() => _recovered = photo);
    } catch (_) {
      // Never attach interrupted selections silently to a different shelter.
      if (mounted) setState(() => _message = '중단된 사진 선택은 다시 시도해 주세요.');
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final photo = await _importer.pick();
      if (mounted && photo != null) {
        setState(() {
          _photos.add(photo);
          _dirty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = '사진을 가져오지 못했습니다. 접근 권한이나 파일을 확인하고 다시 선택해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final success = await widget.controller.savePersonal(
      widget.entry.key,
      _role,
      _note.text,
      _photos,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = !success;
      _message = success
          ? '기기에 저장했습니다.'
          : '저장하지 못했습니다. 입력한 기록을 유지했습니다. 다시 시도하세요.';
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장하지 않고 나갈까요?'),
        content: const Text('저장하지 않은 사진·메모는 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장하지 않고 나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _confirmLeave();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('출입구 사진·메모')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_busy ? '처리 중…' : '기기에 저장'),
          ),
        ),
      ),
      body: PageBody(
        children: [
          Text(
            widget.entry.shelter.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('개인 기록 · 공식 사진 아님\n대피 중에는 촬영보다 이동을 우선하세요.'),
          const SizedBox(height: 20),
          DropdownButtonFormField<ShelterRole>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '대피소 우선순위'),
            items: [
              for (final role in ShelterRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: _busy
                ? null
                : (role) => setState(() {
                    _role = role!;
                    _dirty = true;
                  }),
          ),
          const SizedBox(height: 8),
          const Text(
            '각각 한 곳만 지정해요. 기존 지정은 해제돼요.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            enabled: !_busy,
            maxLength: 300,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '출입구 찾는 방법',
              hintText: '예: 건물 뒤편, 파란 출입문 옆 지하 계단',
            ),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          Text(
            '내 사진 ${_photos.length}/3',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '기기에만 복사해요. 오프라인에서도 볼 수 있어요.',
            style: TextStyle(fontSize: 14),
          ),
          if (_recovered != null && _photos.length < 3) ...[
            const SizedBox(height: 12),
            const Notice('이전에 중단된 사진 선택이 있습니다. 현재 시설의 사진인지 확인한 뒤 저장하세요.'),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _photos.add(_recovered!);
                      _recovered = null;
                      _dirty = true;
                    }),
              child: const Text('중단된 사진 미리보기 추가'),
            ),
          ],
          for (var i = 0; i < _photos.length; i++) ...[
            const SizedBox(height: 16),
            PersonalShelterPhoto(photo: _photos[i], index: i + 1),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _photos.removeAt(i);
                      _dirty = true;
                    }),
              icon: const Icon(Icons.delete_outline),
              label: Text('사진 ${i + 1} 삭제'),
            ),
          ],
          if (_photos.length < 3) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('사진 보관함에서 선택'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Notice(_message!)),
          ],
          const SizedBox(height: 12),
          const Text(
            '앱 삭제·저장 해제 시 개인 기록도 삭제됩니다. 원본 사진은 삭제되지 않습니다.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class PersonalShelterPhoto extends StatelessWidget {
  const PersonalShelterPhoto({
    super.key,
    required this.photo,
    required this.index,
  });
  final ShelterPhoto photo;
  final int index;
  Widget _image({bool full = false}) {
    try {
      return Image.memory(
        base64Decode(photo.data),
        fit: BoxFit.contain,
        semanticLabel: '직접 저장한 대피소 사진 $index. 공식 사진 아님',
        cacheWidth: full ? null : 800,
        errorBuilder: (_, _, _) =>
            const Center(child: Text('사진을 읽지 못했습니다. 다시 추가해 주세요.')),
      );
    } catch (_) {
      return const Center(child: Text('사진을 읽지 못했습니다. 다시 추가해 주세요.'));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFE8EEEB),
          child: SizedBox(height: 200, child: _image()),
        ),
      ),
      TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('개인 사진 $index · 확대')),
              body: SafeArea(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: _image(full: true),
                  ),
                ),
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.zoom_in),
        label: Text('사진 $index 크게 보기'),
      ),
      Text(
        '개인 기록 · 추가 ${photo.addedAt.toLocal().toIso8601String().substring(0, 10)}',
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
}
