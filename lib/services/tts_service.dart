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
  // Caches the in-flight initialization so concurrent callers (e.g. a game
  // screen's own TTS-enabled read racing GameAnnouncer.init(), which awaits
  // this same init() internally) all await the *same* completed load instead
  // of a second caller's guard tripping early and returning before _enabled
  // is actually populated (F16b, audit 2026-07-06 round 4).
  Future<void>? _initializing;
  bool _enabled = false;
  bool _speaking = false;
  // The utterance currently handed to the plugin — tracked purely so the
  // completion handler below can log which line just finished (flutter_tts'
  // completion callback carries no text of its own).
  String? _currentUtterance;
  final Queue<String> _queue = Queue<String>();
  final List<VoidCallback> _idleCallbacks = [];

  // Cap on PENDING (not-yet-speaking) utterances. A 2026-07-09 WILDCARD game
  // log showed the queue hitting 73 pending entries under rapid scoring —
  // announcements ended up minutes behind the live game. Capping means the
  // spoken audio stays close to real time; older, now-stale announcements
  // are dropped rather than eventually spoken out of context. The utterance
  // currently being spoken (already handed to the plugin, no longer in
  // [_queue]) is never touched.
  static const int _maxPendingQueue = 3;

  bool get enabled => _enabled;

  @visibleForTesting
  bool get isInitialized => _initialized;

  @visibleForTesting
  List<String> get pendingQueueForTesting => List<String>.unmodifiable(_queue);

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _initializing = null;
    _enabled = false;
    _speaking = false;
    _currentUtterance = null;
    _queue.clear();
    _idleCallbacks.clear();
  }

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initializing ??= _doInit().catchError((Object e, StackTrace st) {
      // One-shot failure — don't cache a rejected future forever, or every
      // later caller (including GameAnnouncer.init(), which awaits this
      // first and blocks SoundService/VideoService init behind it) gets the
      // same rejection for the rest of the session. Let the next call retry.
      _initializing = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  Future<void> _doInit() async {
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
      // "TTS done" is the completion counterpart to speak()'s own "TTS
      // speak" log line — a field log otherwise only shows what was
      // enqueued, never whether it was actually spoken aloud.
      GameLogger.instance.logTts(event: 'done "$_currentUtterance"');
      _speaking = false;
      _playNext();
      // Fire idle callbacks once the queue has drained
      if (!_speaking) {
        final cbs = List<VoidCallback>.from(_idleCallbacks);
        _idleCallbacks.clear();
        for (final cb in cbs) {
          cb();
        }
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

    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    GameLogger.instance.logTts(event: 'speak "$text"', queueLength: _queue.length);
    _queue.add(text);
    // Drop the OLDEST pending utterance(s) once the cap is exceeded. The
    // active (currently-speaking) utterance is never in [_queue] — it was
    // already removed by [_playNext] — so this can never cancel in-flight
    // speech, only stale backlog.
    while (_queue.length > _maxPendingQueue) {
      final dropped = _queue.removeFirst();
      GameLogger.instance.logTts(
          event: 'queue cap ($_maxPendingQueue) hit — dropping oldest pending "$dropped"',
          queueLength: _queue.length);
    }
    if (!_speaking) {
      _playNext();
    }
  }

  void _playNext() {
    if (_queue.isEmpty) return;
    _speaking = true;
    final text = _queue.removeFirst();
    _currentUtterance = text;
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
