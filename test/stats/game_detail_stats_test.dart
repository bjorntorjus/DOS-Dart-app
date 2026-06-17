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
}
