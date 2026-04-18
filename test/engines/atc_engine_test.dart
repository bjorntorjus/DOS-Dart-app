import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/engines/atc_engine.dart';

void main() {
  // ---------------------------------------------------------------------------
  // isFinished
  // ---------------------------------------------------------------------------
  group('isFinished', () {
    test('forward: not finished at target 1', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.isFinished(1), isFalse);
    });

    test('forward: not finished at target 20', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.isFinished(20), isFalse);
    });

    test('forward: finished at 21 (past 20)', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.isFinished(21), isTrue);
    });

    test('forward with bull: not finished at 25', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.isFinished(25), isFalse);
    });

    test('forward with bull: finished at 26', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.isFinished(26), isTrue);
    });

    test('reverse: not finished at 20', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.isFinished(20), isFalse);
    });

    test('reverse: finished at 0 (below 1)', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.isFinished(0), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // advanceTarget — forward
  // ---------------------------------------------------------------------------
  group('advanceTarget — forward', () {
    test('advances from 1 to 2', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.advanceTarget(1), 2);
    });

    test('advances from 19 to 20', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.advanceTarget(19), 20);
    });

    test('advances from 20 to 21 (finished) without bull', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.advanceTarget(20), 21);
    });

    test('advances from 20 to 25 (Bull) with includeBull', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.advanceTarget(20), 25);
    });

    test('advances from 25 to 26 (finished) after Bull', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.advanceTarget(25), 26);
    });
  });

  // ---------------------------------------------------------------------------
  // advanceTarget — reverse
  // ---------------------------------------------------------------------------
  group('advanceTarget — reverse', () {
    test('advances from 20 to 19', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.advanceTarget(20), 19);
    });

    test('advances from 2 to 1', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.advanceTarget(2), 1);
    });

    test('advances from 1 to 0 (finished)', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.advanceTarget(1), 0);
    });

    test('reverse with bull: 25 → 20', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true, includeBull: true),
          playerCount: 1);
      expect(e.advanceTarget(25), 20);
    });
  });

  // ---------------------------------------------------------------------------
  // segmentsRemaining
  // ---------------------------------------------------------------------------
  group('segmentsRemaining', () {
    test('0 remaining when finished', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.segmentsRemaining(21), 0);
    });

    test('20 remaining at start (target 1, no bull)', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.segmentsRemaining(1), 20);
    });

    test('1 remaining at target 20 (no bull)', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      expect(e.segmentsRemaining(20), 1);
    });

    test('21 remaining at target 1 with bull', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.segmentsRemaining(1), 21);
    });

    test('1 remaining at Bull with includeBull', () {
      final e = ATCEngine(
          config: const ATCConfig(includeBull: true), playerCount: 1);
      expect(e.segmentsRemaining(25), 1);
    });

    test('reverse: 20 remaining at start target 20', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.segmentsRemaining(20), 20);
    });

    test('reverse: 1 remaining at target 1', () {
      final e = ATCEngine(
          config: const ATCConfig(reverse: true), playerCount: 1);
      expect(e.segmentsRemaining(1), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // applyHit — basic hit/miss
  // ---------------------------------------------------------------------------
  group('applyHit — hit and miss', () {
    test('hit advances target', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      final result = e.applyHit(1, 1); // hit target 1
      expect(result.isHit, isTrue);
      expect(result.newTarget, 2);
      expect(e.currentTargets[0], 2);
    });

    test('miss does not advance target', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      final result = e.applyHit(5, 1); // miss (target is 1)
      expect(result.isHit, isFalse);
      expect(e.currentTargets[0], 1);
    });

    test('miss with segment 0 does not advance target', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      final result = e.applyHit(0, 0);
      expect(result.isHit, isFalse);
      expect(e.currentTargets[0], 1);
    });
  });

  // ---------------------------------------------------------------------------
  // applyHit — countMultiples
  // ---------------------------------------------------------------------------
  group('applyHit — countMultiples', () {
    test('triple advances 3 steps with countMultiples', () {
      final e = ATCEngine(
          config: const ATCConfig(countMultiples: true), playerCount: 1);
      // Target is 1, triple 1 → advance 3 steps to target 4
      final result = e.applyHit(1, 3);
      expect(result.isHit, isTrue);
      expect(e.currentTargets[0], 4);
    });

    test('triple advances 1 step without countMultiples', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      final result = e.applyHit(1, 3);
      expect(result.isHit, isTrue);
      expect(e.currentTargets[0], 2); // only 1 step
    });

    test('double advances 2 steps with countMultiples', () {
      final e = ATCEngine(
          config: const ATCConfig(countMultiples: true), playerCount: 1);
      final result = e.applyHit(1, 2);
      expect(result.isHit, isTrue);
      expect(e.currentTargets[0], 3);
    });
  });

  // ---------------------------------------------------------------------------
  // applyHit — finishing
  // ---------------------------------------------------------------------------
  group('applyHit — finishing', () {
    test('hitting last target marks player as finished', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.currentTargets[0] = 20; // one target left
      final result = e.applyHit(20, 1);
      expect(result.playerFinished, isTrue);
      expect(e.finishedPlayers, contains(0));
    });

    test('game is over when only player finishes', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 1);
      e.currentTargets[0] = 20;
      e.applyHit(20, 1);
      expect(e.gameOver, isTrue);
    });

    test('game ends and P1 is placed when P1 cannot match P0 finish', () {
      // P0 finishes in 1 dart; P1 is at target 1 (20 segments left).
      // P1 cannot possibly finish in 1 dart, so the round resolves immediately
      // and the game is over with P0 as winner.
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.currentTargets[0] = 20; // P0 has 1 segment left
      // P1 starts at target 1 (20 segments left — impossible in 1 dart)
      e.applyHit(20, 1);
      expect(e.winnerIndex, 0);
      expect(e.gameOver, isTrue);
    });

    test('turn advances to next player after 3 misses', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.applyHit(0, 0);
      e.applyHit(0, 0);
      final result = e.applyHit(0, 0);
      expect(result.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // isRoundComplete / canAnyRemainingPlayerFinish
  // ---------------------------------------------------------------------------
  group('isRoundComplete', () {
    test('returns true when all players have thrown', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.playersCompletedThisRound.addAll([0, 1]);
      expect(e.isRoundComplete(), isTrue);
    });

    test('returns false when a player has not thrown', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.playersCompletedThisRound.add(0);
      expect(e.isRoundComplete(), isFalse);
    });

    test('skips players finished in a previous round', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.finishedBeforeRound.add(0); // P0 finished last round
      e.playersCompletedThisRound.add(1); // only P1 needs to throw
      expect(e.isRoundComplete(), isTrue);
    });
  });

  group('canAnyRemainingPlayerFinish', () {
    test('returns false when remaining player too far behind', () {
      // P0 finished in 1 dart; P1 has 10 segments left — can't finish in 1 dart
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.finishedPlayers.add(0);
      e.playersCompletedThisRound.add(0);
      e.currentTargets[1] = 11; // 10 segments remain
      expect(e.canAnyRemainingPlayerFinish(1), isFalse);
    });

    test('returns true when remaining player can still finish', () {
      final e = ATCEngine(config: const ATCConfig(), playerCount: 2);
      e.finishedPlayers.add(0);
      e.playersCompletedThisRound.add(0);
      e.currentTargets[1] = 20; // 1 segment left — can finish in 1 dart
      expect(e.canAnyRemainingPlayerFinish(1), isTrue);
    });

    test('with countMultiples, triple can cover 3 segments in 1 dart', () {
      final e = ATCEngine(
          config: const ATCConfig(countMultiples: true), playerCount: 2);
      e.finishedPlayers.add(0);
      e.playersCompletedThisRound.add(0);
      e.currentTargets[1] = 18; // 3 segments left — reachable with triple in 1 dart
      expect(e.canAnyRemainingPlayerFinish(1), isTrue);
    });
  });
}
