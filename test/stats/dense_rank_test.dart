import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/stats/dense_rank.dart';

/// Spec 2026-08-26: Family-A screens give a removed seat a REAL rank, so the
/// placements that survive exclusion can start at 2 or skip a number. The
/// active seats must be renumbered densely before they are persisted.
void main() {
  group('denseRankActive', () {
    test('closes the gap a removed seat leaves at the top', () {
      expect(denseRankActive([2, 3, 1], {2}), [1, 2, 1]);
    });

    test('preserves ties among the active seats', () {
      expect(denseRankActive([1, 1, 3, 2], {3}), [1, 1, 2, 2]);
    });

    test('an empty exclusion set is the identity', () {
      expect(denseRankActive([1, 2, 3], const {}), [1, 2, 3]);
      expect(denseRankActive([1, 1, 3], const {}), [1, 1, 3],
          reason: 'a game with no roster change keeps its competition-style '
              'ties exactly as the screen built them');
    });

    test('leaves the excluded seats own values alone', () {
      final out = denseRankActive([1, 2, 3], {0});
      expect(out[0], 1, reason: 'excluded seat untouched');
      expect(out.sublist(1), [1, 2], reason: 'active seats renumbered from 1');
    });

    test('handles several excluded seats and a gap in the middle', () {
      // Seats 0 and 3 removed; active seats 1, 2, 4 hold 2, 4, 5.
      expect(denseRankActive([1, 2, 4, 3, 5], {0, 3}), [1, 1, 2, 3, 3]);
    });

    test('every seat excluded returns the input unchanged', () {
      expect(denseRankActive([3, 1, 2], {0, 1, 2}), [3, 1, 2]);
    });

    test('does not mutate the input list', () {
      final input = [2, 3, 1];
      denseRankActive(input, {2});
      expect(input, [2, 3, 1]);
    });
  });
}
