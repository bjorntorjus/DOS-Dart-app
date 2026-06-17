import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';

void main() {
  test('DartThrow round-trips through JSON', () {
    final t = DartThrow(
      playerIndex: 1, segment: 20, multiplier: 3, points: 60,
      scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
      turnId: 7, roundNumber: 1, isBust: false,
    );
    final back = DartThrow.fromJson(t.toJson());
    expect(back.playerIndex, 1);
    expect(back.segment, 20);
    expect(back.multiplier, 3);
    expect(back.points, 60);
    expect(back.scoreBefore, 501);
    expect(back.turnNumber, 0);
    expect(back.scoreAtStartOfTurn, 501);
    expect(back.turnId, 7);
    expect(back.roundNumber, 1);
    expect(back.isBust, false);
  });

  test('DartThrow preserves isBust through JSON', () {
    final t = DartThrow(
      playerIndex: 0, segment: 19, multiplier: 1, points: 19,
      scoreBefore: 18, turnNumber: 1, scoreAtStartOfTurn: 18,
      turnId: 3, roundNumber: 2, isBust: true,
    );
    final back = DartThrow.fromJson(t.toJson());
    expect(back.isBust, true);
  });
}
