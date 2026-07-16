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
