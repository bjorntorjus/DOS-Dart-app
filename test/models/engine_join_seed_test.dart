import 'package:dart_scoring/models/golf_engine.dart';
import 'package:dart_scoring/models/one_up_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Engine-level seeding for the three modes whose joiner state lives in the
/// engine rather than the screen (spec 2026-08-10, §7).
void main() {
  group('OneUpEngine.addPlayer', () {
    test('takes explicit initial lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.livesLeft[0] = 3;
      e.livesLeft[1] = 1;

      e.addPlayer(initialLives: 1);

      expect(e.livesLeft[2], 1);
      expect(e.playerCount, 3);
    });

    test('without initialLives still grants the starting lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.addPlayer();
      expect(e.livesLeft[2], 3);
    });

    test("a joiner gets zeroed counters, not the copied seat's", () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.livesLost[1] = 2;
      e.roundsWon[1] = 4;

      e.addPlayer(initialLives: 1);

      expect(e.livesLost[2], 0);
      expect(e.roundsWon[2], 0);
    });
  });

  group('distributeStrokes', () {
    test('an exact division gives every hole the same score', () {
      expect(distributeStrokes(15, 5), [3, 3, 3, 3, 3]);
    });

    test('a remainder is spread, and the total is exact', () {
      final row = distributeStrokes(22, 5);
      expect(row.reduce((a, b) => a + b), 22);
      expect(row.where((s) => s == 5).length, 2);
      expect(row.where((s) => s == 4).length, 3);
    });

    test('every value stays inside the legal 1-6 stroke range', () {
      for (var holes = 1; holes <= 18; holes++) {
        for (var total = holes; total <= holes * 6; total++) {
          final row = distributeStrokes(total, holes);
          expect(row.reduce((a, b) => a + b), total,
              reason: 'total=$total holes=$holes');
          expect(row.every((s) => s >= 1 && s <= 6), isTrue,
              reason: 'total=$total holes=$holes produced $row');
        }
      }
    });

    test('zero holes yields an empty row', () {
      expect(distributeStrokes(0, 0), isEmpty);
    });
  });

  group('GolfEngine.addPlayer', () {
    test('a seeded joiner matches the last-placed total exactly', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      // Play 5 holes: seat 0 is sharp, seat 1 is the worst.
      for (var h = 0; h < 5; h++) {
        e.scorecards[0][h] = 3;
        e.scorecards[1][h] = h == 0 ? 6 : 4;
      }
      e.currentHole = 5;

      e.addPlayer(seedTotal: e.total(1));

      expect(e.total(2), e.total(1));
      expect(e.scorecards[2].sublist(5).every((s) => s == null), isTrue,
          reason: 'unplayed holes stay empty');
    });

    test('without seedTotal still backfills PAR', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      e.currentHole = 4;
      e.addPlayer();
      expect(e.scorecards[2].sublist(0, 4), [3, 3, 3, 3]);
    });

    test('a joiner at hole 1 gets an empty card, not a seeded one', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      e.addPlayer(seedTotal: 0);
      expect(e.total(2), 0);
      expect(e.scorecards[2].every((s) => s == null), isTrue);
    });
  });
}
