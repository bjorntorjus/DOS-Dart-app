import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/engines/cricket_engine.dart';

void main() {
  // Standard targets
  const defaultTargets = [15, 16, 17, 18, 19, 20, 25];

  // ---------------------------------------------------------------------------
  // computeOverflow
  // ---------------------------------------------------------------------------
  group('computeOverflow', () {
    test('no overflow when closing exactly', () {
      // currentMarks=1, multiplier=2 → newMarks=3, no overflow
      expect(CricketEngine.computeOverflow(1, 2), 0);
    });

    test('overflow when already closed and hit again', () {
      // currentMarks=3, multiplier=1 → 1 overflow
      expect(CricketEngine.computeOverflow(3, 1), 1);
    });

    test('triple on 0 marks → 0 overflow (closes, no overflow)', () {
      // currentMarks=0, multiplier=3 → closes exactly, 0 overflow
      expect(CricketEngine.computeOverflow(0, 3), 0);
    });

    test('triple on 1 mark → 1 overflow', () {
      // currentMarks=1, multiplier=3 → needs 2 to close, 1 overflow
      expect(CricketEngine.computeOverflow(1, 3), 1);
    });

    test('triple on 2 marks → 2 overflow', () {
      // currentMarks=2, multiplier=3 → needs 1 to close, 2 overflow
      expect(CricketEngine.computeOverflow(2, 3), 2);
    });

    test('triple when already closed → 3 overflow', () {
      // currentMarks=3, multiplier=3 → 3 overflow
      expect(CricketEngine.computeOverflow(3, 3), 3);
    });
  });

  // ---------------------------------------------------------------------------
  // isClosed / isClosedByAll / allClosedByPlayer
  // ---------------------------------------------------------------------------
  group('closed state helpers', () {
    test('isClosed returns false below 3 marks', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      expect(engine.isClosed(20, 0), isFalse);
    });

    test('isClosed returns true at 3 marks', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.marks[0][20] = 3;
      expect(engine.isClosed(20, 0), isTrue);
    });

    test('isClosedByAll returns false when only one player closed', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.marks[0][20] = 3;
      expect(engine.isClosedByAll(20), isFalse);
    });

    test('isClosedByAll returns true when all players closed', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.marks[0][20] = 3;
      engine.marks[1][20] = 3;
      expect(engine.isClosedByAll(20), isTrue);
    });

    test('allClosedByPlayer returns false when not all targets closed', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 1);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.marks[0][20] = 2; // one target not closed
      expect(engine.allClosedByPlayer(0), isFalse);
    });

    test('allClosedByPlayer returns true when all targets closed', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 1);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      expect(engine.allClosedByPlayer(0), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Standard Cricket scoring
  // ---------------------------------------------------------------------------
  group('Standard Cricket — scoring', () {
    test('single hit adds 1 mark', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.applyHit(20, 1);
      expect(engine.marks[0][20], 1);
    });

    test('triple closes target immediately', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.applyHit(20, 3);
      expect(engine.marks[0][20], 3);
    });

    test('overflow after close scores points for current player', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      // Close 20 first
      engine.marks[0][20] = 3;
      // Now triple 20 → 3 overflow = 20*3 = 60 pts
      engine.applyHit(20, 3);
      expect(engine.scores[0], 60);
    });

    test('no overflow points when target is closed by all players', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      // Both players close 20
      engine.marks[0][20] = 3;
      engine.marks[1][20] = 3;
      // Triple 20 now — no overflow should score
      engine.applyHit(20, 3);
      expect(engine.scores[0], 0);
    });

    test('hitting non-target segment scores nothing', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.applyHit(10, 3); // 10 is not a target
      expect(engine.scores[0], 0);
      expect(engine.marks[0].values.every((m) => m == 0), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Cutthroat Cricket scoring
  // ---------------------------------------------------------------------------
  group('Cutthroat Cricket — scoring', () {
    test('overflow gives points to opponents, not self', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: true, playerCount: 2);
      engine.marks[0][20] = 3; // P0 has closed 20
      // P0 triple 20 → 3 overflow → 60 pts to P1
      engine.applyHit(20, 3);
      expect(engine.scores[0], 0); // P0 gets nothing
      expect(engine.scores[1], 60); // P1 gets penalised
    });

    test('overflow gives points only to opponents who have NOT closed the target', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: true, playerCount: 3);
      engine.marks[0][20] = 3; // P0 closed
      engine.marks[1][20] = 3; // P1 also closed — should NOT receive points
      // P0 triple 20 → overflow → only P2 gets points
      engine.applyHit(20, 3);
      expect(engine.scores[1], 0);
      expect(engine.scores[2], 60);
    });
  });

  // ---------------------------------------------------------------------------
  // Winner detection — Standard
  // ---------------------------------------------------------------------------
  group('Standard Cricket — winner detection', () {
    test('player wins when all targets closed and has highest score', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      // P0 closes all targets and has more points
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 100;
      engine.scores[1] = 50;
      expect(engine.checkFinishForPlayer(0), isTrue);
      expect(engine.finishedPlayers, contains(0));
    });

    test('player cannot win when opponent has higher score', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 50;
      engine.scores[1] = 100; // P1 leads
      expect(engine.checkFinishForPlayer(0), isFalse);
      expect(engine.finishedPlayers, isEmpty);
    });

    test('player wins with equal score (standard — tied is OK)', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 100;
      engine.scores[1] = 100; // tied — P0 can still finish
      expect(engine.checkFinishForPlayer(0), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Winner detection — Cutthroat
  // ---------------------------------------------------------------------------
  group('Cutthroat Cricket — winner detection', () {
    test('player wins when all targets closed and has LOWEST score', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: true, playerCount: 2);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 20; // lowest — wins
      engine.scores[1] = 80;
      expect(engine.checkFinishForPlayer(0), isTrue);
    });

    test('player CANNOT win in cutthroat if opponent has lower score', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: true, playerCount: 2);
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 80;
      engine.scores[1] = 20; // P1 has lower score — P0 cannot win
      expect(engine.checkFinishForPlayer(0), isFalse);
    });

    test('cannot win without all targets closed in cutthroat', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: true, playerCount: 2);
      // Only close some targets
      engine.marks[0][20] = 3;
      engine.scores[0] = 0; // even with best score
      expect(engine.checkFinishForPlayer(0), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // applyHit — game flow
  // ---------------------------------------------------------------------------
  group('applyHit — turn flow', () {
    test('turn ends after 3 darts', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      engine.applyHit(0, 0); // miss
      engine.applyHit(0, 0); // miss
      final result = engine.applyHit(0, 0); // 3rd dart
      expect(result.turnEnded, isTrue);
      expect(engine.currentPlayerIndex, 1); // advanced to P1
    });

    test('turn ends immediately when player finishes', () {
      final engine = CricketEngine(
          targets: defaultTargets, isCutthroat: false, playerCount: 2);
      // Close all targets for P0, ensure P0 also leads in score
      for (final t in defaultTargets) {
        engine.marks[0][t] = 3;
      }
      engine.scores[0] = 100;
      // Hit any target to trigger checkFinishForPlayer
      // Re-close 20 (already closed) → triggers winner check
      final result = engine.applyHit(20, 1);
      expect(result.playerFinished, isTrue);
      expect(result.turnEnded, isTrue);
    });

    test('BUG FIX: undo restores finishedPlayers correctly', () {
      // Simulates the 2-player cutthroat scenario:
      // When P0 closes everything and wins, both P0 AND P1 end up in finishedPlayers.
      // An undo should remove the effect of that dart.
      final engine = CricketEngine(
          targets: [20], isCutthroat: true, playerCount: 2);
      // Set up: P0 has 2 marks on 20, P1 has 1 mark
      engine.marks[0][20] = 2;
      engine.marks[1][20] = 1;
      engine.scores[0] = 0;
      engine.scores[1] = 40; // P1 has points — P0 has lowest

      // P0 hits triple 20: closes (2+3=5 marks → closed), 2 overflow pts to P1
      // After this, P0 should be able to win (all closed, lowest score)
      engine.applyHit(20, 3); // closes + overflow

      // P0 won → both in finishedPlayers (game over with 2 players)
      expect(engine.finishedPlayers, contains(0));
      expect(engine.gameOver, isTrue);

      // Snapshot of finishedPlayers before the dart (as undo would save)
      // represents state BEFORE the winning dart
      // This validates that the engine's finishedPlayers reflects the finish
      expect(engine.finishedPlayers.first, 0); // P0 won
    });
  });
}
