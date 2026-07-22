import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/utils/cricket_achievement_feats.dart';

DartThrow _t(int player, int seg, int mult, int turnId) => DartThrow(
      playerIndex: player,
      segment: seg,
      multiplier: mult,
      points: 0,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turnId,
    );

void main() {
  final targets = {15, 16, 17, 18, 19, 20, 25};

  test('nine marks in ONE turn → 9', () {
    final throws = [
      _t(0, 20, 3, 1), _t(0, 19, 3, 1), _t(0, 18, 3, 1),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 9);
  });

  test('nine marks spread over three turns → max 3 (turnId regression)', () {
    final throws = [
      _t(0, 20, 3, 1), _t(0, 19, 3, 3), _t(0, 18, 3, 5),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 3);
  });

  test('marks on a target closed by ALL players count 0 (dead target)', () {
    final throws = [
      // both players close 20 first (3 marks each)
      _t(0, 20, 3, 1),
      _t(1, 20, 3, 2),
      // now 20 is dead — a T20 turn scores no real marks
      _t(0, 20, 3, 3), _t(0, 20, 3, 3), _t(0, 20, 3, 3),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 3,
        reason: 'best real turn is the opening T20; the dead-target turn is 0');
  });

  test('non-target segments count 0', () {
    final throws = [_t(0, 5, 3, 1), _t(0, 20, 2, 1)];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 2);
  });

  test('empty → 0', () {
    expect(cricketMaxMarksInTurn(const [], targets, 0, 2), 0);
  });
}
