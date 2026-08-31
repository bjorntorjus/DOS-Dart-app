import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_scorecard.dart';
import 'package:dart_scoring/widgets/dossedart/progression_chart.dart';

/// Post-game v2 Task 2: `_buildStats` had a missing `case 'shanghai':` (its
/// stats were silently dropped) and four dead fields across other modes that
/// were passed in `stats` but never rendered. This file locks in the fix.
void main() {
  group('SCORE PER ROUND chart (post-game v2 Task 3)', () {
    List<DartThrow> tinyX01History() => [
          DartThrow(
            playerIndex: 0,
            segment: 20,
            multiplier: 3,
            points: 60,
            scoreBefore: 501,
            turnNumber: 0,
            scoreAtStartOfTurn: 501,
            turnId: 1,
            roundNumber: 1,
          ),
          DartThrow(
            playerIndex: 1,
            segment: 19,
            multiplier: 1,
            points: 19,
            scoreBefore: 501,
            turnNumber: 0,
            scoreAtStartOfTurn: 501,
            turnId: 2,
            roundNumber: 1,
          ),
        ];

    testWidgets(
        'renders when throwHistory + progressionMode are both set (x01)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = GameResult(
        gameMode: 'x01',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'darts': 3}),
          PlayerResult(name: 'B', placement: 2, stats: const {'darts': 3}),
        ],
        throwHistory: tinyX01History(),
        progressionMode: 'x01',
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('SCORE PER ROUND'), findsOneWidget);
      expect(find.byType(ProgressionChart), findsOneWidget);
    });

    testWidgets('absent when throwHistory/progressionMode are null',
        (tester) async {
      final result = GameResult(
        gameMode: 'x01',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'darts': 3}),
        ],
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('SCORE PER ROUND'), findsNothing);
      expect(find.byType(ProgressionChart), findsNothing);
    });
  });
  testWidgets('shanghai result shows Score, Best round, and Shanghai!',
      (tester) async {
    final result = GameResult(
      gameMode: 'shanghai',
      results: [
        PlayerResult(
          name: 'A',
          placement: 1,
          stats: const {'score': 42, 'bestRound': 23, 'shanghai': true},
        ),
        PlayerResult(
          name: 'B',
          placement: 2,
          stats: const {'score': 30, 'bestRound': 12},
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    // Since the DOSSEDART round (2026-08-10) each stat is its own labelled
    // grid cell instead of one joined string, and the mode's headline sits in
    // the row header rather than the grid.
    expect(find.text('42'), findsWidgets); // headline SCORE, winner
    expect(find.text('BEST ROUND'), findsNWidgets(2));
    expect(find.text('23'), findsOneWidget);
    expect(find.text('SHANGHAI!'), findsOneWidget,
        reason: 'only the seat that scored one carries the flag');
    expect(find.text('30'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('gotcha result shows Score first', (tester) async {
    final result = GameResult(
      gameMode: 'gotcha',
      results: [
        PlayerResult(
          name: 'A',
          placement: 1,
          stats: const {
            'score': 250,
            'kills': 2,
            'timesKilled': 1,
            'busts': 0,
            'highestTurn': 60,
            'darts': 15,
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('SCORE'), findsWidgets);
    expect(find.text('250'), findsWidgets);
  });

  testWidgets('oneUp result shows Elims and hides it at 0', (tester) async {
    final result = GameResult(
      gameMode: 'oneUp',
      results: [
        PlayerResult(
          name: 'A',
          placement: 1,
          stats: const {'elimsDealt': 2},
        ),
        PlayerResult(
          name: 'B',
          placement: 2,
          stats: const {'elimsDealt': 0},
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    // ELIMS is a conditional counter: rendered for both players, but the
    // zero is dimmed to an em dash rather than removed, so the grid keeps
    // identical geometry between two games of the mode.
    expect(find.text('ELIMS'), findsNWidgets(2));
    expect(find.text('2'), findsWidgets);
    expect(find.text('0'), findsNothing, reason: 'a zero renders as an em dash');
  });

  testWidgets('golf result shows 1st-dart hit rate', (tester) async {
    final result = GameResult(
      gameMode: 'golf',
      results: [
        PlayerResult(
          name: 'A',
          placement: 1,
          stats: const {
            'strokes': 27,
            'vsPar': 0,
            'firstDartHits': 3,
            'holesPlayed': 9,
          },
        ),
        PlayerResult(
          name: 'B',
          placement: 2,
          stats: const {
            'strokes': 30,
            'vsPar': 3,
            'firstDartHits': 0,
            'holesPlayed': 0,
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('1ST-DART'), findsWidgets);
    expect(find.text('3/9'), findsOneWidget);
    expect(find.text('0/0'), findsNothing,
        reason: 'holesPlayed 0 means the field is absent, not zero');
  });

  group('golfTermDist (post-game v2 Task 4)', () {
    test('counts strokes into A/B/P/B+, omitting zero categories, ignoring nulls', () {
      expect(golfTermDist([1, 2, 3, 3, 4, 6, null]), 'A1 B1 P2 B+2');
    });

    test('returns null when nothing has been played', () {
      expect(golfTermDist([null, null, null]), isNull);
    });

    test('returns null for an empty card', () {
      expect(golfTermDist(const []), isNull);
    });
  });

  group('Golf SCORECARD section (post-game v2 Task 4)', () {
    Map<String, dynamic> golfExtras() => {
          'names': ['A', 'B'],
          'scorecards': [
            [1, 3, null],
            [6, 3, null],
          ],
          'totals': [4, 9],
          'vsPars': [-2, 3],
          'skippedSeats': <int>{},
        };

    testWidgets('present for golf when modeExtras is set', (tester) async {
      // The SCORECARD grid pushes the stats card off a default 600px
      // viewport (RenderFlex overflow) — same tall-viewport fix as the
      // SCORE PER ROUND chart tests above.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = GameResult(
        gameMode: 'golf',
        results: [
          PlayerResult(
            name: 'A',
            placement: 1,
            stats: const {'strokes': 4, 'vsPar': -2},
          ),
          PlayerResult(
            name: 'B',
            placement: 2,
            stats: const {'strokes': 9, 'vsPar': 3},
          ),
        ],
        modeExtras: golfExtras(),
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('SCORECARD'), findsOneWidget);
      expect(find.byType(GolfScoreGrid), findsOneWidget);
    });

    testWidgets('absent for golf without modeExtras', (tester) async {
      final result = GameResult(
        gameMode: 'golf',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'strokes': 4}),
        ],
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('SCORECARD'), findsNothing);
      expect(find.byType(GolfScoreGrid), findsNothing);
    });

    testWidgets('absent for a non-golf mode even if modeExtras were set', (
      tester,
    ) async {
      final result = GameResult(
        gameMode: 'x01',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'darts': 3}),
        ],
        modeExtras: golfExtras(),
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('SCORECARD'), findsNothing);
      expect(find.byType(GolfScoreGrid), findsNothing);
    });

    testWidgets('termDist renders as a Terms: row in the stats line', (
      tester,
    ) async {
      // The SCORECARD grid pushes the stats card off a default 600px
      // viewport (RenderFlex overflow) — same tall-viewport fix as the
      // SCORE PER ROUND chart tests above.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final result = GameResult(
        gameMode: 'golf',
        results: [
          PlayerResult(
            name: 'A',
            placement: 1,
            stats: const {
              'strokes': 27,
              'vsPar': 0,
              'termDist': 'A1 B1 P2 B+2',
            },
          ),
        ],
        modeExtras: golfExtras(),
      );

      await tester
          .pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      expect(find.text('TERMS'), findsWidgets);
      expect(find.text('A1 B1 P2 B+2'), findsOneWidget);
    });
  });
}
