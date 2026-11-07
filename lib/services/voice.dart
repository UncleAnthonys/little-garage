import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Spoken guidance. Text-to-speech is the placeholder; swap [say] to play
/// recorded voice lines per part once they exist.
class Voice {
  Voice._();
  static final Voice instance = Voice._();

  final FlutterTts _tts = FlutterTts();
  bool enabled = true;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.15);
    } catch (_) {}
  }

  Future<void> say(String text) async {
    if (!enabled) return;
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Small sound and haptic cues. Uses system sounds until real effects exist.
class Sfx {
  static bool enabled = true;

  static void tap() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  static void snap() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  static void bump() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
