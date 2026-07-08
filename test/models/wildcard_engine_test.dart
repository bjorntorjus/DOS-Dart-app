import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/wildcard_engine.dart';
import 'package:dart_scoring/models/wildcard_events.dart';

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

    test(
        'removing the current thrower re-rolls the turn modifier instead of '
        'leaking it to the seat inheritor (chaos 0 → re-roll can never '
        'produce a modifier)', () {
      final e = plain(); // startingChaos: 0
      e.debugForceModifier('onlyEvens');
      // Bank P0's turn so P1's turn starts with the forced modifier.
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier?.id, 'onlyEvens'); // rolled for P1

      e.removePlayer(1); // P1 leaves mid-announcement, P2 inherits the seat

      expect(e.currentPlayerIndex, 2);
      // At chaos 0 the modifier chance is 0%, so a genuine re-roll for P2
      // must clear activeModifier. If it were still 'onlyEvens', that would
      // be P1's leaked modifier, not a fresh roll.
      expect(e.activeModifier, isNull);
    });

    test(
        'removing the current thrower when it ends the game (≤1 active '
        'left) skips the re-roll without crashing', () {
      final e = plain(players: 2);
      e.debugForceModifier('onlyEvens');
      // Bank P0's turn so P1 (about to become the sole survivor) starts
      // its turn with the forced modifier active.
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier?.id, 'onlyEvens');

      expect(() => e.removePlayer(1), returnsNormally);

      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      // Same leak check as above, exercised on the path that also ends the
      // game — the re-roll must still happen (and find nothing at chaos 0)
      // rather than leaving P1's forced modifier stuck on the engine.
      expect(e.activeModifier, isNull);
    });
  });

  group('WildcardEngine turn-modifiers', () {
    test(
        'ONLY EVENS: odd segment scores 0 and is dimmed; even scores; '
        'meter still +1 on a dimmed triple (meter follows the dart, not '
        'the points)', () {
      final e = plain()..debugForceModifier('onlyEvens');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks; P1's turn rolls the forced modifier
      expect(e.activeModifier?.id, 'onlyEvens');
      expect(e.dimPredicate!(7), isTrue);
      expect(e.dimPredicate!(8), isFalse);
      final r = e.applyDart(7, 3); // dimmed triple
      expect(r.points, 0);
      expect(r.meterDelta, 1);
      expect(e.chaos, 1);
    });

    test("DOUBLE TROUBLE: D20 scores 60, T20 scores 0 (meter still +1)", () {
      final e = plain()..debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls doubleTrouble
      expect(e.activeModifier?.id, 'doubleTrouble');
      final r1 = e.applyDart(20, 2); // D20 -> 20*3
      expect(r1.points, 60);
      final r2 = e.applyDart(20, 3); // T20 -> 0, meter still reacts
      expect(r2.points, 0);
      expect(r2.meterDelta, 1);
    });

    test('DOUBLE TROUBLE: D-Bull scores 75 (25 x 3)', () {
      final e = plain()..debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls doubleTrouble
      final r = e.applyDart(25, 2); // D-Bull
      expect(r.points, 75);
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 3);
    });

    test('GOLDEN DART: third dart of the turn triples', () {
      final e = plain()..debugForceModifier('goldenDart');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls goldenDart
      expect(e.activeModifier?.id, 'goldenDart');
      e.applyDart(5, 1); // dart 1: 5
      e.applyDart(5, 1); // dart 2: 5
      final r = e.applyDart(5, 1); // dart 3 (golden): 5*3=15
      expect(r.points, 15);
      expect(e.totals[1], 25); // 5 + 5 + 15
    });

    test('EVERYTHING x2 doubles the banked turn total', () {
      final e = plain()..debugForceModifier('everythingX2');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls everythingX2
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1); // turnPoints 60 -> banked 120
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 120);
    });

    test('HOLY TRINITY: exactly 26 banks 126; any other total is unchanged',
        () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(20, 1);
      e.applyDart(5, 1);
      e.debugForceModifier('holyTrinity'); // queue for P2's roll too
      e.applyDart(1, 1); // turnPoints 26 -> banks 126; P1 banks, P2 rolls
      expect(e.totals[1], 126);

      expect(e.activeModifier?.id, 'holyTrinity');
      e.applyDart(20, 1);
      e.applyDart(5, 1);
      final r = e.applyDart(2, 1); // turnPoints 27 -> banks 27, no bonus
      expect(r.turnEnded, isTrue);
      expect(e.totals[2], 27);
    });

    test(
        "BULL'S FORTUNE: bull dart worth +100 instead of its normal points; "
        'choice still required', () {
      final e = plain()..debugForceModifier('bullsFortune');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls bullsFortune
      final r = e.applyDart(25, 1); // single bull under FORTUNE
      expect(r.points, 100);
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 1);
      e.resolveBullChoice(1);
      expect(e.chaos, 1);
    });

    test(
        "BULL'S CURSE: bull dart worth -100; banking floors the turn at 0, "
        'never negative', () {
      final e = plain()..debugForceModifier('bullsCurse');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls bullsCurse
      final r = e.applyDart(25, 1); // single bull under CURSE
      expect(r.points, -100);
      expect(r.needsBullChoice, isTrue);
      e.resolveBullChoice(-1);
      e.applyDart(0, 0);
      e.applyDart(0, 0); // 2 misses, turnPoints ends at -100
      expect(e.totals[1], 0); // floored at 0, never negative
    });

    test(
        'WINDOW: total inside bounds (inclusive) banks flat 100 and '
        'increments windowPrizes', () {
      final e = plain()..debugForceModifier('theWindow');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls theWindow
      expect(e.activeModifier?.id, 'theWindow');
      e.window = (lo: 40, hi: 60); // deterministic override for the test
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1); // total 60, inside [40, 60]
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 100);
      expect(e.windowPrizes[1], 1);
    });

    test('WINDOW: total outside bounds banks 0, no prize', () {
      final e = plain()..debugForceModifier('theWindow');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls theWindow
      e.window = (lo: 40, hi: 60);
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // total 3, outside [40, 60]
      expect(e.totals[1], 0);
      expect(e.windowPrizes[1], 0);
    });

    test(
        'WINDOW: a true miss voids the turn (banks 0) even if the total '
        'would have landed inside the window; meter still -1', () {
      final e = plain()..debugForceModifier('theWindow');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls theWindow
      e.window = (lo: 0, hi: 10); // total-so-far will be well inside this
      e.applyDart(1, 3); // triple: 3 points, meter 0 -> 1 (room to drop)
      final miss = e.applyDart(0, 0); // true miss
      expect(miss.meterDelta, -1); // chaos 1 -> 0
      final r = e.applyDart(2, 1); // total 5 -> inside [0,10], but voided
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 0);
      expect(e.windowPrizes[1], 0);
    });

    test(
        'frozen player scores 0 all turn (meter still reacts), rolls no '
        'modifier, unfreezes once that turn banks', () {
      final e = plain();
      e.frozenPlayer = 1; // freeze P1 before their turn starts
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's (frozen) turn begins
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier, isNull); // frozen thrower rolls no modifier

      final r = e.applyDart(20, 3); // would be a triple; frozen zeroes points
      expect(r.points, 0);
      expect(r.meterDelta, 1); // meter still reacts to the dart
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      expect(e.totals[1], 0); // banked 0 despite the meter movement
      expect(e.frozenPlayer, isNull); // dissolves once the turn banks
    });

    test('modifier announcement is per-turn: cleared after banking', () {
      final e = plain();
      e.activeModifier = onlyEvens; // simulate an active modifier on P0
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks; chaos 0 -> 0% reroll chance for P1
      expect(e.activeModifier, isNull);
      expect(e.currentPlayerIndex, 1);
    });

    test('undo across a modifier roll restores the previous modifier state',
        () {
      final e = plain()..debugForceModifier('onlyEvens');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls forced onlyEvens
      expect(e.activeModifier?.id, 'onlyEvens');
      e.undo(); // undo P0's 3rd dart (the bank) -> pre-bank state
      expect(e.activeModifier, isNull); // P0's turn had no modifier
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 2);
    });

    test('statistical sanity: at chaos 10 a modifier always rolls', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 20, startingChaos: 10, rng: math.Random(1));
      var turnsChecked = 0;
      for (var i = 0; i < 15 && !e.gameOver; i++) {
        turnsChecked++;
        expect(e.activeModifier, isNotNull,
            reason: 'chaos 10 is a 100% modifier chance every turn');
        e.applyDart(1, 1);
        e.applyDart(1, 1);
        e.applyDart(1, 1); // plain darts: no triples/misses/bulls
      }
      expect(turnsChecked, greaterThan(0));
    });
  });

  group('WildcardEngine controller robustness', () {
    test('meter clamps at 10: a further triple past the cap gives '
        'meterDelta 0', () {
      final e = plain();
      for (var i = 0; i < 10; i++) {
        e.applyDart(20, 3); // 10 triples: chaos climbs 0 -> 10
      }
      expect(e.chaos, 10);
      final r = e.applyDart(20, 3); // 11th triple: already at the cap
      expect(r.meterDelta, 0);
      expect(e.chaos, 10);
    });

    test('undo while a bull choice is pending reverts cleanly to the '
        'pre-dart state', () {
      final e = plain();
      e.applyDart(1, 1); // dart 1: chaos 0, turnPoints 1, dartsInTurn 1
      final r = e.applyDart(25, 2); // D-Bull: pending choice
      expect(r.needsBullChoice, isTrue);
      expect(e.pendingBullChoice, 3);
      e.undo();
      expect(e.chaos, 0);
      expect(e.turnPoints, 1);
      expect(e.dartsInTurn, 1);
      expect(e.pendingBullChoice, isNull);
    });

    test(
        "banking floor: a BULL'S CURSE turn with only a single bull (-100) "
        'banks the turn at 0, never negative', () {
      final e = plain()..debugForceModifier('bullsCurse');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls bullsCurse
      final r = e.applyDart(25, 1); // single bull under CURSE: -100
      expect(r.points, -100);
      e.resolveBullChoice(-1);
      // Remaining 2 darts miss: turnPoints traces -100 + 0 + 0 = -100.
      e.applyDart(0, 0);
      final r3 = e.applyDart(0, 0);
      expect(r3.turnEnded, isTrue);
      expect(e.totals[1], 0); // floored, never negative
    });
  });
}
