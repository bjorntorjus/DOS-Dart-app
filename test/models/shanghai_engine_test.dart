import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/shanghai_engine.dart';

void main() {
  group('ShanghaiGameEngine', () {
    test('initial state: round 0, player 0, dart 0, scores zero', () {
      final e = ShanghaiGameEngine(playerCount: 3, targetEnd: 7);
      expect(e.currentRound, 0);
      expect(e.currentTarget, 1);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartNumber, 0);
      expect(e.totalScores, [0, 0, 0]);
      expect(e.gameOver, false);
      expect(e.winnerIndex, isNull);
      expect(e.isInstantShanghai, false);
    });

    test('single hit on target adds target value to score', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.single);
      expect(e.totalScores[0], 1);
      expect(e.dartNumber, 1);
    });

    test('double hit on target adds 2× target value', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.double_);
      expect(e.totalScores[0], 2);
    });

    test('triple hit on target adds 3× target value', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.triple);
      expect(e.totalScores[0], 3);
    });

    test('miss adds 0 and does not count toward Shanghai', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.totalScores[0], 0);
      expect(e.gameOver, false);
    });

    test('target advances to round 2 after all players throw 3 darts', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.currentRound, 1);
      expect(e.currentTarget, 2);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartNumber, 0);
    });

    test('scoring on round 5 uses target value 5', () {
      final e = ShanghaiGameEngine(playerCount: 1, targetEnd: 7);
      for (int r = 0; r < 4; r++) {
        e.recordThrow(HitType.miss);
        e.recordThrow(HitType.miss);
        e.recordThrow(HitType.miss);
      }
      expect(e.currentTarget, 5);
      e.recordThrow(HitType.triple);
      expect(e.totalScores[0], 15);
    });

    test('instant Shanghai: S+D+T in same turn ends game', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.double_);
      e.recordThrow(HitType.triple);
      expect(e.isInstantShanghai, true);
      expect(e.gameOver, true);
      expect(e.winnerIndex, 0);
      expect(e.totalScores[0], 6);
    });

    test('instant Shanghai works in any order: D, T, S', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.double_);
      e.recordThrow(HitType.triple);
      e.recordThrow(HitType.single);
      expect(e.isInstantShanghai, true);
      expect(e.gameOver, true);
    });

    test('instant Shanghai works in any order: T, S, D', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.triple);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.double_);
      expect(e.isInstantShanghai, true);
      expect(e.gameOver, true);
    });

    test('three singles is NOT a Shanghai', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.single);
      expect(e.isInstantShanghai, false);
      expect(e.gameOver, false);
      expect(e.totalScores[0], 3);
    });

    test('S+D without T is NOT a Shanghai', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.double_);
      e.recordThrow(HitType.miss);
      expect(e.isInstantShanghai, false);
      expect(e.gameOver, false);
    });

    test('game ends after final round; high score wins', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 2);
      e.recordThrow(HitType.triple);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.gameOver, true);
      expect(e.winnerIndex, 0);
      expect(e.totalScores, [3, 1]);
      expect(e.isInstantShanghai, false);
    });

    test('tied final scores: winnerIndex is null, gameOver true', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 1);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.gameOver, true);
      expect(e.winnerIndex, isNull);
      expect(e.isTie, true);
    });

    test('undo reverses last throw', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.triple);
      expect(e.totalScores[0], 3);
      expect(e.dartNumber, 1);
      e.undo();
      expect(e.totalScores[0], 0);
      expect(e.dartNumber, 0);
    });

    test('undo restores currentTurnHits state', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.single);
      e.recordThrow(HitType.double_);
      e.undo();
      e.recordThrow(HitType.miss);
      expect(e.isInstantShanghai, false);
      expect(e.gameOver, false);
    });

    test('undo across player boundary', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartNumber, 0);
      e.undo();
      expect(e.currentPlayerIndex, 0);
      expect(e.dartNumber, 2);
    });

    test('undo at game start does nothing', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.undo();
      expect(e.currentPlayerIndex, 0);
      expect(e.dartNumber, 0);
      expect(e.totalScores, [0, 0]);
    });

    test('addPlayer mid-game adds player with score 0', () {
      final e = ShanghaiGameEngine(playerCount: 2, targetEnd: 7);
      e.recordThrow(HitType.triple);
      e.addPlayer();
      expect(e.totalScores.length, 3);
      expect(e.totalScores[2], 0);
    });

    test('removePlayer marks player as skipped without shrinking scores', () {
      final e = ShanghaiGameEngine(playerCount: 3, targetEnd: 7);
      e.removePlayer(1);
      expect(e.totalScores.length, 3);
      expect(e.isSkipped(1), isTrue);
      expect(e.activePlayerCount, 2);
    });

    test('removePlayer skips current player and advances turn', () {
      final e = ShanghaiGameEngine(playerCount: 3, targetEnd: 7);
      // currentPlayerIndex starts at 0
      e.removePlayer(0);
      expect(e.isSkipped(0), isTrue);
      expect(e.currentPlayerIndex, 1);
    });

    test('turn advance skips removed players', () {
      final e = ShanghaiGameEngine(playerCount: 3, targetEnd: 7);
      e.removePlayer(1);
      // Player 0 throws 3 darts; turn should jump to player 2, not 1
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      e.recordThrow(HitType.miss);
      expect(e.currentPlayerIndex, 2);
    });
  });
}
