import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/engines/x01_engine.dart';

void main() {
  // ---------------------------------------------------------------------------
  // isBust — double-out
  // ---------------------------------------------------------------------------
  group('isBust — double-out', () {
    test('negative score is a bust', () {
      expect(
        X01Engine.computeIsBust(10, 20, 1, 'double'), // 10 - 20 = -10
        isTrue,
      );
    });

    test('checkout with single is a bust', () {
      expect(
        X01Engine.computeIsBust(20, 20, 1, 'double'), // score reaches 0 but single
        isTrue,
      );
    });

    test('checkout with double is valid', () {
      expect(
        X01Engine.computeIsBust(40, 20, 2, 'double'), // D20 checks out from 40
        isFalse,
      );
    });

    test('checkout with triple is a bust in double-out', () {
      expect(
        X01Engine.computeIsBust(60, 20, 3, 'double'), // T20 would check out but triple not valid
        isTrue,
      );
    });

    test('score of 1 remaining is a bust', () {
      expect(
        X01Engine.computeIsBust(10, 9, 1, 'double'), // leaves 1
        isTrue,
      );
    });

    test('normal hit that leaves valid score is not a bust', () {
      expect(
        X01Engine.computeIsBust(100, 20, 1, 'double'), // leaves 80
        isFalse,
      );
    });

    test('bull checkout (D25=50) is valid in double-out', () {
      expect(
        X01Engine.computeIsBust(50, 25, 2, 'double'), // Bull checks out from 50
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isBust — master-out
  // ---------------------------------------------------------------------------
  group('isBust — master-out', () {
    test('checkout with triple is valid in master-out', () {
      expect(
        X01Engine.computeIsBust(60, 20, 3, 'master'),
        isFalse,
      );
    });

    test('checkout with single is a bust in master-out', () {
      expect(
        X01Engine.computeIsBust(20, 20, 1, 'master'),
        isTrue,
      );
    });

    test('checkout with double is valid in master-out', () {
      expect(
        X01Engine.computeIsBust(40, 20, 2, 'master'),
        isFalse,
      );
    });

    test('score of 1 remaining is a bust in master-out', () {
      expect(
        X01Engine.computeIsBust(10, 9, 1, 'master'),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isBust — free-out (no restriction)
  // ---------------------------------------------------------------------------
  group('isBust — free-out (none)', () {
    test('negative score is a bust', () {
      expect(X01Engine.computeIsBust(10, 20, 1, 'none'), isTrue);
    });

    test('single checkout is valid in free-out', () {
      expect(X01Engine.computeIsBust(20, 20, 1, 'none'), isFalse);
    });

    test('score of 1 remaining is NOT a bust in free-out', () {
      expect(X01Engine.computeIsBust(10, 9, 1, 'none'), isFalse);
    });

    test('score of 0 from any dart is valid in free-out', () {
      expect(X01Engine.computeIsBust(60, 20, 3, 'none'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // maxCheckoutForDarts
  // ---------------------------------------------------------------------------
  group('maxCheckoutForDarts', () {
    test('double-out: 1 dart max is 50 (Bull)', () {
      expect(X01Engine.computeMaxCheckoutForDarts(1, 'double'), 50);
    });

    test('double-out: 2 darts max is 110', () {
      expect(X01Engine.computeMaxCheckoutForDarts(2, 'double'), 110);
    });

    test('double-out: 3 darts max is 170', () {
      expect(X01Engine.computeMaxCheckoutForDarts(3, 'double'), 170);
    });

    test('master-out: 1 dart max is 60 (T20)', () {
      expect(X01Engine.computeMaxCheckoutForDarts(1, 'master'), 60);
    });

    test('master-out: 3 darts max is 180', () {
      expect(X01Engine.computeMaxCheckoutForDarts(3, 'master'), 180);
    });
  });

  // ---------------------------------------------------------------------------
  // compareCheckouts
  // ---------------------------------------------------------------------------
  group('compareCheckouts', () {
    test('fewer darts wins', () {
      final a = PendingCheckout(playerIndex: 0, dartsUsedInTurn: 1, checkoutScore: 40);
      final b = PendingCheckout(playerIndex: 1, dartsUsedInTurn: 2, checkoutScore: 40);
      expect(X01Engine.compareCheckouts(a, b), isNegative); // a wins
    });

    test('with equal darts, higher checkout score wins', () {
      final a = PendingCheckout(playerIndex: 0, dartsUsedInTurn: 2, checkoutScore: 170);
      final b = PendingCheckout(playerIndex: 1, dartsUsedInTurn: 2, checkoutScore: 80);
      expect(X01Engine.compareCheckouts(a, b), isNegative); // a wins
    });

    test('identical darts and score is a tie', () {
      final a = PendingCheckout(playerIndex: 0, dartsUsedInTurn: 2, checkoutScore: 100);
      final b = PendingCheckout(playerIndex: 1, dartsUsedInTurn: 2, checkoutScore: 100);
      expect(X01Engine.compareCheckouts(a, b), 0);
    });

    test('more darts loses even with higher checkout score', () {
      final a = PendingCheckout(playerIndex: 0, dartsUsedInTurn: 3, checkoutScore: 170);
      final b = PendingCheckout(playerIndex: 1, dartsUsedInTurn: 1, checkoutScore: 40);
      expect(X01Engine.compareCheckouts(a, b), isPositive); // b wins
    });
  });

  // ---------------------------------------------------------------------------
  // isRoundComplete
  // ---------------------------------------------------------------------------
  group('isRoundComplete', () {
    test('returns true when all players have completed their turn', () {
      final engine = X01Engine(masterOut: 'none', initialScores: [301, 301, 301]);
      engine.playersCompletedThisRound.addAll([0, 1, 2]);
      expect(engine.isRoundComplete(), isTrue);
    });

    test('returns false when a player has not yet thrown', () {
      final engine = X01Engine(masterOut: 'none', initialScores: [301, 301, 301]);
      engine.playersCompletedThisRound.addAll([0, 1]);
      expect(engine.isRoundComplete(), isFalse);
    });

    test('skips players in finishedBeforeRound', () {
      // Player 2 finished last round — should not block round completion
      final engine = X01Engine(masterOut: 'none', initialScores: [301, 301, 0]);
      engine.finishedBeforeRound.add(2);
      engine.playersCompletedThisRound.addAll([0, 1]);
      expect(engine.isRoundComplete(), isTrue);
    });

    test('BUG FIX: skips players removed mid-game (in finishedPlayers but not finishedBeforeRound)', () {
      // Player 2 was added to finishedPlayers mid-round (removed or checked out same round).
      // Before the fix, isRoundComplete would wait for them to throw.
      final engine = X01Engine(masterOut: 'none', initialScores: [100, 100, 0]);
      engine.finishedPlayers.add(2); // mid-game remove — NOT in finishedBeforeRound
      engine.playersCompletedThisRound.addAll([0, 1]);
      expect(engine.isRoundComplete(), isTrue);
    });

    test('does not complete if active player has not thrown', () {
      final engine = X01Engine(masterOut: 'none', initialScores: [100, 100, 0]);
      engine.finishedBeforeRound.add(2);
      engine.playersCompletedThisRound.add(0); // only player 0 done
      expect(engine.isRoundComplete(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // canAnyRemainingPlayerCheckout
  // ---------------------------------------------------------------------------
  group('canAnyRemainingPlayerCheckout', () {
    test('returns true when a remaining player can match checkout in given darts', () {
      final engine = X01Engine(masterOut: 'double', initialScores: [40, 170]);
      engine.finishedPlayers.add(0); // P0 checked out in 1 dart
      engine.playersCompletedThisRound.add(0);
      // P1 has 170 — can they check out in 1 dart? Max with double-out is 50. No.
      expect(engine.canAnyRemainingPlayerCheckout(1), isFalse);
    });

    test('returns true when remaining player score fits within dart budget', () {
      final engine = X01Engine(masterOut: 'double', initialScores: [40, 40]);
      engine.finishedPlayers.add(0);
      engine.playersCompletedThisRound.add(0);
      // P1 has 40 — fits within 1-dart double-out max of 50
      expect(engine.canAnyRemainingPlayerCheckout(1), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Full game flow
  // ---------------------------------------------------------------------------
  group('applyThrow — game flow', () {
    test('hit reduces score', () {
      final engine = X01Engine(masterOut: 'none', initialScores: [301]);
      engine.applyThrow(20, 1); // single 20
      expect(engine.scores[0], 281);
    });

    test('bust resets score to start of turn', () {
      final engine = X01Engine(masterOut: 'double', initialScores: [30]);
      engine.applyThrow(20, 1); // leaves 10 — not a bust
      // Now score is 10, try to overshoot
      final result = engine.applyThrow(20, 1); // 10 - 20 = -10 → bust
      expect(result, X01ThrowResult.bust);
      expect(engine.scores[0], 30); // reset to start of turn
    });

    test('checkout adds player to finishedPlayers', () {
      final engine = X01Engine(masterOut: 'double', initialScores: [40]);
      final result = engine.applyThrow(20, 2); // D20 = checkout from 40
      expect(result, X01ThrowResult.checkout);
      expect(engine.finishedPlayers, contains(0));
      expect(engine.scores[0], 0);
    });

    test('turn advances after 3 darts', () {
      final engine =
          X01Engine(masterOut: 'none', initialScores: [501, 501]);
      engine.applyThrow(20, 1);
      engine.applyThrow(20, 1);
      engine.applyThrow(20, 1); // 3rd dart → turn ends
      expect(engine.currentPlayerIndex, 1); // now P1's turn
      expect(engine.dartsInTurn, 0);
    });

    test('bust in double-out when single hits 0', () {
      final engine = X01Engine(masterOut: 'double', initialScores: [20]);
      final result = engine.applyThrow(20, 1); // single 20 from 20 → bust
      expect(result, X01ThrowResult.bust);
    });

    test('two players — checkout adds to pendingCheckouts', () {
      final engine =
          X01Engine(masterOut: 'none', initialScores: [20, 200]);
      engine.applyThrow(20, 1); // P0 checks out
      expect(engine.pendingCheckouts.length, 1);
      expect(engine.pendingCheckouts.first.playerIndex, 0);
      expect(engine.pendingCheckouts.first.dartsUsedInTurn, 1);
      expect(engine.pendingCheckouts.first.checkoutScore, 20);
    });

    test('resolveCheckouts sorts by fewest darts then highest score', () {
      final engine =
          X01Engine(masterOut: 'none', initialScores: [100, 60, 170]);
      // Simulate two pending checkouts
      engine.pendingCheckouts.addAll([
        PendingCheckout(playerIndex: 1, dartsUsedInTurn: 2, checkoutScore: 60),
        PendingCheckout(playerIndex: 2, dartsUsedInTurn: 2, checkoutScore: 170),
        PendingCheckout(playerIndex: 0, dartsUsedInTurn: 1, checkoutScore: 100),
      ]);
      final sorted = engine.resolveCheckouts();
      // P0 wins: 1 dart. Then P2 (170 > 60 with equal darts). Then P1.
      expect(sorted[0].playerIndex, 0);
      expect(sorted[1].playerIndex, 2);
      expect(sorted[2].playerIndex, 1);
    });
  });
}
