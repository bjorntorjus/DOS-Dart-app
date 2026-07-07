// test/services/game_announcer_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/services/game_announcer.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F16 (audit 2026-07-06): the per-category TTS settings must gate every
/// announcement path. GameAnnouncer had zero tests before this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  const audioplayersGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioplayersChannel = MethodChannel('xyz.luan/audioplayers');
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') spoken.add(call.arguments as String);
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersGlobalChannel, (call) async {
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersChannel, (call) async {
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersChannel, null);
    TtsService.instance.resetForTesting();
  });

  Future<GameAnnouncer> makeAnnouncer(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues({'tts_enabled': true, ...prefs});
    final announcer = GameAnnouncer();
    await announcer.init();
    return announcer;
  }

  test('announceNextPlayer speaks when the category is on', () async {
    final a = await makeAnnouncer({});
    a.announceNextPlayer('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, contains('Alice'));
  });

  test('announceNextPlayer is silent when the category is off', () async {
    final a = await makeAnnouncer({'tts_announce_next_player': false});
    a.announceNextPlayer('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });

  test('announceThrow respects tts_announce_throw_result', () async {
    final a = await makeAnnouncer({'tts_announce_throw_result': false});
    a.announceThrow('triple 20');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });

  test('announceWinner speaks "<name> wins!" when winner category is on', () async {
    final a = await makeAnnouncer({});
    a.announceWinner('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, contains('Alice wins!'));
  });

  test('announceGameEvent respects tts_announce_game_events', () async {
    final a = await makeAnnouncer({'tts_announce_game_events': false});
    a.announceGameEvent('Instant Shanghai!');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });
}
