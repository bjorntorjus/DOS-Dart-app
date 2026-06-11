import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/utils/x01_achievement_feats.dart';

DartThrow _t({
  int seg = 20,
  int mult = 1,
  int? points,
  required int turnId,
  int scoreBefore = 200,
  bool isBust = false,
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
      isBust: isBust,
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

  test('busted 180 does not grant MAXIMUM', () {
    // 181 left: T20, T20, T20 — third dart leaves 1 → bust in double-out.
    final throws = [
      _t(seg: 20, mult: 3, scoreBefore: 181, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 121, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 61, turnId: 1, isBust: true),
    ];
    final feats = X01Feats.analyze(throws);
    expect(feats.hit180, isFalse);
  });

  test('clean 180 still grants MAXIMUM', () {
    final throws = [
      _t(seg: 20, mult: 3, scoreBefore: 501, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 441, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 381, turnId: 1),
    ];
    expect(X01Feats.analyze(throws).hit180, isTrue);
  });

  test('busted single bull at 25 does not grant BULLSEYE FINISH', () {
    final throws = [
      _t(seg: 25, mult: 1, scoreBefore: 25, turnId: 1, isBust: true),
    ];
    expect(X01Feats.analyze(throws).bullFinish, isFalse);
  });

  test('D-bull checkout grants BULLSEYE FINISH', () {
    final throws = [
      _t(seg: 25, mult: 2, scoreBefore: 50, turnId: 1),
    ];
    expect(X01Feats.analyze(throws).bullFinish, isTrue);
  });

  test('empty throws → no feats', () {
    final feats = X01Feats.analyze(const []);
    expect(feats.hit180, isFalse);
    expect(feats.bullFinish, isFalse);
    expect(feats.maxTreblesInTurn, 0);
    expect(feats.maxBullsInTurn, 0);
  });
}
