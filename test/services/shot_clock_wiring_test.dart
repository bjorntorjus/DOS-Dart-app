import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/game_announcer.dart';
import 'package:dart_scoring/services/shot_clock.dart';

void main() {
  // GameAnnouncer's constructor reaches TtsService, which wires a
  // MethodChannel handler — that needs a binding even in a pure unit test.
  TestWidgetsFlutterBinding.ensureInitialized();

  // GameAnnouncer's constructor builds both TtsService and SoundService, and
  // each opens a platform channel with no implementation under flutter_test —
  // an unmocked call resolves AFTER the test finishes and fails it
  // retroactively. audioplayers' global scope is a process-wide singleton
  // created by the first-ever AudioPlayer, so it is mocked before any
  // announcer exists (same approach as sound_service_queue_test.dart).
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => 1);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => null);
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (args, events) {}),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true;
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  test('announcing the next player starts the clock', () {
    final announcer = GameAnnouncer();

    announcer.announceNextPlayer('Ada'); // first turn — grace
    announcer.announceNextPlayer('Bo');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Bo'), 1,
        reason: 'the announcer is the universal turn-change hook');
  });

  test('the shot-clock nudge does not itself restart the turn', () {
    final announcer = GameAnnouncer();
    announcer.announceNextPlayer('Ada'); // first turn
    announcer.announceNextPlayer('Bo');

    // What the nudge timer does when it fires.
    announcer.announceShotClock('Bo');

    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
    expect(ShotClock.instance.slowTurnsFor('Bo'), 1,
        reason: 'a nudge must not reset the very turn it is nagging about');
  });
}
