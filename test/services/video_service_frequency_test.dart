import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Video-damping 2026-07-22: every call site showed its video 100% of the
/// time (winner after every game). VideoService now rolls a global dice from
/// the video-frequency setting; these tests pin the decision seam.
class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final int value; // what nextInt returns: 0 = dice hit, >0 = dice miss
  @override
  int nextInt(int max) => value < max ? value : max - 1;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('VideoService.frequencyToChance', () {
    test('maps the 1-10 scale like the meme dice', () {
      expect(VideoService.frequencyToChance(10), 1); // always
      expect(VideoService.frequencyToChance(8), 2);
      expect(VideoService.frequencyToChance(6), 3);
      expect(VideoService.frequencyToChance(5), 4); // default
      expect(VideoService.frequencyToChance(2), 6);
      expect(VideoService.frequencyToChance(1), 8);
    });
  });

  group('VideoService.shouldPlay', () {
    VideoService fresh({required int frequency, required int roll}) {
      final v = VideoService.instance;
      v.setEnabled(true);
      v.setFrequency(frequency);
      v.random = _FixedRandom(roll);
      return v;
    }

    test('disabled service never plays', () {
      final v = fresh(frequency: 10, roll: 0);
      v.setEnabled(false);
      expect(v.shouldPlay(), isFalse);
    });

    test('frequency 10 always plays, regardless of the dice', () {
      final v = fresh(frequency: 10, roll: 5);
      expect(v.shouldPlay(), isTrue);
    });

    test('a winning dice roll plays', () {
      final v = fresh(frequency: 5, roll: 0);
      expect(v.shouldPlay(), isTrue);
    });

    test('a losing dice roll skips', () {
      final v = fresh(frequency: 5, roll: 1);
      expect(v.shouldPlay(), isFalse);
    });

    test('per-call chance still applies on top at frequency 10', () {
      // Event call sites may pass their own chance; frequency 10 bypasses
      // only the GLOBAL dice, not an explicit per-call one.
      final v = fresh(frequency: 10, roll: 1);
      expect(v.shouldPlay(chance: 3), isFalse);
      v.random = _FixedRandom(0);
      expect(v.shouldPlay(chance: 3), isTrue);
    });
  });
}
