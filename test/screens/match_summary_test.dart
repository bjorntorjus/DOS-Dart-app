import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/screens/post_game/match_summary.dart';

DartThrow t(int seat, int seg, int mul, {int round = 0, int turn = 0}) =>
    DartThrow(
      playerIndex: seat,
      segment: seg,
      multiplier: mul,
      points: seg * mul,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turn,
      roundNumber: round,
    );

void main() {
  test('duration formats as mm:ss, and past an hour as h:mm:ss', () {
    expect(matchSummaryFrom(durationSeconds: 1122).duration, '18:42');
    expect(matchSummaryFrom(durationSeconds: 59).duration, '0:59');
    expect(matchSummaryFrom(durationSeconds: 3725).duration, '1:02:05');
  });

  test('no duration renders an em dash rather than a zero clock', () {
    expect(matchSummaryFrom(durationSeconds: null).duration, '—');
  });

  test('suppressed throwHistory degrades every cell but duration', () {
    final s = matchSummaryFrom(durationSeconds: 600, throws: null);
    expect(s.degraded, isTrue);
    expect(s.duration, '10:00');
    expect(s.rounds, isNull);
    expect(s.bestTurn, isNull);
  });

  test('rounds, darts and the best turn come off the throw history', () {
    final throws = [
      t(0, 20, 3, round: 0, turn: 0), // 60
      t(0, 20, 1, round: 0, turn: 0), // 20  -> turn 0 = 80
      t(1, 5, 1, round: 0, turn: 1),
      t(0, 19, 3, round: 1, turn: 2), // 57
      t(0, 19, 3, round: 1, turn: 2), // 57  -> turn 2 = 114
    ];
    final s = matchSummaryFrom(
      durationSeconds: 60,
      throws: throws,
      playerNames: const ['Jonas', 'Mia'],
    );
    expect(s.degraded, isFalse);
    expect(s.rounds, '2');
    expect(s.darts, '5');
    expect(s.bestTurn, '114');
    expect(s.bestTurnBy, 'JONAS · R2');
  });

  test('hit distribution counts a bull as a bull, not as a double', () {
    final throws = [
      t(0, 20, 3),
      t(0, 20, 2),
      t(0, 25, 2), // double bull — a bull, counted once
      t(0, 0, 0),
    ];
    final s = matchSummaryFrom(
        durationSeconds: 1, throws: throws, playerNames: const ['A']);
    expect(s.hitDistribution, 'T 1 · D 1 · B 1 · ✗ 1');
  });

  test('biggest lead is the widest same-round gap between seats', () {
    final series = {
      0: <num>[0, 60, 140],
      1: <num>[0, 20, 45],
    };
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['A', 'B'],
      seriesFor: (seat) => series[seat],
    );
    expect(s.biggestLead, '95');
  });

  test('no series means no lead, and the rest still render', () {
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['A'],
    );
    expect(s.biggestLead, isNull);
    expect(s.darts, '1');
    expect(s.degraded, isFalse,
        reason: 'a missing series dims one cell, not the whole zone');
  });

  test('a single-player game has no lead to report', () {
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['Solo'],
      seriesFor: (seat) => <num>[0, 20],
    );
    expect(s.biggestLead, isNull);
  });

  test('series of differing length compare only the shared rounds', () {
    // A joiner's series is shorter. Comparing past its end would read a
    // missing value as a lead of the leader's full total.
    final series = {
      0: <num>[0, 60, 140, 200],
      1: <num>[0, 20],
    };
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['A', 'B'],
      seriesFor: (seat) => series[seat],
    );
    expect(s.biggestLead, '40', reason: 'round 1 gap, not round 3');
  });
}
