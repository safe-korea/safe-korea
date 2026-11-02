import 'dart:async';

import 'package:flutter/material.dart';

import '../services/action_speech.dart';

class ActionSpeechButton extends StatefulWidget {
  const ActionSpeechButton({super.key, required this.text, this.speech});
  final String text;
  final ActionSpeech? speech;
  @override
  State<ActionSpeechButton> createState() => _ActionSpeechButtonState();
}

class _ActionSpeechButtonState extends State<ActionSpeechButton>
    with WidgetsBindingObserver {
  late final _speech = widget.speech ?? ActionSpeech();
  bool _playing = false;
  int _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _stop() {
    _generation++;
    unawaited(_speech.stop());
    _playing = false;
  }

  @override
  void didUpdateWidget(ActionSpeechButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stop();
      _error = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) setState(_stop);
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      setState(_stop);
      return;
    }
    final generation = ++_generation;
    setState(() {
      _playing = true;
      _error = null;
    });
    try {
      await _speech.speak(widget.text);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '기기의 한국어 음성을 사용할 수 없어요. 화면 안내를 읽어 주세요.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _playing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _toggle,
        icon: Icon(
          _playing ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
        ),
        label: Text(_playing ? '읽기 중지' : '행동요령 읽어주기'),
      ),
      if (_error != null)
        Semantics(
          liveRegion: true,
          child: Text(_error!, style: const TextStyle(fontSize: 14)),
        ),
    ],
  );
}
