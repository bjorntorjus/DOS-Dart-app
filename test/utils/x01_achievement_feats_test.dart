import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/utils/x01_achievement_feats.dart';

DartThrow _t({
  int seg = 20,
  int mult = 1,
  int? points,
  required int turnId,
  int scoreBefore = 200,
}) =>
    DartThrow(
      playerIndex: 0,
      segment: seg,
      multiplier: mult,
      points: points ?? seg * mult,
      scoreBefore: scoreBefore,
      turnNumber: 0,
      scoreAtStartOfTurn: scoreBefore,
      turnId: turnId,
    );

void main() {
  test('detects a 180 (three treble-20s in one turn)', () {
    final feats = X01Feats.analyze([
      _t(seg: 20, mult: 3, turnId: 1),
      _t(seg: 20, mult: 3, turnId: 1),
      _t(seg: 20, mult: 3, turnId: 1),
    ]);
    expect(feats.hit180, isTrue);
    expect(feats.maxTreblesInTurn, 3);
  });

  test('no 180 when the turn totals less', () {
    final feats = X01Feats.analyze([
      _t(seg: 20, mult: 3, turnId: 1),
      _t(seg: 20, mult: 3, turnId: 1),
      _t(seg: 20, mult: 1, turnId: 1),
    ]);
    expect(feats.hit180, isFalse);
    expect(feats.maxTreblesInTurn, 2);
  });

  test('bull finish: a bull dart that closes the leg (scoreBefore == points)', () {
    final feats = X01Feats.analyze([
      _t(seg: 25, mult: 2, points: 50, scoreBefore: 50, turnId: 7),
    ]);
    expect(feats.bullFinish, isTrue);
  });

  test('a non-closing bull is not a bull finish', () {
    final feats = X01Feats.analyze([
      _t(seg: 25, mult: 1, points: 25, scoreBefore: 120, turnId: 7),
    ]);
    expect(feats.bullFinish, isFalse);
    expect(feats.maxBullsInTurn, 1);
  });

  test('three bulls in one turn', () {
    final feats = X01Feats.analyze([
      _t(seg: 25, mult: 1, points: 25, scoreBefore: 120, turnId: 3),
      _t(seg: 25, mult: 1, points: 25, scoreBefore: 95, turnId: 3),
      _t(seg: 25, mult: 1, points: 25, scoreBefore: 70, turnId: 3),
    ]);
    expect(feats.maxBullsInTurn, 3);
  });

  test('empty throws → no feats', () {
    final feats = X01Feats.analyze(const []);
    expect(feats.hit180, isFalse);
    expect(feats.bullFinish, isFalse);
    expect(feats.maxTreblesInTurn, 0);
    expect(feats.maxBullsInTurn, 0);
  });
}
