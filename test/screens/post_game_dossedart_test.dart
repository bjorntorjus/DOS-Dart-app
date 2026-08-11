import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_placement_card.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_winner_spotlight.dart';

void main() {
  Future<void> pump(WidgetTester tester, GameResult r,
      {Size size = const Size(820, 1180)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: r)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a spotlight, one card per player and the summary',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'x01',
        durationSeconds: 1122,
        results: [
          PlayerResult(name: 'Jonas', placement: 1, stats: const {
            'avgTurn': 62.4,
            'highestTurn': 140,
            'darts': 24,
          }),
          PlayerResult(name: 'Mia', placement: 2, stats: const {
            'avgTurn': 41.8,
            'highestTurn': 100,
            'darts': 33,
          }),
        ],
      ),
    );

    expect(find.byType(DossedartWinnerSpotlight), findsOneWidget);
    expect(find.byType(DossedartPlacementCard), findsNWidgets(2));
    expect(find.text('★ WINNER ★'), findsOneWidget);
    // The winner appears twice on purpose: once in the spotlight, once in
    // the standings, which list every player at the same size.
    expect(find.text('JONAS'), findsNWidgets(2));
    expect(find.text('MATCH SUMMARY'), findsOneWidget);
    expect(find.text('18:42'), findsOneWidget);
    expect(find.text('X01'), findsOneWidget);
  });

  testWidgets('the stat wall is gone — each stat is its own labelled cell',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'x01',
        results: [
          PlayerResult(name: 'Jonas', placement: 1, stats: const {
            'avgTurn': 62.4,
            'highestTurn': 140,
            'darts': 24,
            'checkout': 'D20',
          }),
        ],
      ),
    );

    // The old screen rendered one joined string per player.
    expect(find.textContaining('Best: 140 | Darts: 24'), findsNothing);
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    expect(find.text('DARTS'), findsOneWidget);
    expect(find.text('CHECKOUT'), findsOneWidget);
    expect(find.text('D20'), findsOneWidget);
  });

  testWidgets('the action bar survives a short frame — never pushed off',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'gotcha',
        results: [
          for (var i = 0; i < 6; i++)
            PlayerResult(
                name: 'Player $i', placement: i + 1, stats: const {
              'score': 100,
              'kills': 1,
              'timesKilled': 0,
              'busts': 0,
              'highestTurn': 60,
              'darts': 27,
            }),
        ],
      ),
      size: const Size(820, 640),
    );

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a roster change shows the notice, no chart, dimmed DETAILS',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'cricket',
        statsSkipped: true,
        durationSeconds: 300,
        results: [
          PlayerResult(
              name: 'Kari', placement: 1, stats: const {'points': 40}),
          PlayerResult(name: 'Per', placement: 2, stats: const {'points': 12}),
        ],
      ),
    );

    expect(find.textContaining('STATISTICS NOT RECORDED'), findsOneWidget);
    expect(find.text('SCORE PER ROUND'), findsNothing);
    // The button is rendered even though it cannot be used.
    expect(find.text('▶ DETAILS'), findsOneWidget);
    // Duration survives; the rest of the summary is degraded.
    expect(find.text('5:00'), findsOneWidget);
    expect(find.textContaining('partly unavailable'), findsOneWidget);
  });

  testWidgets('a tie tags both cards and shares the placement number',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'halveIt',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'score': 480}),
          PlayerResult(name: 'B', placement: 2, stats: const {'score': 300}),
          PlayerResult(name: 'C', placement: 2, stats: const {'score': 300}),
        ],
      ),
    );

    expect(find.text('TIED'), findsNWidgets(2));
  });

  testWidgets('WILDCARD keeps the Elo column and dims it for everyone',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'wildcard',
        results: [
          PlayerResult(name: 'Per', placement: 1, stats: const {
            'score': 412,
            'jokersHit': 3,
            'windowPrizes': 2,
            'pointsStolen': 0,
            'highestTurn': 96,
            'darts': 27,
          }),
        ],
      ),
    );

    expect(find.text('ELO'), findsNWidgets(2), reason: 'spotlight + one card');
    expect(find.text('STOLEN'), findsOneWidget,
        reason: 'zero conditional stays in place');
  });

  testWidgets('an empty result list does not crash the screen',
      (tester) async {
    await pump(tester, GameResult(gameMode: 'x01', results: const []));
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
