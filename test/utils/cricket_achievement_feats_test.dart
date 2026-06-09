import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/utils/cricket_achievement_feats.dart';

DartThrow _t(int seg, int mult, int turnId) => DartThrow(
      playerIndex: 0,
      segment: seg,
      multiplier: mult,
      points: seg * mult,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turnId,
    );

void main() {
  final targets = {15, 16, 17, 18, 19, 20, 25};

  test('three trebles in one turn = 9 marks', () {
    final max = cricketMaxMarksInTurn([
      _t(20, 3, 1),
      _t(19, 3, 1),
      _t(18, 3, 1),
    ], targets);
    expect(max, 9);
  });

  test('off-target darts score no marks', () {
    final max = cricketMaxMarksInTurn([
      _t(3, 3, 1), // 3 is not a cricket target
      _t(20, 1, 1),
    ], targets);
    expect(max, 1);
  });

  test('double bull = 2 marks, single bull = 1', () {
    expect(cricketMarksForDart(_t(25, 2, 1), targets), 2);
    expect(cricketMarksForDart(_t(25, 1, 1), targets), 1);
  });

  test('marks are summed per turn, max returned across turns', () {
    final max = cricketMaxMarksInTurn([
      _t(20, 1, 1), _t(20, 1, 1), // turn 1 = 2
      _t(20, 3, 2), _t(19, 3, 2), _t(17, 1, 2), // turn 2 = 7
    ], targets);
    expect(max, 7);
  });

  test('empty → 0', () {
    expect(cricketMaxMarksInTurn(const [], targets), 0);
  });
}
