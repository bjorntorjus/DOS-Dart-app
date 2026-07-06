import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';

/// F11 (audit 2026-07-06): "best finish" is FEWEST darts, so it needs a min
/// counter. setMax kept the worst finish forever.
void main() {
  group('ModeStats.setMin', () {
    test('a zero/unset counter takes the first real value', () {
      final ms = ModeStats(played: 1);
      ms.setMin('bestDartCount', 30);
      expect(ms.get('bestDartCount'), 30);
    });

    test('keeps the smaller value and ignores larger ones', () {
      final ms = ModeStats(played: 3);
      ms.setMin('bestDartCount', 30);
      ms.setMin('bestDartCount', 45); // worse finish — must not overwrite
      expect(ms.get('bestDartCount'), 30);
      ms.setMin('bestDartCount', 22); // new PB
      expect(ms.get('bestDartCount'), 22);
    });

    test('an inflated legacy value self-heals on the next better finish', () {
      // Simulates old data written by the buggy setMax path (worst finish).
      final ms = ModeStats(played: 5, counters: {'bestDartCount': 60});
      ms.setMin('bestDartCount', 28);
      expect(ms.get('bestDartCount'), 28);
    });
  });
}
