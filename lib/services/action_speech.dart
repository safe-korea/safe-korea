import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

class ActionSpeech {
  FlutterTts? _engine;
  int _generation = 0;
  Future<void> speak(String text) async {
    final generation = ++_generation;
    final tts = _engine ??= FlutterTts();
    if (Platform.isAndroid && await tts.isLanguageInstalled('ko-KR') != true) {
      throw StateError('설치된 한국어 음성 없음');
    }
    final voices = await tts.getVoices as List;
    final candidates = voices.whereType<Map>().where(
      (voice) =>
          voice['locale'].toString().replaceAll('_', '-') == 'ko-KR' &&
          (!Platform.isAndroid ||
              voice['network_required'] == false ||
              voice['network_required'] == 'false' ||
              voice['network_required'] == '0' ||
              voice['network_required'] == 0),
    );
    if (candidates.isEmpty) throw StateError('한국어 기기 음성 없음');
    final voice = candidates.first;
    final selected = await tts.setVoice({
      'name': voice['name'].toString(),
      'locale': voice['locale'].toString(),
      if (voice['identifier'] != null)
        'identifier': voice['identifier'].toString(),
    });
    if (selected != 1) throw StateError('한국어 음성 선택 실패');
    await tts.setSpeechRate(0.45);
    await tts.awaitSpeakCompletion(true);
    if (generation != _generation) return;
    final result = await tts.speak(text);
    if (result != 1 && generation == _generation) throw StateError('음성 재생 실패');
  }

  Future<void> stop() async {
    _generation++;
    try {
      await _engine?.stop();
    } catch (_) {
      /* Text remains available. */
    }
  }
}
