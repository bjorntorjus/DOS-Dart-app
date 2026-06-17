import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/mode_progression.dart';

DartThrow _t(int seg, int mul, {required int round}) => DartThrow(
    playerIndex: 0, segment: seg, multiplier: mul, points: seg * mul,
    scoreBefore: 0, turnNumber: 0, scoreAtStartOfTurn: 0,
    turnId: round, roundNumber: round);

void main() {
  test('Cricket plots cumulative marks on target numbers, climbing', () {
    final throws = [
      _t(20, 3, round: 1), // 3 marks
      _t(19, 2, round: 2), // +2 marks
      _t(5, 1, round: 2),  // 5 is not a target → ignored
    ];
    final p = CricketProgression(targets: const {15, 16, 17, 18, 19, 20}, maxValue: 20);
    final series = p.seriesFor(throws, playerIndex: 0);
    expect(series, [0, 3, 5]);
    expect(p.descending, isFalse);
  });

  test('Shanghai/Splitscore plot cumulative points, climbing', () {
    final throws = [
      _t(20, 3, round: 1), // 60
      _t(10, 1, round: 2), // +10
    ];
    final p = CumulativeScoreProgression(maxValue: 100);
    final series = p.seriesFor(throws, playerIndex: 0);
    expect(series, [0, 60, 70]);
    expect(p.descending, isFalse);
  });

  test('ATC plots sequential targets reached, climbing toward 20', () {
    // Hits 1 (R1), misses then 2 (R2), jumps to 5 (no effect — must be in order).
    final throws = [
      _t(1, 1, round: 1),  // reaches 1
      _t(2, 1, round: 2),  // reaches 2
      _t(5, 1, round: 2),  // out of sequence → no advance
    ];
    final p = AtcProgression();
    final series = p.seriesFor(throws, playerIndex: 0);
    expect(series, [0, 1, 2]);
    expect(p.maxValue, 20);
    expect(p.descending, isFalse);
  });
}
