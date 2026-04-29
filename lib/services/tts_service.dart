import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'app_settings.dart';
import 'game_logger.dart';

class TtsService {
  static final TtsService _instance = TtsService._();
  static TtsService get instance => _instance;

  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = false;
  bool _speaking = false;
  final Queue<String> _queue = Queue<String>();
  final List<VoidCallback> _idleCallbacks = [];

  bool get enabled => _enabled;

  @visibleForTesting
  bool get isInitialized => _initialized;

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _enabled = false;
    _speaking = false;
    _queue.clear();
    _idleCallbacks.clear();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _enabled = await AppSettings.getTtsEnabled();
    final language = await AppSettings.getTtsLanguage();
    final voiceName = await AppSettings.getTtsVoice();

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Restore saved voice if set
    if (voiceName.isNotEmpty) {
      final voices = await getVoices();
      final match = voices.where((v) => v['name'] == voiceName);
      if (match.isNotEmpty) {
        await _tts.setVoice(match.first);
      }
    }

    _tts.setCompletionHandler(() {
      _speaking = false;
      _playNext();
      // Fire idle callbacks once the queue has drained
      if (!_speaking) {
        final cbs = List<VoidCallback>.from(_idleCallbacks);
        _idleCallbacks.clear();
        for (final cb in cbs) cb();
      }
    });

    _tts.setCancelHandler(() {
      _speaking = false;
      _queue.clear();
      _idleCallbacks.clear();
    });

    _tts.setErrorHandler((msg) {
      _speaking = false;
      _playNext();
    });
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    GameLogger.instance.logTts(event: 'speak "$text"', queueLength: _queue.length);
    _queue.add(text);
    if (!_speaking) {
      _playNext();
    }
  }

  void _playNext() {
    if (_queue.isEmpty) return;
    _speaking = true;
    final text = _queue.removeFirst();
    _tts.speak(text);
  }

  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
    await AppSettings.setTtsLanguage(language);
    // Clear saved voice when language changes
    await AppSettings.setTtsVoice('');
  }

  Future<List<Map<String, String>>> getVoices() async {
    final voices = await _tts.getVoices;
    final list = (voices as List)
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
    list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return list;
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
    await AppSettings.setTtsVoice(voice['name'] ?? '');
  }

  Future<void> setEnabled(bool value) async {
    if (!_initialized) await init();
    _enabled = value;
    await AppSettings.setTtsEnabled(value);
    if (!value) await stop();
  }

  Future<List<String>> getLanguages() async {
    final languages = await _tts.getLanguages;
    final list = (languages as List).map((l) => l.toString()).toList();
    list.sort();
    return list;
  }

  /// Schedule [cb] to run as soon as TTS is idle (queue empty, not speaking).
  /// If already idle, fires immediately.
  void callWhenIdle(VoidCallback cb) {
    if (!_speaking && _queue.isEmpty) {
      GameLogger.instance.logTts(event: 'callWhenIdle → firing immediately (idle)', queueLength: 0);
      cb();
    } else {
      GameLogger.instance.logTts(event: 'callWhenIdle → deferred (speaking=$_speaking)', queueLength: _queue.length);
      _idleCallbacks.add(cb);
    }
  }

  Future<void> stop() async {
    _queue.clear();
    _idleCallbacks.clear();
    _speaking = false;
    await _tts.stop();
  }
}
