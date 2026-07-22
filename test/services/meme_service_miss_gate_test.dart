import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/meme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Constructing MemeService touches SoundService.instance, whose real
    // AudioPlayer initializes the audioplayers global scope + per-player
    // channels — mock them (same seam as sound_service_queue_test).
    // Playback itself stays off via flutter_test_config's disableForTest.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => null);
    messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'),
        MockStreamHandler.inline(onListen: (args, events) {}));
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async => null);
    messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers/events/sound_service'),
        MockStreamHandler.inline(onListen: (args, events) {}));
  });

  MemeService freshService({int frequency = 5}) {
    final m = MemeService();
    m.setEnabled(true);
    m.setFrequency(frequency);
    return m;
  }

  group('MemeService.tryMissSound per-turn gate', () {
    test('returns false when memes are disabled', () {
      final m = freshService();
      m.setEnabled(false);
      expect(m.tryMissSound(), isFalse);
    });

    test('is gated off for the rest of the turn once a sound played', () {
      final m = freshService(frequency: 5);
      m.markSoundPlayed();
      // Deterministic: the gate short-circuits before any dice roll.
      for (var i = 0; i < 50; i++) {
        expect(m.tryMissSound(), isFalse);
      }
    });

    test('resetTurn reopens the gate', () {
      final m = freshService(frequency: 10); // chance 1/1 → always hits
      m.markSoundPlayed();
      m.resetTurn();
      expect(m.tryMissSound(), isTrue);
    });

    test('onTurnEnd reopens the gate', () {
      final m = freshService(frequency: 10);
      m.markSoundPlayed();
      m.onTurnEnd();
      expect(m.tryMissSound(), isTrue);
    });

    test('frequency 10 ("always") bypasses the gate entirely', () {
      final m = freshService(frequency: 10);
      m.markSoundPlayed();
      expect(m.tryMissSound(), isTrue);
    });

    test('the dice roll happens at most once per turn even when it misses',
        () {
      // Meme-damping 2026-07-22: three misses in a turn used to mean three
      // independent rolls (log showed 3 meme sounds inside one second).
      final m = freshService(frequency: 1); // 1/8 chance — usually misses
      m.tryMissSound(); // first roll of the turn, any outcome
      for (var i = 0; i < 50; i++) {
        expect(m.tryMissSound(), isFalse,
            reason: 'no further rolls this turn after the first');
      }
      final m10 = freshService(frequency: 10);
      m10.tryMissSound();
      expect(m10.tryMissSound(), isTrue,
          reason: 'frequency 10 ("always") bypasses the roll-once gate too');
    });

    test('onTurnEnd reopens the roll-once gate', () {
      final m = freshService(frequency: 10);
      m.setFrequency(1);
      m.tryMissSound(); // consumes the turn's roll
      m.onTurnEnd();
      m.setFrequency(10); // always → deterministic
      expect(m.tryMissSound(), isTrue);
    });

    test('a successful roll closes the gate for the rest of the turn', () {
      final m = freshService(frequency: 5); // 1/3 chance per roll
      // Each turn gets one roll — reset between attempts (bounded so a
      // broken implementation fails the test instead of hanging).
      var played = false;
      for (var i = 0; i < 1000 && !played; i++) {
        played = m.tryMissSound();
        if (!played) m.resetTurn();
      }
      expect(played, isTrue,
          reason: 'the per-turn roll should hit within 1000 turns');
      // From now on, every further miss this turn stays silent.
      for (var i = 0; i < 50; i++) {
        expect(m.tryMissSound(), isFalse);
      }
      // Next turn: open again (dice may miss, but the roll is available —
      // frequency 10 makes it deterministic).
      m.resetTurn();
      m.setFrequency(10);
      expect(m.tryMissSound(), isTrue);
    });
  });
}
