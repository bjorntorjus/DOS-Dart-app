import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/mode_progression.dart';

DartThrow _t(int seg, int mul, {required int round, required int sst}) => DartThrow(
    playerIndex: 0, segment: seg, multiplier: mul, points: seg * mul,
    scoreBefore: sst, turnNumber: 0, scoreAtStartOfTurn: sst,
    turnId: round, roundNumber: round);

void main() {
  test('X01 progression is remaining score per round, racing to 0', () {
    final throws = [
      _t(20, 3, round: 1, sst: 501), // 441 left after R1
      _t(20, 3, round: 2, sst: 441), // 381 left after R2
    ];
    final p = X01Progression(startScore: 501);
    final series = p.seriesFor(throws, playerIndex: 0);
    expect(series.first, 501);     // start point
    expect(series, [501, 441, 381]);
    expect(p.descending, isTrue);
    expect(p.maxValue, 501);
  });
}
