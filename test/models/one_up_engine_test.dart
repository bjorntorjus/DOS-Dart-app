import 'dart:math';

import 'package:dart_scoring/models/one_up_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OneUpEngine BEAT THE LAST core', () {
    test('game opens with a free throw that sets the target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      expect(e.isFreeThrow, isTrue);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1); // 60
      expect(r.turnEnded, isTrue);
      expect(r.lostLife, isFalse);
      expect(e.target, 60);
      expect(e.targetSetBy, 0);
      expect(e.targetsSet[0], 1);
      expect(e.currentPlayerIndex, 1);
      expect(e.isFreeThrow, isFalse);
    });

    test('tie = success: equal total is safe, target unchanged', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60); // P0 free: target 60
      final r = _turn(e, 60); // P1 ties
      expect(r.lostLife, isFalse);
      expect(e.livesLeft, [3, 3]);
      expect(e.target, 60);
    });

    test('beat: total becomes the new target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      _turn(e, 100);
      expect(e.target, 100);
      expect(e.targetSetBy, 1);
    });

    test('fail: lose a life AND the lower total becomes the target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      final r = _turn(e, 40);
      expect(r.lostLife, isTrue);
      expect(e.livesLeft, [3, 2]);
      expect(e.target, 40); // self-correcting bar
      expect(e.targetSetBy, 1);
      expect(e.livesLost[1], 1);
    });

    test('a 0 target cannot be failed (three misses then anything)', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 0); // free throw of 0
      final r = _turn(e, 0); // ties 0 → safe
      expect(r.lostLife, isFalse);
      expect(e.livesLeft, [3, 3]);
    });

    test('elimination + placement order + last alive wins', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);          // P0 sets 100
      var r = _turn(e, 50);   // P1 fails → 0 lives → out
      expect(r.eliminated, isTrue);
      expect(r.playerWon, isFalse);
      expect(e.eliminationOrder, [1]);
      r = _turn(e, 40);       // P2 fails vs 50 → out → P0 wins
      expect(r.eliminated, isTrue);
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      expect(e.eliminationOrder, [1, 2]);
    });

    test('eliminated player is skipped in rotation, their throw stays the target', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);
      _turn(e, 50); // P1 out, target now 50
      expect(e.target, 50);
      expect(e.currentPlayerIndex, 2);
      _turn(e, 60); // P2 beats
      expect(e.currentPlayerIndex, 0); // P1 skipped
    });

    test('undo restores lives, target and elimination', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 1);
      _turn(e, 100);
      _turn(e, 40); // P1 out, P0 wins
      expect(e.gameOver, isTrue);
      e.undo(); // rewind last dart
      expect(e.gameOver, isFalse);
      expect(e.livesLeft[1], 1);
      expect(e.eliminationOrder, isEmpty);
      expect(e.target, 100);
      expect(e.dartsInTurn, 2);
    });

    test('helper getters: needed / canStillBeat / hasBeatenTarget', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 150);
      e.applyDart(10, 1); // turnPoints 10, 2 darts left, need 140
      expect(e.needed, 140);
      expect(e.canStillBeat, isFalse); // 140 > 120
      e.applyDart(20, 3);
      e.applyDart(20, 3);
      expect(e.hasBeatenTarget, isFalse); // 130 < 150 — turn already resolved
    });

    test('saved on last dart counts', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      e.applyDart(20, 1);
      e.applyDart(20, 1);       // 40 — still below
      e.applyDart(20, 3);       // 100 → tie on the last dart
      expect(e.lastDartSaves[1], 1);
    });

    test('highest turn and turns survived tracked', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      _turn(e, 100);
      expect(e.highestTurn, [60, 100]);
      expect(e.turnsSurvived, [1, 1]);
    });
  });

  group('OneUpEngine SURVIVOR', () {
    OneUpEngine survivor(int players, int lives,
            {bool randomOrder = false, Random? rng}) =>
        OneUpEngine(
            playerCount: players, startingLives: lives,
            variant: OneUpVariant.survivor,
            randomOrder: randomOrder, rng: rng);

    test('rotation loops within the round without advancing roundNumber', () {
      final e = survivor(3, 3);
      _turn(e, 60);  // P0 free-sets 60
      _turn(e, 100); // P1 raises
      _turn(e, 120); // P2 raises → back to P0
      expect(e.currentPlayerIndex, 0);
      expect(e.roundNumber, 1); // same round — the rotation wrapped
      expect(e.target, 120);
    });

    test('fail ejects from the round without lowering the target', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 free-sets 100
      final r = _turn(e, 40); // P1 fails
      expect(r.lostLife, isTrue);
      expect(e.livesLeft[1], 2);
      expect(e.isOutOfRound(1), isTrue);
      expect(e.target, 100); // unchanged — the failer's total is discarded
      expect(e.currentPlayerIndex, 2); // P2 next
    });

    test('round winner without throwing (everyone else fails)', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 sets 100
      _turn(e, 40);  // P1 fails → out
      _turn(e, 40);  // P2 fails → out → P0 wins the round unopposed
      expect(e.roundsWon[0], 1);
      expect(e.roundNumber, 2);
      expect(e.target, isNull);          // new round → free throw
      expect(e.outOfRoundIndices, isEmpty);
      expect(e.currentPlayerIndex, 1);   // round 2 starter rotates to seat 1
      expect(e.livesLeft[0], 3);         // winner lost no life
    });

    test('duel: two players raise the bar until one falls short', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 sets 100
      _turn(e, 40);  // P1 fails → out
      _turn(e, 120); // P2 raises
      _turn(e, 140); // P0 raises
      final r = _turn(e, 40); // P2 fails vs 140 → P0 wins the round
      expect(r.roundWonBy, 0);
      expect(e.roundsWon[0], 1);
      expect(e.livesLeft[0], 3); // P0 intact
      expect(e.livesLeft[1], 2); // P1 −1
      expect(e.livesLeft[2], 2); // P2 −1
    });

    test('tie is safe and keeps the target owner', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 free-sets 100, owner 0
      final r = _turn(e, 100); // P1 ties
      expect(r.lostLife, isFalse);
      expect(e.livesLeft, [3, 3, 3]);
      expect(e.isOutOfRound(1), isFalse); // stays in the round
      expect(e.target, 100);
      expect(e.targetSetBy, 0); // tie does NOT transfer ownership
    });

    test('a survivor fail can eliminate and end the game', () {
      final e = survivor(2, 1);
      _turn(e, 100); // P0 free-sets 100
      final r = _turn(e, 40); // P1 fails → 0 lives → out → game over
      expect(r.eliminated, isTrue);
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      expect(e.roundsWon[0], 1); // survivor is credited the round too
    });

    test('undo across a round end restores target / out-of-round / rounds', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 sets 100
      _turn(e, 40);  // P1 fails → out {1}
      _turn(e, 40);  // P2 fails → round ends, P0 wins
      expect(e.roundNumber, 2);
      expect(e.roundsWon[0], 1);
      e.undo(); // rewind P2's 3rd (final) dart
      expect(e.roundNumber, 1);
      expect(e.target, 100);
      expect(e.roundsWon[0], 0);
      expect(e.isOutOfRound(1), isTrue);  // P1 still out
      expect(e.isOutOfRound(2), isFalse); // P2's fail is rolled back
      expect(e.dartsInTurn, 2);
    });

    test('removePlayer leaving one in-round ends the round', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 sets 100
      _turn(e, 40);  // P1 fails → out; P2 to throw
      e.removePlayer(2);
      expect(e.roundsWon[0], 1); // P0 is the only one left in-round
      expect(e.roundNumber, 2);
      expect(e.isSkipped(2), isTrue);
      expect(e.canUndo, isFalse); // roster op cleared the stack
    });

    test('addPlayer does not block round completion', () {
      final e = survivor(3, 3);
      _turn(e, 100); // P0 sets 100
      e.addPlayer();  // seat 3 added mid-round (not in the current order)
      expect(e.playerCount, 4);
      _turn(e, 40);  // P1 fails → out
      _turn(e, 40);  // P2 fails → only original P0 remains → round ends
      expect(e.roundsWon[0], 1);
      expect(e.roundNumber, 2);
      expect(e.roundOrder.contains(3), isTrue); // new seat joins round 2
    });

    test('shuffle rebuilds the order from alive seats at each round', () {
      final e = survivor(3, 3, randomOrder: true, rng: Random(42));
      final round1 = List.of(e.roundOrder);
      _turn(e, 100); // first thrower of round 1 free-sets 100
      _turn(e, 0);   // next in order fails → out
      _turn(e, 0);   // next fails → out → round ends
      expect(e.roundNumber, 2);
      final round2 = List.of(e.roundOrder);
      expect(round2.toSet(), {0, 1, 2}); // rebuilt from all alive seats
      expect(e.outOfRoundIndices, isEmpty);
      expect(e.target, isNull);
      // A fresh shuffle is drawn each round; with seed 42 the orders differ.
      expect(round2, isNot(equals(round1)));
    });
  });

  group('OneUpEngine shuffle + roster', () {
    test('randomOrder reshuffles alive players each round (seeded)', () {
      final e = OneUpEngine(
          playerCount: 4, startingLives: 3, randomOrder: true,
          rng: Random(42));
      final round1 = List.of(e.roundOrder);
      for (var i = 0; i < 12; i++) { e.applyDart(1, 1); } // 4 turns → round 2
      expect(e.roundNumber, 2);
      final round2 = List.of(e.roundOrder);
      expect(round2.toSet(), {0, 1, 2, 3});
      // With seed 42 the two orders differ; if this ever collides, bump the seed.
      expect(round2, isNot(equals(round1)));
    });

    test('shuffled order is restored by undo', () {
      final e = OneUpEngine(
          playerCount: 3, startingLives: 3, randomOrder: true,
          rng: Random(7));
      final round1 = List.of(e.roundOrder);
      for (var i = 0; i < 9; i++) { e.applyDart(1, 1); } // → round 2
      final round2 = List.of(e.roundOrder);
      e.undo(); // back into round 1's last turn
      expect(e.roundNumber, 1);
      expect(e.roundOrder, round1); // the ROUND-1 order is byte-restored
      e.applyDart(1, 1); // redo the dart → round 2 again
      // The re-shuffle draws fresh randomness, so identity with the first
      // round-2 order is NOT guaranteed — only membership:
      expect(e.roundNumber, 2);
      expect(e.roundOrder.toSet(), round2.toSet());
    });

    test('addPlayer joins from the next round with full lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      e.addPlayer();
      expect(e.playerCount, 3);
      expect(e.livesLeft[2], 3);
      expect(e.roundOrder.contains(2), isFalse); // not in current round
      expect(e.canUndo, isFalse); // roster change cleared the stack
      _turn(e, 100); // P1 finishes the round
      expect(e.roundOrder.contains(2), isTrue); // in from round 2
    });

    test('removePlayer: current thrower removed → in-progress turn discarded, target unchanged', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 3);
      _turn(e, 100); // P0 sets 100
      e.applyDart(20, 3); // P1 starts a turn
      e.removePlayer(1);
      expect(e.currentPlayerIndex, 2);
      expect(e.turnPoints, 0);
      expect(e.dartsInTurn, 0);
      expect(e.target, 100); // just a number — stays
      expect(e.canUndo, isFalse);
    });

    test('removing down to one alive player ends the game (survivor wins)', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);
      _turn(e, 40); // P1 eliminated
      e.removePlayer(0);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 2); // removed player never wins
    });

    test('a removed player is never the winner', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      e.removePlayer(0); // the leader leaves
      expect(e.winnerIndex, 1);
      expect(e.isSkipped(0), isTrue);
    });
  });
}

