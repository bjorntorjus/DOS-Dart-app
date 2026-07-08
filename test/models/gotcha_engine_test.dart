import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/gotcha_engine.dart';

void main() {
  group('GotchaEngine core', () {
    test('players start at 0 and climb', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      expect(e.totals, [0, 0]);
      final r = e.applyDart(20, 3); // T20
      expect(r.points, 60);
      expect(e.totals[0], 60);
      expect(e.dartsInTurn, 1);
      expect(r.turnEnded, isFalse);
    });

    test('turn ends after 3 darts and rotation advances', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1);
      expect(r.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartsInTurn, 0);
      expect(e.turnStartScore, 0); // next player's turn baseline
    });

    test('exact target wins immediately', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3);
      e.applyDart(20, 2); // 100
      final r = e.applyDart(1, 1); // 101
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      // Game is frozen at the winning state — turn advance is skipped when
      // gameOver, so the darts-in-turn counter and seat are left as-is.
      expect(e.dartsInTurn, 3);
      expect(e.currentPlayerIndex, 0);
    });

    test('overshoot busts: revert to turn start, turn ends, bust counted', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); // 60
      final r = e.applyDart(20, 3); // 120 > 101 → bust
      expect(r.isBust, isTrue);
      expect(r.turnEnded, isTrue);
      expect(e.totals[0], 0); // reverted to turn start (0)
      expect(e.busts[0], 1);
      expect(e.currentPlayerIndex, 1);
    });

    test('bust reverts to score at START of turn, not previous dart', () {
      final e = GotchaEngine(target: 201, playerCount: 2);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 = 60, turn ends
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 = 3, turn ends, back to P0
      e.applyDart(20, 3); // P0 = 120 (not bust)
      e.applyDart(20, 3); // P0 = 180 (not bust)
      final result = e.applyDart(19, 3); // P0 = 237 > 201 → bust
      expect(result.isBust, isTrue);
      expect(e.totals[0], 60); // start-of-turn baseline, NOT 180
      expect(e.busts[0], 1);
      expect(e.currentPlayerIndex, 1);
    });

    test('snapshot undo restores everything', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); // 60
      final r = e.applyDart(20, 3); // bust → 0, seat advanced
      expect(r.isBust, isTrue);
      e.undo();
      expect(e.totals[0], 60);
      expect(e.busts[0], 0);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 1);
      e.undo();
      expect(e.totals[0], 0);
      expect(e.canUndo, isFalse);
      e.undo(); // empty stack: silent no-op
      expect(e.totals[0], 0);
    });

    test('undo across a win reopens the game', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3);
      e.applyDart(20, 2);
      e.applyDart(1, 1); // win
      expect(e.gameOver, isTrue);
      e.undo();
      expect(e.gameOver, isFalse);
      expect(e.winnerIndex, isNull);
      expect(e.totals[0], 100);
    });

    test('miss (0 points) consumes a dart, cannot bust', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      final r = e.applyDart(0, 0);
      expect(r.points, 0);
      expect(r.isBust, isFalse);
      expect(e.dartsInTurn, 1);
    });
  });
}
