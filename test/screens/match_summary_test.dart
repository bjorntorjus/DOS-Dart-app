import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/screens/post_game/match_summary.dart';

DartThrow t(int seat, int seg, int mul,
        {int round = 0, int turn = 0, int sb = 0}) =>
    DartThrow(
      playerIndex: seat,
      segment: seg,
      multiplier: mul,
      points: seg * mul,
      scoreBefore: sb,
      turnNumber: 0,
      scoreAtStartOfTurn: sb,
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

  group('mode-aware best turn', () {
    test('point modes keep the points sum and the BEST TURN label', () {
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'x01',
        throws: [t(0, 20, 3, turn: 0), t(0, 20, 3, turn: 0)],
        playerNames: const ['A'],
      );
      expect(s.bestTurnLabel, 'BEST TURN');
      expect(s.bestTurn, '120');
    });

    test('ATC counts targets cleared, doubles and triples included', () {
      // Turn 0: S5 (1 step), D6 (2 steps), miss → 3 cleared.
      // Turn 1: S1 only → 1 cleared.
      final throws = [
        t(0, 5, 1, round: 0, turn: 0, sb: 5),
        t(0, 6, 2, round: 0, turn: 0, sb: 6),
        t(0, 0, 0, round: 0, turn: 0, sb: 8),
        t(1, 1, 1, round: 0, turn: 1, sb: 1),
      ];
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'aroundTheClock',
        modeExtras: {
          'countMultiples': true,
          'sequence': [for (var n = 1; n <= 20; n++) n],
        },
        throws: throws,
        playerNames: const ['Jonas', 'Mia'],
      );
      expect(s.bestTurnLabel, 'BEST ROUND');
      expect(s.bestTurn, '3');
      expect(s.bestTurnBy, 'JONAS · R1');
    });

    test('ATC with countMultiples off treats a double as one step', () {
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'aroundTheClock',
        modeExtras: {
          'countMultiples': false,
          'sequence': [for (var n = 1; n <= 20; n++) n],
        },
        throws: [
          t(0, 5, 2, turn: 0, sb: 5),
          t(0, 6, 2, turn: 0, sb: 6),
        ],
        playerNames: const ['A'],
      );
      expect(s.bestTurn, '2');
    });

    test('ATC clamps the finishing dart to the targets that remained', () {
      // On 19 with only 19-20 left, a T19 clears 2, not 3.
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'aroundTheClock',
        modeExtras: {
          'countMultiples': true,
          'sequence': [for (var n = 1; n <= 20; n++) n],
        },
        throws: [t(0, 19, 3, turn: 0, sb: 19)],
        playerNames: const ['A'],
      );
      expect(s.bestTurn, '2');
    });

    test('killer and golf report most hits in a round as n/m', () {
      final throws = [
        t(0, 20, 2, round: 0, turn: 0), // hit
        t(0, 0, 0, round: 0, turn: 0), // miss
        t(0, 20, 2, round: 0, turn: 0), // hit
        t(1, 5, 1, round: 0, turn: 1),
        t(1, 0, 0, round: 0, turn: 1),
        t(1, 0, 0, round: 0, turn: 1),
      ];
      for (final mode in ['killer', 'golf']) {
        final s = matchSummaryFrom(
          durationSeconds: 1,
          gameMode: mode,
          throws: throws,
          playerNames: const ['Jonas', 'Mia'],
        );
        expect(s.bestTurnLabel, 'BEST ROUND', reason: mode);
        expect(s.bestTurn, '2/3', reason: mode);
        expect(s.bestTurnBy, 'JONAS · R1', reason: mode);
      }
    });

    test('cricket counts only points scored while the number is live', () {
      // P0 turn 0: T20 closes (no overflow), T20 again overflows 3 while Mia
      // is open → 60 points. Raw dart sum would have said 120.
      // P1 turn 1: closes 20, then overflows onto the now-dead 20 → 0.
      // P0 turn 2: three S10 — not a cricket target → 0.
      final throws = [
        t(0, 20, 3, round: 0, turn: 0),
        t(0, 20, 3, round: 0, turn: 0),
        t(0, 0, 0, round: 0, turn: 0),
        t(1, 20, 3, round: 0, turn: 1),
        t(1, 20, 3, round: 0, turn: 1),
        t(1, 0, 0, round: 0, turn: 1),
        t(0, 10, 1, round: 1, turn: 2),
        t(0, 10, 1, round: 1, turn: 2),
        t(0, 10, 1, round: 1, turn: 2),
      ];
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'cricket',
        modeExtras: {
          'targets': [15, 16, 17, 18, 19, 20, 25],
        },
        throws: throws,
        playerNames: const ['Jonas', 'Mia'],
      );
      expect(s.bestTurnLabel, 'BEST TURN');
      expect(s.bestTurn, '60');
      expect(s.bestTurnBy, 'JONAS · R1');
    });

    test('cutthroat routes to the same cricket scoring, not the raw sum', () {
      // Points dealt in cutthroat equal points scored in standard play for
      // the same darts — overflow gated on the number being live — so one
      // replay serves both. 100 raw points, 40 that counted.
      final throws = [
        t(0, 20, 3, round: 0, turn: 0),
        t(0, 20, 2, round: 0, turn: 0), // overflow 2 → 40 dealt to open Mia
      ];
      final s = matchSummaryFrom(
        durationSeconds: 1,
        gameMode: 'cricket_cutthroat',
        modeExtras: {
          'targets': [15, 16, 17, 18, 19, 20, 25],
        },
        throws: throws,
        playerNames: const ['Jonas', 'Mia'],
      );
      expect(s.bestTurn, '40');
    });

    test('a degraded summary still carries the mode label for the dim cell',
        () {
      final s = matchSummaryFrom(
        durationSeconds: 600,
        gameMode: 'aroundTheClock',
        throws: null,
      );
      expect(s.degraded, isTrue);
      expect(s.bestTurnLabel, 'BEST ROUND');
    });
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
