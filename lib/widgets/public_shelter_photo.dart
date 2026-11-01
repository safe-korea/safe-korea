import 'package:flutter/material.dart';

import '../models/public_shelter_photo.dart';
import 'common.dart';

class PublicShelterPhotoCard extends StatelessWidget {
  const PublicShelterPhotoCard({super.key, required this.photo});
  final PublicShelterPhoto photo;
  Widget _image() => Image.asset(
    photo.asset,
    fit: BoxFit.contain,
    semanticLabel: '${photo.title}. ${photo.takenOn} 촬영. 대피 출입구 사진 아님.',
    errorBuilder: (_, _, _) => const Padding(
      padding: EdgeInsets.all(16),
      child: Text('공개 사진을 읽지 못했어요. 아래 로드뷰에서 주변을 확인하세요.'),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '공개된 건물 사진',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      const SizedBox(height: 8),
      _image(),
      const SizedBox(height: 8),
      Text(
        photo.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      Text(
        '촬영 ${photo.takenOn} · 대피 출입구 사진 아님',
        style: const TextStyle(fontSize: 14),
      ),
      const Text('현재 개방 여부는 현장에서 확인하세요.', style: TextStyle(fontSize: 14)),
      TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('공개 건물 사진 · 출입구 아님')),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: InteractiveViewer(maxScale: 4, child: _image()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${photo.author} · CC BY-SA 4.0\n촬영 ${photo.takenOn} · Wikimedia Commons',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.zoom_in),
        label: const Text('공개 사진 크게 보기'),
      ),
      Text(
        '${photo.author} · CC BY-SA 4.0\nWikimedia Commons · 축소본, 추가 편집 없음',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => openExternal(context, Uri.parse(photo.sourceUrl)),
            child: const Text('사진 원문'),
          ),
          TextButton(
            onPressed: () => openExternal(context, Uri.parse(photo.licenseUrl)),
            child: const Text('사진 이용 조건'),
          ),
        ],
      ),
    ],
  );
}
