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
      // QA5 loop-taming: triple is now +1 (was +2).
      expect(r2.meterDelta, 1);
      expect(e.chaos, 1);
    });

    test('meter: double-ring dart is +1 (new lever; D-Bull excluded)', () {
      final e = plain();
      final r = e.applyDart(20, 2); // D20: a plain double-ring dart
      expect(r.meterDelta, 1);
      expect(e.chaos, 1);
    });

    test('a triple raises the meter by 1 (was 2)', () {
      final e = plain();
      final r = e.applyDart(20, 3);
      expect(r.meterDelta, 1);
      expect(e.chaos, 1);
    });

    test('joker hit raises the meter by 1 (was 2)', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1}); // seed 7, chaos 3 -> wcJokerCount == 1
      // doubleJeopardy has no chaos side effect of its own (just sets a
      // one-round flag), so the whole meter movement here is the joker's.
      e.debugForceEvent('doubleJeopardy');
      final r = e.applyDart(1, 1); // single dart hits the joker
      expect(r.jokerHit, 1);
      expect(r.meterDelta, 1); // joker: +1 (was +2)
      expect(e.chaos, 4); // 3 base + 1 joker
    });

    test('meter decays by 1 at the start of each new round', () {
      final e = plain(players: 1, rounds: 3); // 1 player -> round advances every turn
      e.applyDart(20, 3); // triple: chaos 0 -> 1
      e.applyDart(20, 3); // triple: chaos 1 -> 2
      final prevChaos = e.chaos;
      expect(prevChaos, 2);
      e.applyDart(1, 1); // 3rd dart banks the turn; round advances -> decay -1
      expect(e.chaos, prevChaos - 1); // 2 -> 1
      expect(e.round, 2);
    });

    test('round-start decay clamps at 0', () {
      final e = plain(players: 1, rounds: 3); // chaos starts at 0
      expect(e.chaos, 0);
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // banks the turn; round advances -> decay tries -1
      expect(e.chaos, 0); // clamped, not negative
      expect(e.round, 2);
    });

    test(
        'meter: only the FIRST true miss in a turn costs the meter; a '
        'second miss the same turn is a no-op (not just clamp-related)', () {
      // startingChaos 0 keeps jokers empty (wcJokerCount(0) == 0), so the
      // plain darts below can't accidentally trigger a joker/instant event
      // that would perturb chaos independently of the miss mechanic. Set
      // chaos directly (bypasses joker assignment) to give the meter room
      // to drop twice.
      final e = plain(players: 2)..chaos = 3;
      final r1 = e.applyDart(0, 0); // 1st miss this turn: -1
      expect(r1.meterDelta, -1);
      expect(e.chaos, 2);
      final r2 = e.applyDart(0, 0); // 2nd miss this turn: no-op (not clamp)
      expect(r2.meterDelta, 0);
      expect(e.chaos, 2);
      e.applyDart(1, 1); // 3rd dart banks the turn; miss-flag resets
      final r4 = e.applyDart(0, 0); // P1's turn, 1st miss: -1 again
      expect(r4.meterDelta, -1);
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
        'the points; QA5 triple tuning applies here too)', () {
      final e = plain()..debugForceModifier('onlyEvens');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks; P1's turn rolls the forced modifier
      expect(e.activeModifier?.id, 'onlyEvens');
      expect(e.dimPredicate!(7, 1), isTrue);
      expect(e.dimPredicate!(8, 1), isFalse);
      final r = e.applyDart(7, 3); // dimmed triple
      expect(r.points, 0);
      expect(r.meterDelta, 1); // triple: +1 (QA5, was +2)
      expect(e.chaos, 1);
    });

    test(
        'dimPredicate bull carve-out: under ONLY EVENS, (25, 1) is reported '
        'as scoring (false) even though 25 is odd — the value-based '
        'predicate alone would wrongly dim bull; dimPredicate wraps it with '
        'the same holyTrinity-only exception applyDart uses', () {
      final e = plain()..debugForceModifier('onlyEvens');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks; P1's turn rolls the forced modifier
      expect(e.activeModifier?.id, 'onlyEvens');
      expect(e.dimPredicate!(25, 1), isFalse); // bull exempt, not trinity
      expect(e.dimPredicate!(25, 2), isFalse); // D-Bull exempt too
    });

    test(
        'DOUBLE TROUBLE v2 (QA round 4): D20 scores 100 (20x5, meter +1, '
        'the double-ring lever), T20 dims to 0 (only doubles score; meter '
        '+1 QA5 triple tuning still applies)', () {
      final e = plain()..debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls doubleTrouble
      expect(e.activeModifier?.id, 'doubleTrouble');
      final r1 = e.applyDart(20, 2); // D20 -> 20*5 (was x3 pre-QA4)
      expect(r1.points, 100);
      expect(r1.meterDelta, 1); // double-ring: +1 (new)
      final r2 = e.applyDart(20, 3); // T20 -> dimmed to 0, meter still reacts
      expect(r2.points, 0);
      expect(r2.meterDelta, 1); // triple: +1 (QA5, was +2)
    });

    test(
        'DOUBLE TROUBLE v2: S20 (single ring) also dims to 0 — only the '
        'double ring scores', () {
      final e = plain()..debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls doubleTrouble
      final r = e.applyDart(20, 1); // S20, dimmed
      expect(r.points, 0);
    });

    test(
        'DOUBLE TROUBLE v2: bull is exempt from the x5 payout — D-Bull '
        'still scores a plain 50 (was x3 = 75 pre-QA4), only the meter '
        'choice mechanic applies', () {
      final e = plain()..debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls doubleTrouble
      final r = e.applyDart(25, 2); // D-Bull
      expect(r.points, 50); // exempt: plain double-bull value, no x5/x3
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 3);
    });

    test(
        'TRIPLE THREAT (QA round 4, DT\'s sibling): T20 scores 100 (20x5, '
        'meter +1 QA5), D20 dims to 0 (only triples score; meter +1 still '
        'applies)', () {
      final e = plain()..debugForceModifier('tripleThreat');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls tripleThreat
      expect(e.activeModifier?.id, 'tripleThreat');
      final r1 = e.applyDart(20, 3); // T20 -> 20*5
      expect(r1.points, 100);
      expect(r1.meterDelta, 1); // triple: +1 (QA5, was +2)
      final r2 = e.applyDart(20, 2); // D20 -> dimmed to 0
      expect(r2.points, 0);
      expect(r2.meterDelta, 1); // double-ring: +1 still applies
    });

    test(
        'TRIPLE THREAT: bull is exempt from the x5 payout — S-Bull scores '
        'a plain 25', () {
      final e = plain()..debugForceModifier('tripleThreat');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls tripleThreat
      final r = e.applyDart(25, 1); // single bull
      expect(r.points, 25);
      expect(r.needsBullChoice, isTrue);
      expect(r.bullChoiceMagnitude, 1);
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

    test(
        'HOLY TRINITY v3: D5+S20+S1 (any ring on each) banks 131 — the '
        'coverage bonus no longer requires all-singles', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(5, 2); // D5 = 10
      e.applyDart(20, 1); // S20 = 20
      final r = e.applyDart(1, 1); // S1 = 1; segments {5,20,1} -> +100
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 131); // 10 + 20 + 1 + 100
    });

    test(
        'HOLY TRINITY v3: T20+D5+S1 banks 171 — a triple no longer '
        'disqualifies the coverage bonus (v3: any ring counts on each of '
        'the three numbers)', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(20, 3); // T20 = 60
      e.applyDart(5, 2); // D5 = 10
      final r = e.applyDart(1, 1); // S1 = 1; segments {20,5,1} -> +100
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 171); // 60 + 10 + 1 + 100
    });

    test('HOLY TRINITY v3: the trinity darts qualify in ANY throw order', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(1, 1); // S1 first this time
      e.applyDart(5, 1);
      final r = e.applyDart(20, 1); // S1, S5, S20 -> still the trinity
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 126);
    });

    test('HOLY TRINITY v3: S5+S5+S20 banks 30, no bonus — coverage is '
        'missing 1 (a repeated number does not substitute)', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(5, 1);
      e.applyDart(5, 1);
      final r = e.applyDart(20, 1); // segments {5,20} -> missing 1, no bonus
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 30); // 5 + 5 + 20, no +100
    });

    test('HOLY TRINITY v3: S5+S20+miss banks 25, no bonus — a true miss '
        'records segment 0 and contributes nothing to coverage', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(5, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(0, 0); // true miss
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 25); // 5 + 20 + 0, no bonus (missing 1)
    });

    test(
        'HOLY TRINITY v3: D10+S5+S1 also sums to 26 but is NOT the trinity — '
        'the literal segment-coverage rule replaces the old sum==26 check, '
        'and segment 10 is dimmed by the restriction on top of that '
        '(regression guard: the pre-restriction rule would have banked 26 '
        'here)', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      final d10 = e.applyDart(10, 2); // D10 = 20, but 10 isn't in {20,5,1}
      expect(d10.points, 0); // dimmed by the trinity restriction
      e.applyDart(5, 1);
      final r = e.applyDart(1, 1); // turnPoints 0 + 5 + 1 = 6
      expect(r.turnEnded, isTrue);
      expect(e.totals[1], 6); // banked plain — no +100 bonus, D10 dimmed
    });

    test(
        'dimPredicate bull carve-out: under HOLY TRINITY, (25, 1) is '
        'reported as non-scoring (true) — the one modifier where the board '
        'must actually dim bull, mirroring applyDart\'s scoring carve-out', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      expect(e.activeModifier?.id, 'holyTrinity');
      expect(e.dimPredicate!(25, 1), isTrue);
      expect(e.dimPredicate!(25, 2), isTrue);
    });

    test(
        'HOLY TRINITY v3: bull is the ONE exception to "bull always scores '
        'under a restriction" — it scores 0, the bull choice still fires '
        'unconditionally, and 25 does not count toward coverage', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(20, 1); // S20 = 20
      e.applyDart(1, 1); // S1 = 1
      final r = e.applyDart(25, 1); // bull, dimmed to 0 under trinity
      expect(r.points, 0);
      expect(r.needsBullChoice, isTrue); // bull control stays unconditional
      expect(r.bullChoiceMagnitude, 1);
      e.resolveBullChoice(1); // resolves normally; banks the turn (3rd dart)
      expect(e.totals[1], 21); // 20 + 1 + 0 — no bonus, 25 isn't coverage
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
      e.applyDart(1, 3); // triple: 3 points, meter 0 -> 2 (room to drop)
      final miss = e.applyDart(0, 0); // true miss
      expect(miss.meterDelta, -1); // chaos 2 -> 1
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
      expect(r.meterDelta, 1); // meter still reacts to the dart (triple: +1, QA5)
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

    test(
        'statistical sanity: at chaos 10 the modifier COOLDOWN roughly '
        'halves the raw 80% chance table\'s effective rate', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 100, startingChaos: 10, rng: math.Random(1));
      var turnsChecked = 0;
      var rolled = 0;
      for (var i = 0; i < 200 && !e.gameOver; i++) {
        // QA5 added a -1/round decay (a deliberate, SEPARATE mechanic to tame
        // the chaos-meter ratchet). Left unchecked over 100 rounds it would
        // walk chaos down toward 0, confounding this test's cooldown-only
        // statistic with the decay's own effect. Pin chaos back to 10 at the
        // top of every turn: levels 9 and 10 share the same 90% entry in
        // _modifierChancePctByLevel, so at most one round's worth of decay
        // (-1) can ever be in effect at roll time regardless — the reset
        // just stops it from accumulating turn over turn.
        e.chaos = 10;
        turnsChecked++;
        if (e.activeModifier != null) rolled++;
        // Plain darts: no triples/misses/bulls, but segment 1 may be a
        // joker and trigger an event (e.g. CUT!) that ends the turn early —
        // stop throwing once that happens rather than asserting past it.
        for (var d = 0; d < 3 && !e.gameOver; d++) {
          e.applyDart(1, 1);
        }
      }
      expect(turnsChecked, greaterThan(0));
      // chaos 10 is an 80% modifier chance per eligible roll (tuned table),
      // but cooldown means a player who got a modifier skips their very
      // next roll — a 2-state Markov chain (rollable <-> cooldown) whose
      // stationary "modifier assigned" fraction is p/(1+p) = 0.8/1.8 ≈
      // 0.444, not the raw 0.8. Generous tolerance for a statistical test.
      expect(rolled / turnsChecked, greaterThan(0.25));
      expect(rolled / turnsChecked, lessThan(0.6));
    });
  });

  group('WildcardEngine HEAVY CROWN', () {
    test('HEAVY CROWN never fires before round 4', () {
      final e = plain(players: 2, rounds: 10);
      // P0 holds a lead far past kHeavyCrownLeadThreshold (120) for the
      // whole test; every dart below is a miss (0 pts) so it never changes.
      e.totals[0] = 200;
      // 5 banked turns walks currentPlayerIndex/round through: P1@r1,
      // P0@r2, P1@r2, P0@r3, P1@r3 — every roll still lands in rounds 1-3.
      // A 6th turn would wrap into round 4, which is out of scope here (see
      // the threshold test below for round-4 behavior).
      for (var t = 0; t < 5; t++) {
        e.applyDart(0, 0);
        e.applyDart(0, 0);
        e.applyDart(0, 0);
        expect(e.round, lessThan(4));
        expect(e.activeModifier?.id, isNot('heavyCrown'));
      }
    });

    test('HEAVY CROWN only targets a leader ahead by >= threshold', () {
      // Drives P0 to a lead of [lead] and banks 6 miss-only turns (2
      // players), which walks round 1 -> 4 and lands the crown-eligible
      // roll on P0's round-4 turn (see trace in the test above). Chaos
      // stays 0 throughout (no triples/doubles/bulls, jokerCount(0) == 0),
      // so this is the FIRST and only _rng call the whole run makes —
      // picking the seed picks the crown roll outright.
      bool crownFires(int lead, int seed) {
        final e = WildcardEngine(
            playerCount: 2, rounds: 10, startingChaos: 0, rng: math.Random(seed));
        e.totals[0] = lead;
        for (var t = 0; t < 6; t++) {
          e.applyDart(0, 0);
          e.applyDart(0, 0);
          e.applyDart(0, 0);
        }
        return e.activeModifier?.id == 'heavyCrown';
      }

      // 119 lead: under threshold, the guard rejects before ever touching
      // the rng — true regardless of seed.
      for (var seed = 0; seed < 30; seed++) {
        expect(crownFires(119, seed), isFalse);
      }

      // 120 lead: at the threshold, some seed's 25%-chance roll must land
      // a crown — bounded search over fixed seeds, not a live random draw.
      final canCrown =
          List<int>.generate(500, (i) => i).any((seed) => crownFires(120, seed));
      expect(canCrown, isTrue);
    });

    test('debugForceModifier heavyCrown sets it as the active modifier', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // bank P0, roll P1's turn
      expect(e.activeModifier?.id, 'heavyCrown');
    });

    test('HEAVY CROWN: 1 true miss costs 20 off the game total', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 -> 60, banks; P1's turn rolls heavyCrown (forced)
      expect(e.activeModifier?.id, 'heavyCrown');

      e.totals[1] = 300; // base total, set by hand before P1 throws
      e.applyDart(0, 0); // true miss #1
      e.applyDart(5, 1); // scores 5 — not a miss
      e.applyDart(5, 1); // scores 5 — not a miss; turn banks
      // turnPoints = 5 + 5 = 10; 1 true miss -> penalty 20.
      // banked total: 300 + 10 - 20 = 290.
      expect(e.totals[1], 290);
    });

    test('HEAVY CROWN: 2 true misses cost 40 off the game total', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 -> 60, banks; P1's turn rolls heavyCrown (forced)
      expect(e.activeModifier?.id, 'heavyCrown');

      e.totals[1] = 300;
      e.applyDart(0, 0); // true miss #1
      e.applyDart(0, 0); // true miss #2
      e.applyDart(5, 1); // scores 5 — not a miss; turn banks
      // turnPoints = 5; 2 true misses -> penalty 40.
      // banked total: 300 + 5 - 40 = 265.
      expect(e.totals[1], 265);
    });

    test('HEAVY CROWN: 3 true misses cost 80 off the game total', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 -> 60, banks; P1's turn rolls heavyCrown (forced)
      expect(e.activeModifier?.id, 'heavyCrown');

      e.totals[1] = 300;
      e.applyDart(0, 0); // true miss #1
      e.applyDart(0, 0); // true miss #2
      e.applyDart(0, 0); // true miss #3; turn banks
      // turnPoints = 0; 3 true misses -> penalty 80.
      // banked total: 300 + 0 - 80 = 220.
      expect(e.totals[1], 220);
    });

    test('HEAVY CROWN penalty floors at 0', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 -> 60, banks; P1's turn rolls heavyCrown (forced)
      expect(e.activeModifier?.id, 'heavyCrown');

      e.totals[1] = 50; // smaller than the 80-point 3-miss penalty
      e.applyDart(0, 0);
      e.applyDart(0, 0);
      e.applyDart(0, 0);
      // 50 + 0 - 80 = -30, floored to 0, not negative.
      expect(e.totals[1], 0);
    });

    test(
        'undo across a HEAVY CROWN turn restores the total and the '
        'per-turn miss counter', () {
      final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 -> 60, banks; P1's turn rolls heavyCrown (forced)
      expect(e.activeModifier?.id, 'heavyCrown');

      e.totals[1] = 300;
      e.applyDart(0, 0); // true miss #1
      e.applyDart(0, 0); // true miss #2
      e.applyDart(0, 0); // true miss #3; turn banks: 300 + 0 - 80 = 220
      expect(e.totals[1], 220);

      e.undo(); // undo the 3rd (banking) dart
      expect(e.totals[1], 300); // total restored
      expect(e.dartsInTurn, 2); // still mid-turn, 2 darts thrown

      // If the per-turn miss counter had NOT been restored to 2 (e.g. left
      // at 3, or wrongly reset to 0), finishing the turn with a scoring dart
      // instead of a 3rd miss would bank a different total than expected.
      e.applyDart(5, 1); // scores 5, not a miss; turn banks
      // turnPoints = 5; miss counter must read back as 2 -> penalty 40.
      // banked total: 300 + 5 - 40 = 265.
      expect(e.totals[1], 265);
    });
  });

  group('WildcardEngine modifier cooldown', () {
    test(
        'a modifier-having turn puts that player on cooldown for their '
        'very next turn (deterministic via debugForceModifier; chaos 0 so '
        'no unforced roll can contaminate the sequence)', () {
      final e = plain(players: 2); // startingChaos 0
      expect(e.activeModifier, isNull); // turn 1 (P0): chaos 0 -> no roll

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 1 (no modifier); rolls turn 2 (P1)
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier, isNull); // turn 2 (P1): chaos 0 -> no roll

      // Queue a force now: the next roll is turn 3 (P0), when turn 2 banks.
      e.debugForceModifier('onlyEvens');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks turn 2 (no modifier -> no P1 cooldown)
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier?.id, 'onlyEvens'); // turn 3 (P0): forced

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 3 (HAD a modifier -> P0 cooldown set)
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier, isNull); // turn 4 (P1): chaos 0 anyway

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks turn 4; rolls turn 5 for P0
      expect(e.currentPlayerIndex, 0);
      // Turn 5 is P0's very next turn since the forced modifier on turn 3 —
      // cooldown must suppress the roll even though chaos is 0 anyway.
      expect(e.activeModifier, isNull);
    });

    test(
        "a fresh debugForceModifier queued while the thrower is on "
        'cooldown is NOT consumed by the skipped roll — it survives to the '
        'next roll that actually happens (frozen-skip semantics mirrored)',
        () {
      final e = plain(players: 2); // startingChaos 0
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 1 (no modifier); rolls turn 2 (P1)

      e.debugForceModifier('onlyEvens'); // lands on turn 3 (P0)
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks turn 2; rolls turn 3 for P0
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier?.id, 'onlyEvens'); // turn 3 (P0): forced

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 3 -> P0's cooldown flag set
      expect(e.currentPlayerIndex, 1);

      // Queue a fresh force before turn 4 (P1) banks; the next roll it
      // triggers is turn 5 (P0), which is on cooldown and must skip.
      e.debugForceModifier('doubleTrouble');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks turn 4 (no modifier); rolls turn 5 (P0)
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier, isNull); // cooldown skip, force NOT consumed

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 5 (no modifier -> no new cooldown);
      // rolls turn 6 for P1, which is the first real roll since the force
      // was queued — the survived force applies here.
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier?.id, 'doubleTrouble');
    });

    test(
        "the cooldown flag is snapshot-restored on undo: undoing the dart "
        "that both banked P1's turn AND cleared P0's cooldown (via the "
        "skip) puts P0 back on cooldown, so redoing that exact dart skips "
        'P0 again instead of rolling the still-queued force', () {
      final e = plain(players: 2);
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 1 (no modifier); rolls turn 2 (P1)

      e.debugForceModifier('onlyEvens'); // lands on turn 3 (P0)
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks turn 2; rolls turn 3 for P0
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier?.id, 'onlyEvens'); // turn 3 (P0): forced

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 3 -> P0's cooldown flag set true
      expect(e.currentPlayerIndex, 1);

      e.debugForceModifier('doubleTrouble'); // queued; next real roll wins it
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      // This dart banks P1's turn 4 AND rolls turn 5 for P0 — which is on
      // cooldown, so the roll is skipped and the cooldown flag is CLEARED
      // to false as a side effect of that skip.
      final criticalDart = e.applyDart(1, 1);
      expect(criticalDart.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier, isNull); // turn 5 (P0): cooldown skip

      // Undo exactly that dart. If the cooldown flag's pre-dart value
      // (true) is correctly restored, P0 is back on cooldown.
      e.undo();
      expect(e.currentPlayerIndex, 1);

      // Redo the identical dart: if the flag was restored to true, turn 5
      // skips again (null) — the queued force is still not consumed. If
      // undo had left the flag leaked at false, this redo would instead
      // roll the force ('doubleTrouble') immediately, since nothing else
      // would stop it.
      final redone = e.applyDart(1, 1);
      expect(redone.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 0);
      expect(e.activeModifier, isNull); // still skipped -> flag was restored

      // The force is still alive; confirm it finally lands on the next
      // real roll (P0's turn 5 banks with no modifier, then P1's turn 6).
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks turn 5; rolls turn 6 for P1
      expect(e.currentPlayerIndex, 1);
      expect(e.activeModifier?.id, 'doubleTrouble');
    });
  });

  group('WildcardEngine controller robustness', () {
    test('meter clamps at 10: a further triple past the cap gives '
        'meterDelta 0', () {
      // 4 players (not the default 3): a bank only rotates the seat, and a
      // round only wraps (triggering the QA5 round-start decay) once every
      // 4 turns / 12 darts. 10 darts here land mid-round-1 (seat 3's first
      // dart), so no decay confounds the pure +1-per-triple accumulation.
      final e = plain(players: 4);
      for (var i = 0; i < 10; i++) {
        // Triples are now +1 (QA5 tuning, was +2): the cap is reached
        // exactly on the 10th (1,2,...,10).
        e.applyDart(20, 3);
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

  group('WildcardEngine jokers', () {
    test('round 1 assigns exactly wcJokerCount(chaos) unique numbers 1-20',
        () {
      final e = plain(); // startingChaos: 0 -> wcJokerCount(0) == 0
      expect(e.jokers, isEmpty);

      final e3 = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e3.jokers, {1}); // seed 7, chaos 3 -> wcJokerCount == 1
    });

    test('two jokers never share a number: chaos 9 assigns 2 distinct', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 9, rng: math.Random(7));
      expect(e.jokers, {1, 18});
      expect(e.jokers.length, 2);
    });

    test(
        'joker hit: reveals, meter +1 (QA5), jokersHitCount increments, '
        're-rolls excluding the just-hit number and other actives', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 9, rng: math.Random(7));
      expect(e.jokers, {1, 18});
      e.debugForceEvent('chaosSurge');
      final r = e.applyDart(1, 1); // hits the joker at 1
      expect(r.jokerHit, 1);
      expect(r.instantEvent?.id, 'chaosSurge');
      expect(e.jokersHitCount[0], 1);
      // 18 survives untouched; 1 re-rolled to a fresh number (14) that is
      // neither 1 (just hit) nor 18 (the other active joker).
      expect(e.jokers, {18, 14});
    });

    test('dimmed joker still triggers: scores 0 under a restriction but the '
        'event still fires (spec §10)', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7))
        ..debugForceModifier('onlyEvens');
      // P0 banks a plain turn so P1's turn rolls the forced onlyEvens.
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      expect(e.activeModifier?.id, 'onlyEvens');
      expect(e.jokers, {1}); // odd -> dimmed under onlyEvens

      e.debugForceEvent('chaosSurge');
      final r = e.applyDart(1, 1); // joker 1 is odd: dimmed, scores 0
      expect(r.points, 0);
      expect(r.jokerHit, 1);
      expect(r.instantEvent?.id, 'chaosSurge');
      expect(e.chaos, 7); // 3 (base) + 1 (joker, QA5) + 3 (chaosSurge)
    });
  });

  group('WildcardEngine instant events', () {
    test('CHAOS SURGE: meter +3', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.debugForceEvent('chaosSurge');
      e.applyDart(1, 1);
      expect(e.chaos, 7); // 3 + 1 (joker, QA5) + 3 (surge)
      expect(e.lastEventResolution?.detail, 'Chaos +3');
    });

    test('CHAOS SURGE: clamped at 10 near the cap', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 9, rng: math.Random(7));
      expect(e.jokers, {1, 18});
      e.debugForceEvent('chaosSurge');
      e.applyDart(1, 1); // joker: 9 -> 10 (+1 applied, QA5); surge: 10 -> 10 (+0, clamped)
      expect(e.chaos, 10);
      expect(e.lastEventResolution?.detail, 'Chaos +0');
    });

    test(
        'SCORE SWAP: totals swap with a uniformly-random OTHER living '
        'player', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 100;
      e.totals[1] = 40;
      e.totals[2] = 10;
      expect(e.jokers, {1});
      e.debugForceEvent('scoreSwap');
      final r = e.applyDart(1, 1); // P0 (hitter) hits the joker
      expect(r.jokerHit, 1);
      expect(e.totals, [40, 100, 10]); // P0 <-> P1 (the rng-picked other)
      expect(e.lastEventResolution?.detail, 'P0 and P1 swap scores');
      expect(e.lastEventResolution?.flags, [
        (playerIndex: 0, flagText: '-60 SWAP', good: false),
        (playerIndex: 1, flagText: '+60 SWAP', good: true),
      ]);
    });

    test(
        'ROBIN HOOD: steals 50 from the highest-total OTHER player, credited '
        'to the hitter; pointsStolen tracks it', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 10; // hitter
      e.totals[1] = 300; // leader/victim
      e.totals[2] = 20;
      expect(e.jokers, {1});
      e.debugForceEvent('robinHood');
      e.applyDart(1, 1);
      expect(e.totals, [60, 250, 20]); // 10+50, 300-50, unchanged
      expect(e.pointsStolen[0], 50);
      expect(e.lastEventResolution?.detail, 'STEAL 50 · P1 300 → 250');
      expect(e.lastEventResolution?.flags, [
        (playerIndex: 0, flagText: '+50 STEAL', good: true),
        (playerIndex: 1, flagText: '-50 ROBBED', good: false),
      ]);
    });

    test('ROBIN HOOD: steal caps at the victim total when under 50 (floor)',
        () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 10;
      e.totals[1] = 30; // leader, but under 50
      e.totals[2] = 20;
      e.debugForceEvent('robinHood');
      e.applyDart(1, 1);
      expect(e.totals, [40, 0, 20]); // steals only 30, victim floors at 0
      expect(e.pointsStolen[0], 30);
    });

    test('SCORE SWAP resolution carries before/after for both players', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 100; // P0 banks a lead so totals differ
      e.totals[1] = 40;
      expect(e.jokers, {1});
      e.debugForceEvent('scoreSwap');
      e.applyDart(1, 1); // P0 (hitter) hits the joker, swaps with P1
      expect(e.totals, [40, 100]);
      final ch = e.lastEventResolution!.scoreChanges;
      expect(ch, [
        (playerIndex: 0, before: 100, after: 40),
        (playerIndex: 1, before: 40, after: 100),
      ]);
      expect(ch.length, 2);
      expect(ch[0].after, ch[1].before); // swap symmetry
      expect(ch[1].after, ch[0].before);
      expect(ch.any((c) => c.before != c.after), isTrue); // it actually changed
    });

    test('ROBIN HOOD resolution carries hitter and victim before/after', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 10; // hitter
      e.totals[1] = 300; // clear leader/victim
      expect(e.jokers, {1});
      e.debugForceEvent('robinHood');
      e.applyDart(1, 1);
      expect(e.totals, [60, 250]);
      final ch = e.lastEventResolution!.scoreChanges;
      expect(ch, [
        (playerIndex: 0, before: 10, after: 60),
        (playerIndex: 1, before: 300, after: 250),
      ]);
      expect(ch.length, 2);
      final victim = ch.firstWhere((c) => c.after < c.before);
      final hitter = ch.firstWhere((c) => c.after > c.before);
      expect(
          victim.before - victim.after, hitter.after - hitter.before); // conserved
    });

    test(
        'GIFT (fixed QA round 4): 3-player, hitter is NOT last — the '
        'triggering dart\'s points plus the remaining darts of the turn '
        'credit the true lowest total (hitter included in the comparison, '
        'but not the target here)', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 50; // hitter — clearly not last
      e.totals[1] = 300;
      e.totals[2] = 5; // true lowest among all 3, hitter included
      expect(e.jokers, {1});
      e.applyDart(2, 1); // dart 1 (not the joker): 2 points, pre-gift
      e.debugForceEvent('gift');
      final d2 = e.applyDart(1, 1); // dart 2 hits the joker: +1, triggers GIFT
      expect(d2.jokerHit, 1);
      expect(e.lastEventResolution?.detail, 'Rest of the turn goes to P2');
      final d3 = e.applyDart(7, 1); // dart 3: +7, all of it redirected
      expect(d3.turnEnded, isTrue);
      // Thrower banks only the pre-gift 2 (on top of its starting 50); P2
      // gets the gift joker dart (1) plus the remaining dart (7) = 8.
      expect(e.totals, [52, 300, 13]);
    });

    test(
        'GIFT (log-diagnosed 2-player bug, fixed QA round 4): hitter is '
        'already in last place — the redirect targets the hitter itself '
        '(self-gift, a documented no-op) and the turn banks NORMALLY '
        'exactly once: no double-bank, no loss, opponent untouched', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[1] = 300; // P1 leads; hitter P0 stays lowest, incl. itself
      expect(e.jokers, {1});
      e.applyDart(2, 1); // dart 1 (not the joker): 2 points, pre-gift
      e.debugForceEvent('gift');
      final d2 = e.applyDart(1, 1); // dart 2 hits the joker: +1, triggers GIFT
      expect(d2.jokerHit, 1);
      expect(e.lastEventResolution?.detail, 'Rest of the turn goes to P0');
      final d3 = e.applyDart(7, 1); // dart 3: +7
      expect(d3.turnEnded, isTrue);
      // Self-redirect: the whole 2+1+7=10 banks to P0 exactly once.
      expect(e.totals, [10, 300]);
    });

    test(
        'GIFT: 3-player tie for last place (excluding the hitter, who leads) '
        'resolves to the earliest seat', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 50; // hitter, clearly not last
      e.totals[1] = 5;
      e.totals[2] = 5; // tied for last with P1
      expect(e.jokers, {1});
      e.debugForceEvent('gift');
      e.applyDart(1, 1); // hits the joker -> GIFT
      expect(e.lastEventResolution?.detail, 'Rest of the turn goes to P1');
    });

    test('FREEZE: flags the current leader (hitter included, tie -> '
        'earliest seat) for their next turn', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 10;
      e.totals[1] = 300; // leader
      e.totals[2] = 20;
      e.debugForceEvent('freeze');
      e.applyDart(1, 1);
      expect(e.frozenPlayer, 1);
      expect(e.lastEventResolution?.detail,
          'P1 FROZEN · skipped next turn (scores 0)');
    });

    test('FREEZE: ties resolve to the earliest seat, hitter included', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      // All totals start at 0 (a 3-way tie including the hitter, P0).
      e.debugForceEvent('freeze');
      e.applyDart(1, 1);
      expect(e.frozenPlayer, 0);
    });

    test('CURSED NUMBER: assigns a new hidden number; hitting it scores '
        'negative (−segment×multiplier) and clears the curse; the dialog '
        'detail never reveals the number', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.debugForceEvent('cursedNumber');
      e.applyDart(1, 1); // reveals the joker, assigns cursedNumber
      expect(e.cursedNumber, 18);
      expect(e.lastEventResolution?.detail,
          'A hidden number is now CURSED — hit it and it bites');
      expect(e.lastEventResolution?.detail, isNot(matches(RegExp(r'\d'))));

      final r = e.applyDart(18, 3); // hit the curse: T18 would be 54
      expect(r.points, -54);
      expect(e.cursedNumber, isNull); // clears once hit
    });

    test('DOUBLE JEOPARDY: sets a one-round flag; the NEXT round assigns 2 '
        'jokers regardless of wcJokerCount', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.debugForceEvent('doubleJeopardy');
      e.applyDart(1, 1); // hits the joker, fires DOUBLE JEOPARDY, re-rolls
      expect(e.jokers, {18}); // the usual per-hit reroll still happens
      expect(e.lastEventResolution?.detail, '2 jokers next round');
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; round is still 1
      expect(e.round, 1);
      expect(e.jokers, {18}); // unchanged until the round actually rolls over

      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 banks -> round 2 rolls over
      expect(e.round, 2);
      expect(e.jokers, {7, 19}); // forced to 2, not wcJokerCount(chaos)==1
    });
  });

  group('WildcardEngine lastBankedBonusKind (trinity/window outcome signal)',
      () {
    test('HOLY TRINITY completion sets lastBankedBonusKind to trinity', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      expect(e.lastBankedBonusKind, isNull);
      e.applyDart(5, 1);
      e.applyDart(20, 1);
      e.applyDart(1, 1); // completes the trinity -> +100
      expect(e.lastBankedBonusKind, WcBonusKind.trinity);
    });

    test('THE WINDOW prize sets lastBankedBonusKind to window', () {
      final e = plain()..debugForceModifier('theWindow');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls theWindow
      e.window = (lo: 40, hi: 60);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // total 60, inside [40, 60] -> flat 100
      expect(e.lastBankedBonusKind, WcBonusKind.window);
    });

    test(
        'THE WINDOW: a deferred bull (3rd dart) defers the bank until '
        'resolveBullChoice, and still sets lastBankedBonusKind to window '
        'when the total including the bull lands inside the bounds', () {
      final e = plain(players: 2)..debugForceModifier('theWindow');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls theWindow
      e.window = (lo: 40, hi: 60); // deterministic override for the test
      e.applyDart(15, 1);
      e.applyDart(15, 1); // 30 so far
      final r = e.applyDart(25, 1); // single bull: +25 -> total 55
      expect(r.needsBullChoice, isTrue);
      expect(r.turnEnded, isFalse); // bank deferred until the choice resolves
      expect(e.lastBankedBonusKind, isNull); // not banked yet
      e.resolveBullChoice(1);
      expect(e.totals[1], 100); // 55 is inside [40, 60] -> flat 100
      expect(e.lastBankedBonusKind, WcBonusKind.window);
    });

    test('a non-bonus bank leaves lastBankedBonusKind null', () {
      final e = plain();
      e.applyDart(5, 1);
      e.applyDart(5, 1);
      e.applyDart(5, 1); // plain bank, no bonus
      expect(e.lastBankedBonusKind, isNull);
    });

    test(
        "lastBankedBonusKind clears at the start of the NEXT player's first "
        'dart', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(5, 1);
      e.applyDart(20, 1);
      e.applyDart(1, 1); // P1 completes trinity -> bonus set
      expect(e.lastBankedBonusKind, WcBonusKind.trinity);
      e.applyDart(5, 1); // P2's first dart of the new turn
      expect(e.lastBankedBonusKind, isNull);
    });

    test('undo restores lastBankedBonusKind (snapshot-safe)', () {
      final e = plain()..debugForceModifier('holyTrinity');
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P0 banks; P1's turn rolls holyTrinity
      e.applyDart(5, 1);
      e.applyDart(20, 1);
      e.applyDart(1, 1); // completes the trinity
      expect(e.lastBankedBonusKind, WcBonusKind.trinity);
      e.undo(); // undoes the trinity-completing dart itself
      expect(e.lastBankedBonusKind, isNull);
    });
  });

  group('WildcardEngine CUT! and REWIND', () {
    test(
        'CUT!: current turn banks as-is; players yet to throw this round '
        'lose their turn; next round starts fresh', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.applyDart(5, 1);
      e.applyDart(5, 1); // 2 darts banked into turnPoints (10), P1/P2 untouched
      e.debugForceEvent('cutEvent');
      final r = e.applyDart(1, 1); // 3rd dart hits the joker -> CUT!
      expect(r.jokerHit, 1);
      expect(r.instantEvent?.id, 'cutEvent');
      expect(r.turnEnded, isTrue);
      expect(r.roundEnded, isTrue);
      expect(e.totals, [11, 0, 0]); // P0's turn banks as-is: 5+5+1
      expect(e.round, 2);
      expect(e.currentPlayerIndex, 0); // next round starts at the first seat
      expect(e.jokers, {19}); // fresh round-2 jokers, no reroll double-add
    });

    test('CUT! mid-turn (dart 1 of 3) still bank-and-cuts immediately', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.debugForceEvent('cutEvent');
      final r = e.applyDart(1, 1); // the very first dart of the turn
      expect(r.turnEnded, isTrue);
      expect(r.roundEnded, isTrue);
      expect(e.totals, [1, 0, 0]);
      expect(e.round, 2);
      expect(e.currentPlayerIndex, 0);
    });

    test('CUT! in the final round ends the game; totals stand', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 1, startingChaos: 3, rng: math.Random(7));
      e.debugForceEvent('cutEvent');
      final r = e.applyDart(1, 1);
      expect(r.gameOver, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.totals, [1, 0, 0]);
      expect(e.winnerIndex, 0);
    });

    test(
        'REWIND: wipes every player\'s this-round banked points back to '
        'roundStartTotals, discards the in-progress turn, restarts from the '
        'first seat; jokers are unchanged', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks 60; P1's turn begins
      expect(e.totals, [60, 0, 0]);
      expect(e.currentPlayerIndex, 1);
      expect(e.jokers, {1}); // same round -> same joker set (not re-rolled)

      e.debugForceEvent('rewindEvent');
      final r = e.applyDart(1, 1); // P1 hits the joker -> REWIND
      expect(r.turnEnded, isTrue);
      expect(r.roundEnded, isTrue);
      expect(e.totals, [0, 0, 0]); // P0's banked 60 is wiped
      expect(e.round, 1); // same round, restarted (not incremented)
      expect(e.currentPlayerIndex, 0); // back to the round's first seat
      expect(e.turnPoints, 0);
      expect(e.dartsInTurn, 0);
      expect(e.jokers, {1}); // untouched — only scores rewind
    });

    test('REWIND on round 1 restarts from zero scores for everyone', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks 60
      expect(e.totals, [60, 0]);
      e.debugForceEvent('rewindEvent');
      e.applyDart(1, 1); // P1 hits the joker -> REWIND
      expect(e.totals, [0, 0]);
      expect(e.currentPlayerIndex, 0);
      expect(e.round, 1);
    });

    test(
        'REWIND resolution lists every player wiped back to round-start '
        'totals', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks 60; P1's turn begins
      expect(e.totals, [60, 0]);
      e.debugForceEvent('rewindEvent');
      e.applyDart(1, 1); // P1 hits the joker -> REWIND
      expect(e.totals, [0, 0]);
      final ch = e.lastEventResolution!.scoreChanges;
      expect(ch.length, 2); // one row per living player
      expect(ch, [
        (playerIndex: 0, before: 60, after: 0),
        (playerIndex: 1, before: 0, after: 0),
      ]);
      for (final c in ch) {
        expect(c.after, e.roundStartTotals[c.playerIndex]); // restored
      }
    });
  });

  group('WildcardEngine undo across every event type', () {
    test('undo across joker+event restores meter, totals, joker set, and '
        're-hides the joker', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      expect(e.jokers, {1});
      expect(e.chaos, 3);
      e.debugForceEvent('chaosSurge');
      e.applyDart(1, 1);
      expect(e.jokers, {18});
      expect(e.chaos, 7); // 3 + 1 (joker, QA5) + 3 (surge)

      e.undo();
      expect(e.jokers, {1}); // re-hidden
      expect(e.chaos, 3);
      expect(e.jokersHitCount[0], 0);
      expect(e.lastEventResolution, isNull);
    });

    test('undo SCORE SWAP restores totals byte-for-byte', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 100;
      e.totals[1] = 40;
      e.totals[2] = 10;
      e.debugForceEvent('scoreSwap');
      e.applyDart(1, 1);
      expect(e.totals, [40, 100, 10]);

      e.undo();
      expect(e.totals, [100, 40, 10]);
      expect(e.jokers, {1});
    });

    test('undo ROBIN HOOD restores totals and pointsStolen', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 10;
      e.totals[1] = 300;
      e.totals[2] = 20;
      e.debugForceEvent('robinHood');
      e.applyDart(1, 1);
      expect(e.totals, [60, 250, 20]);
      expect(e.pointsStolen[0], 50);

      e.undo();
      expect(e.totals, [10, 300, 20]);
      expect(e.pointsStolen[0], 0);
    });

    test(
        'undo GIFT clears the redirect so a replayed dart banks to the '
        'thrower normally', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.totals[0] = 50; // hitter — not last, so the gift has a real target
      e.totals[2] = 5;
      e.applyDart(2, 1); // dart 1: 2 points
      e.debugForceEvent('gift');
      e.applyDart(1, 1); // dart 2: triggers GIFT

      e.undo(); // undo dart 2 -> the redirect must be gone
      e.debugForceEvent('chaosSurge'); // replay dart 2 without GIFT this time
      e.applyDart(1, 1);
      e.applyDart(7, 1); // dart 3 banks
      expect(e.totals, [60, 0, 5]); // all of it stays with P0, P2 untouched
    });

    test(
        'undo DOUBLE JEOPARDY leaves the next round at a normal joker '
        'count (the one-round flag does not leak)', () {
      final e = WildcardEngine(
          playerCount: 2, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.debugForceEvent('doubleJeopardy');
      e.applyDart(1, 1);
      e.undo();
      expect(e.jokers, {1});

      // Bank two plain turns to reach round 2 without ever re-forcing DJ.
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      e.applyDart(2, 1);
      expect(e.round, 2);
      expect(e.jokers, {7}); // normal chaos-3 count (1), not the forced 2
    });

    test('undo CUT! restores the pre-cut totals, round, seat and in-flight '
        'turn', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.applyDart(5, 1);
      e.applyDart(5, 1);
      e.debugForceEvent('cutEvent');
      e.applyDart(1, 1);
      expect(e.totals, [11, 0, 0]);
      expect(e.round, 2);

      e.undo();
      expect(e.totals, [0, 0, 0]);
      expect(e.round, 1);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 2);
      expect(e.turnPoints, 10);
      expect(e.jokers, {1});
    });

    test(
        'undo REWIND restores the pre-rewind totals, round-2-in-progress '
        'seat, and banked turn', () {
      final e = WildcardEngine(
          playerCount: 3, rounds: 5, startingChaos: 3, rng: math.Random(7));
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 banks 60
      e.debugForceEvent('rewindEvent');
      e.applyDart(1, 1); // P1 -> REWIND
      expect(e.totals, [0, 0, 0]);

      e.undo();
      expect(e.totals, [60, 0, 0]);
      expect(e.currentPlayerIndex, 1);
      expect(e.round, 1);
      expect(e.jokers, {1});
    });
  });

  group('WildcardEngine event drawing pool', () {
    test(
        'statistical sanity: at chaos 9-10 the wild tier is drawn roughly '
        'half the time (double-weighted per spec §3)', () {
      final rng = math.Random(42);
      final e = WildcardEngine(
          playerCount: 2, rounds: 200, startingChaos: 9, rng: rng);
      var wildCount = 0;
      var total = 0;
      for (var i = 0; i < 3000 && !e.gameOver && total < 200; i++) {
        if (e.jokers.isEmpty) {
          e.applyDart(5, 1);
          continue;
        }
        final j = e.jokers.first;
        final r = e.applyDart(j, 1);
        if (r.instantEvent != null) {
          total++;
          if (r.instantEvent!.severity == WcSeverity.wild) wildCount++;
        }
      }
      expect(total, greaterThan(50));
      final ratio = wildCount / total;
      expect(ratio, greaterThan(0.3));
      expect(ratio, lessThan(0.7));
    });
  });
}
