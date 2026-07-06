import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/game_detail_stats.dart';

void main() {
  test('X01 per-player grid derives avg/best/180/darts', () {
    // One 180 turn (T20 x3), then a 100 turn.
    final throws = <DartThrow>[
      for (var d = 0; d < 3; d++)
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: d, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      // A 100 turn with exactly one double: D20 (40) + T20 (60) + miss (0).
      DartThrow(playerIndex: 0, segment: 20, multiplier: 2, points: 40,
          scoreBefore: 321, turnNumber: 0, scoreAtStartOfTurn: 321,
          turnId: 2, roundNumber: 2),
      DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
          scoreBefore: 281, turnNumber: 1, scoreAtStartOfTurn: 321,
          turnId: 2, roundNumber: 2),
      DartThrow(playerIndex: 0, segment: 0, multiplier: 0, points: 0,
          scoreBefore: 221, turnNumber: 2, scoreAtStartOfTurn: 321,
          turnId: 2, roundNumber: 2),
    ];
    final g = x01GridStats(throws, playerIndex: 0);
    expect(g.n180, 1);
    expect(g.bestTurn, 180);
    expect(g.darts, 6);
    expect(g.avg3, closeTo(140.0, 0.1)); // (180+100)/2 turns
    expect(g.doublesHit, 1);
  });

  test('busted turns are excluded from turn-based stats', () {
    final throws = <DartThrow>[
      for (var d = 0; d < 3; d++)
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: d, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      // A busted turn: should not count toward avg/best.
      DartThrow(playerIndex: 0, segment: 20, multiplier: 1, points: 20,
          scoreBefore: 18, turnNumber: 0, scoreAtStartOfTurn: 18,
          turnId: 2, roundNumber: 2, isBust: true),
    ];
    final g = x01GridStats(throws, playerIndex: 0);
    expect(g.bestTurn, 180);
    expect(g.avg3, closeTo(180.0, 0.1)); // only the 180 turn counts
  });

  group('x01TurnTotals', () {
    test('groups by turnId, not scoreAtStartOfTurn', () {
      // Two distinct turns that share the SAME scoreAtStartOfTurn (101) — this
      // is exactly what happens after a bust reverts the score: the next turn
      // restarts from the same value. Grouping by scoreAtStartOfTurn would
      // merge them into a single 6-dart "turn" of 200+ points; grouping by
      // turnId keeps them separate.
      final throws = <DartThrow>[
        for (var d = 0; d < 3; d++)
          DartThrow(playerIndex: 0, segment: 20, multiplier: 2, points: 40,
              scoreBefore: 101, turnNumber: d, scoreAtStartOfTurn: 101,
              turnId: 1, roundNumber: 1),
        for (var d = 0; d < 3; d++)
          DartThrow(playerIndex: 0, segment: 20, multiplier: 1, points: 20,
              scoreBefore: 101, turnNumber: d, scoreAtStartOfTurn: 101,
              turnId: 2, roundNumber: 2),
      ];
      expect(x01TurnTotals(throws, playerIndex: 0), [120, 60]);
    });

    test('a bust followed by a turn at the same score never exceeds 180', () {
      // Reproduces the reported "190" record. Turn 1 busts (T20 → overshoot)
      // and reverts to 50; turn 2 restarts from 50 and scores 130. Grouping by
      // scoreAtStartOfTurn merged these into T20+T20+T20+S10 = 190.
      final throws = <DartThrow>[
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 50, turnNumber: 0, scoreAtStartOfTurn: 50,
            turnId: 1, roundNumber: 1, isBust: true),
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 50, turnNumber: 0, scoreAtStartOfTurn: 50,
            turnId: 2, roundNumber: 2),
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 50, turnNumber: 1, scoreAtStartOfTurn: 50,
            turnId: 2, roundNumber: 2),
        DartThrow(playerIndex: 0, segment: 10, multiplier: 1, points: 10,
            scoreBefore: 50, turnNumber: 2, scoreAtStartOfTurn: 50,
            turnId: 2, roundNumber: 2),
      ];
      final totals = x01TurnTotals(throws, playerIndex: 0);
      expect(totals, [130]); // busted turn excluded, no merge
      expect(totals.every((t) => t <= 180), isTrue);
    });

    test('returns one entry per non-busted turn, only for the given player', () {
      final throws = <DartThrow>[
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
        DartThrow(playerIndex: 1, segment: 5, multiplier: 1, points: 5,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 2, roundNumber: 1),
      ];
      expect(x01TurnTotals(throws, playerIndex: 0), [60]);
      expect(x01TurnTotals(throws, playerIndex: 1), [5]);
      expect(x01TurnTotals(const [], playerIndex: 0), isEmpty);
    });
  });
}
