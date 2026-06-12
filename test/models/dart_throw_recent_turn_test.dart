import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';

DartThrow _t({
  int playerIndex = 0,
  required int segment,
  required int multiplier,
  required int turnId,
}) =>
    DartThrow(
      playerIndex: playerIndex,
      segment: segment,
      multiplier: multiplier,
      points: segment * multiplier,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turnId,
    );

void main() {
  group('RecentTurn.recentTurnLabel', () {
    test('empty history returns null', () {
      expect(<DartThrow>[].recentTurnLabel(0), isNull);
    });

    test('player with no throws returns null even when others threw', () {
      final history = [_t(playerIndex: 0, segment: 20, multiplier: 1, turnId: 0)];
      expect(history.recentTurnLabel(1), isNull);
    });

    test('in-progress turn accumulates live, dart by dart', () {
      final history = [_t(segment: 20, multiplier: 3, turnId: 0)];
      expect(history.recentTurnLabel(0), 'T20');

      history.add(_t(segment: 19, multiplier: 1, turnId: 0));
      expect(history.recentTurnLabel(0), 'T20 · S19');

      history.add(_t(segment: 0, multiplier: 0, turnId: 0));
      expect(history.recentTurnLabel(0), 'T20 · S19 · MISS');
    });

    test('falls back to the player\'s own most recent turn', () {
      final history = [
        _t(playerIndex: 0, segment: 20, multiplier: 1, turnId: 0),
        _t(playerIndex: 0, segment: 5, multiplier: 2, turnId: 0),
        // P1's turn in between — must not leak into P0's label.
        _t(playerIndex: 1, segment: 19, multiplier: 3, turnId: 1),
      ];
      expect(history.recentTurnLabel(0), 'S20 · D5');
      expect(history.recentTurnLabel(1), 'T19');
    });

    test('only the latest turnId of the player is shown', () {
      final history = [
        _t(segment: 1, multiplier: 1, turnId: 0),
        _t(segment: 2, multiplier: 1, turnId: 0),
        _t(segment: 3, multiplier: 1, turnId: 2),
      ];
      expect(history.recentTurnLabel(0), 'S3');
    });

    test('Bull and D-Bull keep their names like shortLabel (not S25/D25)', () {
      final history = [
        _t(segment: 25, multiplier: 1, turnId: 0),
        _t(segment: 25, multiplier: 2, turnId: 0),
      ];
      expect(history.recentTurnLabel(0), 'Bull · D-Bull');
    });

    test('miss renders as MISS regardless of multiplier 0', () {
      final history = [_t(segment: 0, multiplier: 0, turnId: 0)];
      expect(history.recentTurnLabel(0), 'MISS');
    });
  });

  group('RecentTurn.recentTurnSum', () {
    test('0 when the player has no throws', () {
      expect(<DartThrow>[].recentTurnSum(0), 0);
    });

    test('sums only the most recent turn, in-progress included', () {
      final history = [
        _t(segment: 20, multiplier: 3, turnId: 0),
        _t(segment: 20, multiplier: 3, turnId: 0),
        _t(segment: 20, multiplier: 3, turnId: 0),
        _t(segment: 19, multiplier: 1, turnId: 1),
      ];
      expect(history.recentTurnSum(0), 19);

      history.add(_t(segment: 0, multiplier: 0, turnId: 1));
      expect(history.recentTurnSum(0), 19,
          reason: 'a miss adds nothing to the live sum');

      history.add(_t(segment: 25, multiplier: 2, turnId: 1));
      expect(history.recentTurnSum(0), 69,
          reason: 'D-Bull counts 50 via segment × multiplier');
    });

    test('other players\' darts are excluded from the sum', () {
      final history = [
        _t(playerIndex: 0, segment: 20, multiplier: 1, turnId: 0),
        _t(playerIndex: 1, segment: 19, multiplier: 3, turnId: 1),
      ];
      expect(history.recentTurnSum(0), 20);
      expect(history.recentTurnSum(1), 57);
    });
  });
}
