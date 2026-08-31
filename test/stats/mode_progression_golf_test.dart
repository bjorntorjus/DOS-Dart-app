import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/mode_progression.dart';

// points is deliberately set to a garbage value (999) on every fixture dart:
// golf's DartThrow.points is a placeholder and must never be read by
// GolfProgression — if the implementation ever falls back to it, these
// numbers would leak into the assertions and fail loudly.
DartThrow _dart(int playerIndex, int seg, int mul, {required int round}) =>
    DartThrow(
      playerIndex: playerIndex,
      segment: seg,
      multiplier: mul,
      points: 999,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: round,
      roundNumber: round,
    );

DartThrow _miss(int playerIndex, {required int round}) =>
    _dart(playerIndex, 0, 0, round: round);

void main() {
  final p = GolfProgression(maxValue: 0);

  test('ace: triple-20 on the first dart is 1 stroke → vsPar -2', () {
    final throws = [_dart(0, 20, 3, round: 1)];
    expect(p.seriesFor(throws, playerIndex: 0), [0, -2]);
  });

  test('hit after 2 misses via a double is 4 strokes → vsPar +1', () {
    final throws = [
      _miss(0, round: 1),
      _miss(0, round: 1),
      _dart(0, 7, 2, round: 1),
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, 1]);
  });

  test('wash: 3 misses is 6 strokes → vsPar +3', () {
    final throws = [
      _miss(0, round: 1),
      _miss(0, round: 1),
      _miss(0, round: 1),
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, 3]);
  });

  test('cumulative series across 3 holes', () {
    final throws = [
      _dart(0, 20, 3, round: 1), // ace → -2 (cum -2)
      _miss(0, round: 2),
      _miss(0, round: 2),
      _dart(0, 7, 2, round: 2), // 4 strokes → +1 (cum -1)
      _miss(0, round: 3),
      _miss(0, round: 3),
      _miss(0, round: 3), // wash → +3 (cum +2)
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, -2, -1, 2]);
  });

  test('playoff contamination: darts after the terminator are ignored', () {
    final throws = [
      _dart(0, 20, 3, round: 1), // ace terminates hole 1 → -2
      // Playoff darts stamped with the same frozen roundNumber — must not
      // change the already-terminated hole's stroke count.
      _dart(0, 5, 1, round: 1),
      _miss(0, round: 1),
      _dart(0, 19, 3, round: 1),
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, -2]);
  });

  test('unterminated round contributes nothing yet', () {
    final throws = [
      _dart(0, 20, 3, round: 1), // ace → -2
      _miss(0, round: 2), // hole 2 still in progress, no terminator
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, -2]);
  });

  test('two players interleaved are filtered independently per playerIndex',
      () {
    final throws = [
      _dart(0, 20, 3, round: 1), // player 0 ace → -2
      _miss(1, round: 1),
      _miss(1, round: 1),
      _miss(1, round: 1), // player 1 wash → +3
      _dart(1, 7, 2, round: 2), // player 1 hole 2: hit on first dart, D → 2
      _miss(0, round: 2),
      _miss(0, round: 2),
      _dart(0, 7, 2, round: 2), // player 0 hole 2: 4 strokes → +1
    ];
    expect(p.seriesFor(throws, playerIndex: 0), [0, -2, -1]);
    expect(p.seriesFor(throws, playerIndex: 1), [0, 3, 2]);
  });

  test('metadata', () {
    expect(p.descending, isFalse);
    expect(p.finishLabel, '⛳');
  });
}