/// Throws one full 3-dart turn totalling [total]: greedy T20s, then the
/// remainder as one dart, then misses. Works for any total 0-180 whose
/// remainder after 60s is a single (≤20), 25, 50, an even ≤40, or a
/// multiple of 3 ≤ 60 — asserts otherwise.
OneUpDartResult _turn(OneUpEngine e, int total) {
  var remaining = total;
  var r = const OneUpDartResult(
      points: 0, turnEnded: false, lostLife: false,
      eliminated: false, playerWon: false);
  for (var d = 0; d < 3; d++) {
    final v = remaining >= 60 ? 60 : remaining;
    remaining -= v;
    r = _dart(e, v);
  }
  assert(remaining == 0, 'total $total not expressible in 3 darts');
  return r;
}

OneUpDartResult _dart(OneUpEngine e, int points) {
  if (points == 0) return e.applyDart(0, 1);          // miss
  if (points <= 20) return e.applyDart(points, 1);
  if (points == 25) return e.applyDart(25, 1);        // bull
  if (points == 50) return e.applyDart(25, 2);        // double bull
  if (points % 3 == 0 && points <= 60) return e.applyDart(points ~/ 3, 3);
  if (points % 2 == 0 && points <= 40) return e.applyDart(points ~/ 2, 2);
  throw ArgumentError('inexpressible dart: $points');
}
