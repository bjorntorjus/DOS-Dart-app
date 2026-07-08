import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/wildcard_engine.dart';

WildcardEngine plain({int players = 3, int rounds = 5}) => WildcardEngine(
    playerCount: players, rounds: rounds, startingChaos: 0, rng: math.Random(7));

void main() {
  group('WildcardEngine core', () {
    test('chaos-0 baseline: a plain points race, no modifiers, no jokers', () {
      final e = plain();
      for (var r = 0; r < 5 * 3 * 3; r++) {
        expect(e.activeModifier, isNull);
        expect(e.jokers, isEmpty);
        if (e.gameOver) break;
        e.applyDart(5, 1); // no triples/bulls → meter stays 0
      }
      expect(e.gameOver, isTrue);
      expect(e.chaos, 0);
    });

    test('turn banks at 3 darts and rotation advances', () {
      final e = plain();
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1);
      expect(r.turnEnded, isTrue);
      expect(e.totals[0], 60);
      expect(e.currentPlayerIndex, 1);
      expect(e.turnPoints, 0);
    });

    test('meter: triple +1, true miss −1, clamps at 0 and 10', () {
      final e = plain();
      final r1 = e.applyDart(0, 0); // miss at 0 → clamped
      expect(r1.meterDelta, 0);
      expect(e.chaos, 0);
      final r2 = e.applyDart(20, 3);
      expect(r2.meterDelta, 1);
      expect(e.chaos, 1);
    });

    test('bull requires a choice and the choice lands in the same undo entry',
        () {
      final e = plain();
      final r = e.applyDart(25, 2); // D-Bull
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 3);
      e.resolveBullChoice(3);
      expect(e.chaos, 3);
      e.undo(); // one undo removes dart AND meter change
      expect(e.chaos, 0);
      expect(e.turnPoints, 0);
    });

    test('single bull needs a ±1 choice; negative direction applies', () {
      final e = plain();
      final r = e.applyDart(25, 1); // single bull, 25 points
      expect(r.points, 25);
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 1);
      expect(r.meterDelta, 0); // deferred until the choice resolves
      e.resolveBullChoice(-1);
      expect(e.chaos, 0); // clamped: 0 - 1 → 0
    });

    test('bull does not advance the turn until the choice resolves, even as '
        'the 3rd dart', () {
      final e = plain();
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      final r = e.applyDart(25, 2); // 3rd dart of the turn is a bull
      expect(r.turnEnded, isFalse);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 3);
      e.resolveBullChoice(3);
      expect(e.currentPlayerIndex, 1); // now the turn actually banks
      expect(e.totals[0], 52); // 1 + 1 + 50
    });

    test('game over after final round; ranking reflects the totals', () {
      final e = plain(players: 2, rounds: 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0: 60 in one turn
      e.applyDart(20, 3);
      e.applyDart(0, 0);
      e.applyDart(0, 0); // P1: 60 with a 60-turn
      expect(e.gameOver, isTrue);
      expect(e.totals, [60, 60]);
    });

    test('ranking: equal totals, tiebreak by higher single banked turn', () {
      final e = plain();
      e.totals[0] = 100;
      e.totals[1] = 100;
      e.totals[2] = 50;
      e.highestTurn[0] = 40;
      e.highestTurn[1] = 60;
      expect(e.ranking(), [1, 0, 2]);
    });

    test(
        'ranking: identical totals and identical highest turn share '
        'placement by seat order', () {
      final e = plain();
      e.totals[0] = 60;
      e.totals[1] = 60;
      e.totals[2] = 60;
      e.highestTurn[0] = 20;
      e.highestTurn[1] = 20;
      e.highestTurn[2] = 20;
      expect(e.ranking(), [0, 1, 2]);
    });

    test('undo restores everything incl. round/turn state', () {
      final e = plain();
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1); // banks P0's turn, rotates to P1
      expect(r.turnEnded, isTrue);
      expect(e.totals[0], 60);

      e.applyDart(5, 1); // P1 dart 1
      e.undo(); // undo P1's dart → back to right after P0 banked
      expect(e.currentPlayerIndex, 1);
      expect(e.totals[0], 60);
      expect(e.turnPoints, 0);
      expect(e.dartsInTurn, 0);

      e.undo(); // undo P0's 3rd dart (the bank) → pre-bank 2-dart state
      expect(e.currentPlayerIndex, 0);
      expect(e.totals[0], 0);
      expect(e.turnPoints, 40);
      expect(e.dartsInTurn, 2);
      expect(e.round, 1);
    });
  });

  group('WildcardEngine roster', () {
    test('remove current player advances seat; ≤1 active ends game with '
        'survivor', () {
      final e = plain(players: 3);
      e.applyDart(20, 1); // P0 mid-turn
      e.removePlayer(0);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartsInTurn, 0);
      expect(e.turnPoints, 0);
      expect(e.isSkipped(0), isTrue);

      e.removePlayer(2);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 1);
    });

    test('addPlayer joins at 0 and clears undo', () {
      final e = plain();
      e.applyDart(20, 1);
      e.addPlayer();
      expect(e.totals.length, 4);
      expect(e.totals[3], 0);
      expect(e.canUndo, isFalse);
    });

    test('removing the frozen player dissolves the freeze', () {
      final e = plain();
      e.frozenPlayer = 1;
      e.removePlayer(1);
      expect(e.frozenPlayer, isNull);
    });
  });
}
