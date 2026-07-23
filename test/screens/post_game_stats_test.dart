import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
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

    expect(find.textContaining('Score: 42'), findsOneWidget);
    expect(find.textContaining('Best round: 23'), findsOneWidget);
    expect(find.textContaining('Shanghai!'), findsOneWidget);
    expect(find.textContaining('Score: 30'), findsOneWidget);
    expect(find.textContaining('Best round: 12'), findsOneWidget);
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

    expect(find.textContaining('Score: 250'), findsOneWidget);
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

    expect(find.textContaining('Elims: 2'), findsOneWidget);
    expect(find.textContaining('Elims: 0'), findsNothing);
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

    expect(find.textContaining('1st-dart: 3/9'), findsOneWidget);
    expect(find.textContaining('1st-dart: 0/0'), findsNothing);
  });
}
