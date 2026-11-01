import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../models/saved_shelter.dart';

/// Explicit photo selection only. Re-encoding removes EXIF/location metadata.
class ShelterPhotoImporter {
  Future<ShelterPhoto?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      requestFullMetadata: false,
    );
    return file == null ? null : decode(file);
  }

  Future<ShelterPhoto?> recover() async {
    if (!Platform.isAndroid) return null;
    final result = await ImagePicker().retrieveLostData();
    final files = result.files;
    return files == null || files.isEmpty ? null : decode(files.first);
  }

  Future<ShelterPhoto> decode(XFile file) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('사진이 너무 큽니다. 작은 사진을 선택해 주세요.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) {
        final scale = 1280 / (w > h ? w : h);
        return ui.TargetImageSize(
          width: scale < 1 ? (w * scale).round() : w,
          height: scale < 1 ? (h * scale).round() : h,
        );
      },
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (bytes == null || bytes.lengthInBytes > 6 * 1024 * 1024) {
          throw const FormatException('사진을 줄이지 못했습니다. 다른 사진을 선택해 주세요.');
        }
        return ShelterPhoto(
          data: base64Encode(bytes.buffer.asUint8List()),
          addedAt: DateTime.now().toUtc(),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
