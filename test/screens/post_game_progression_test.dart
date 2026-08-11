import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/progression_chart.dart';

/// PostGameScreen's optional "SCORE PER ROUND" progression chart (WQ3 Task
/// 4): rendered only when a `GameResult` opts in with both `throwHistory`
/// and `progressionMode` set (WILDCARD, as of 2026-07-09) — every other mode
/// passes neither and gets no chart, zero behavior change.
void main() {
  List<DartThrow> threeRoundThrows() => [
        for (var r = 1; r <= 3; r++) ...[
          DartThrow(
            playerIndex: 0,
            segment: 20,
            multiplier: 3,
            points: 60,
            scoreBefore: 0,
            turnNumber: 0,
            scoreAtStartOfTurn: (r - 1) * 60,
            turnId: r * 2,
            roundNumber: r,
          ),
          DartThrow(
            playerIndex: 1,
            segment: 19,
            multiplier: 2,
            points: 38,
            scoreBefore: 0,
            turnNumber: 0,
            scoreAtStartOfTurn: (r - 1) * 38,
            turnId: r * 2 + 1,
            roundNumber: r,
          ),
        ],
      ];

  testWidgets(
      'wildcard result with throwHistory shows the chart + Score row',
      (tester) async {
    // The chart renders as a trailing ListView item below the placement
    // tiles (avoids a fixed-height sibling overflowing the Column on short
    // screens) — a tall viewport keeps it built/visible without scrolling.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = GameResult(
      gameMode: 'wildcard',
      results: [
        PlayerResult(
          name: 'A',
          placement: 1,
          stats: const {
            'score': 180,
            'jokersHit': 0,
            'windowPrizes': 0,
            'highestTurn': 60,
            'darts': 3,
          },
        ),
        PlayerResult(
          name: 'B',
          placement: 2,
          stats: const {
            'score': 114,
            'jokersHit': 0,
            'windowPrizes': 0,
            'highestTurn': 38,
            'darts': 3,
          },
        ),
      ],
      throwHistory: threeRoundThrows(),
      progressionMode: 'wildcard',
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('SCORE PER ROUND'), findsOneWidget);
    expect(find.byType(ProgressionChart), findsOneWidget);
    // Headline values now sit in the row header, not a joined stat string.
    expect(find.text('180'), findsWidgets);
    expect(find.text('114'), findsOneWidget);
  });

  testWidgets('result without throwHistory shows no chart', (tester) async {
    final result = GameResult(
      gameMode: 'gotcha',
      results: [
        PlayerResult(name: 'A', placement: 1, stats: const {'kills': 2}),
        PlayerResult(name: 'B', placement: 2, stats: const {'kills': 0}),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('SCORE PER ROUND'), findsNothing);
    expect(find.byType(ProgressionChart), findsNothing);
  });
}
