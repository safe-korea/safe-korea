import 'package:flutter/material.dart';

import '../models/shelter.dart';
import '../services/shelter_street_view.dart';

class ShelterStreetViewButton extends StatefulWidget {
  const ShelterStreetViewButton({
    super.key,
    required this.shelter,
    this.service,
    this.previousLocation = false,
  });
  final Shelter shelter;
  final ShelterStreetView? service;
  final bool previousLocation;
  @override
  State<ShelterStreetViewButton> createState() =>
      _ShelterStreetViewButtonState();
}

class _ShelterStreetViewButtonState extends State<ShelterStreetViewButton> {
  bool _busy = false;
  String? _error;
  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened = await (widget.service ?? ShelterStreetView()).open(
        widget.shelter,
      );
      if (!opened && mounted) {
        setState(() => _error = '로드뷰를 열지 못했어요. 인터넷 연결을 확인한 뒤 다시 눌러 주세요.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '시설 좌표를 확인하지 못했어요. 주소와 공식 자료를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _open,
        icon: const Icon(Icons.streetview_outlined),
        label: Text(_busy ? '로드뷰 여는 중…' : '주변 실제 모습 보기'),
      ),
      const SizedBox(height: 4),
      Text(
        widget.previousLocation
            ? '이전 저장 위치 기준 · 카카오 로드뷰 · 온라인'
            : '카카오 로드뷰 · 온라인',
        style: const TextStyle(fontSize: 13),
      ),
      const Text(
        '주변 거리 사진이며, 실제 출입구와 다를 수 있어요.',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      const Text(
        '설치 안내에서는 ‘설치없이 지도보기’를 선택하세요.',
        style: TextStyle(fontSize: 13),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('사진 이용 안내', style: TextStyle(fontSize: 14)),
        children: const [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '시설 좌표·IP가 카카오에 전달됩니다. 현재 GPS는 보내지 않아요.\n촬영일은 로드뷰에서 확인하세요. 촬영된 거리 사진이 없을 수 있으며 출입구·개방 상태는 현장에서 확인해야 해요.\n로드뷰 사진은 저장하지 않아 오프라인에서는 볼 수 없어요.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
      if (_error != null)
        Semantics(
          liveRegion: true,
          child: Text(_error!, style: const TextStyle(fontSize: 14)),
        ),
    ],
  );
}
