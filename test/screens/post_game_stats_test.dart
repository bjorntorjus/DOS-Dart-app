import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';

/// Post-game v2 Task 2: `_buildStats` had a missing `case 'shanghai':` (its
/// stats were silently dropped) and four dead fields across other modes that
/// were passed in `stats` but never rendered. This file locks in the fix.
void main() {
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
