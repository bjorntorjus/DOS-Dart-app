import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/mode_progression.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';
import 'package:dart_scoring/widgets/dossedart/progression_chart.dart';

/// Post-game v2 Task 3: `_LegPainter` computed its y-range as `[0, top]`
/// (folding `dataMax` from a 0 seed, `top` floored at 1), which silently
/// assumed every series was non-negative. Golf's vs-par series goes negative
/// whenever a player is under par, so `yAt(v)` for those points landed below
/// `padT + plotH` — outside the 200px plot box entirely. `yRange` now spans
/// `[min(0, dataMin) .. max(1, dataMax)]` so negative values stay inside.
void main() {
  test(
      'chart lines use the per-player accent cycle — same color as the '
      'player\'s in-game accent, no near-identical silver/cyan pair '
      '(tester feedback 2026-08-21)', () {
    expect(dossedartPlayerPalette, dossedartAccents,
        reason: 'the old chart-only palette gave seat 2 silver, which was '
            'indistinguishable from seat 1\'s glowing cyan on the tablet');
  });

  group('yRange', () {
    test('spans negative golf data instead of clamping the bottom at 0', () {
      final progression = GolfProgression(maxValue: 0);
      final series = [
        [0, -2, -3, -4]
      ];

      final r = yRange(progression, series);

      // The pre-fix formula always returned bottom=0, top>=1 — every
      // negative value in the series would sit below the visible box.
      expect(r.bottom, lessThanOrEqualTo(-4));
      expect(r.top, greaterThanOrEqualTo(1));
      for (final v in series.expand((s) => s)) {
        expect(v, inInclusiveRange(r.bottom.toDouble(), r.top.toDouble()));
      }
    });

    test('keeps bottom at 0 for descending (race-to-zero) progressions', () {
      final progression = X01Progression(startScore: 501);
      final series = [
        [501, 401, 301]
      ];

      final r = yRange(progression, series);

      expect(r.bottom, 0);
      expect(r.top, 501);
    });

    test('bottoms at 0 for climbing progressions with no negative data',
        () {
      final progression = CricketProgression(targets: const {20}, maxValue: 0);
      final series = [
        [0, 2, 5]
      ];

      final r = yRange(progression, series);

      expect(r.bottom, 0);
      expect(r.top, 5);
    });
  });

  testWidgets(
      'ProgressionChart renders an all-negative golf series without exceptions',
      (tester) async {
    // Three holes, each closing on the first dart via a hit — vsPar goes
    // -2, -3, -4: a series that never crosses back to 0.
    final throws = [
      DartThrow(
        playerIndex: 0,
        segment: 20,
        multiplier: 3,
        points: 0,
        scoreBefore: 0,
        turnNumber: 0,
        scoreAtStartOfTurn: 0,
        turnId: 1,
        roundNumber: 1,
      ),
      DartThrow(
        playerIndex: 0,
        segment: 20,
        multiplier: 2,
        points: 0,
        scoreBefore: 0,
        turnNumber: 0,
        scoreAtStartOfTurn: 0,
        turnId: 2,
        roundNumber: 2,
      ),
      DartThrow(
        playerIndex: 0,
        segment: 20,
        multiplier: 2,
        points: 0,
        scoreBefore: 0,
        turnNumber: 0,
        scoreAtStartOfTurn: 0,
        turnId: 3,
        roundNumber: 3,
      ),
    ];
    final progression = GolfProgression(maxValue: 0);

    // Sanity: this really does exercise the all-negative path, otherwise
    // the test wouldn't be reproducing the bug at all.
    final series = progression.seriesFor(throws, playerIndex: 0);
    expect(series.any((v) => v < 0), isTrue);
    expect(series.every((v) => v <= 0), isTrue);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProgressionChart(
          progression: progression,
          throws: throws,
          playerNames: const ['A'],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ProgressionChart), findsOneWidget);
  });
}
