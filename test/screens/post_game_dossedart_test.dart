import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/dossedart/game_detail_screen.dart';
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

  testWidgets('PLAY AGAIN pops the screen with the again action',
      (tester) async {
    String? popped;
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => PostGameScreen(
                  result: GameResult(
                    gameMode: 'x01',
                    results: [
                      PlayerResult(name: 'Jonas', placement: 1, stats: const {
                        'avgTurn': 62.4,
                        'highestTurn': 140,
                        'darts': 24,
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('↻ PLAY AGAIN'));
    await tester.pumpAndSettle();
    expect(popped, 'again');
  });

  testWidgets(
      'a roster-changed result: no chart, DURATION still reads, summary is '
      'flagged partly unavailable, and DETAILS is offered', (tester) async {
    // Spec 2026-08-26: a mid-game roster change no longer skips stats. Only
    // the progression chart stays suppressed (its lines index by seat and
    // would mislabel a changed roster), so the screen arrives with
    // throwHistory == null but a real durationSeconds and a real
    // detailEntry — the same flagged entry every other consumer reads.
    await pump(
      tester,
      GameResult(
        gameMode: 'cricket',
        durationSeconds: 1122,
        throwHistory: null,
        progressionMode: null,
        detailEntry: GameHistoryEntry(
          id: 'e1',
          gameMode: 'cricket',
          date: DateTime(2026, 8, 26),
          durationSeconds: 1122,
          players: [
            GameHistoryPlayer(
                name: 'Jonas', placement: 1, stats: const {'points': 80}),
            GameHistoryPlayer(
                name: 'Mia', placement: 2, stats: const {'points': 41}),
            GameHistoryPlayer(
                name: 'Ghost',
                placement: 0,
                stats: const {'points': 12},
                removed: true),
          ],
        ),
        results: [
          PlayerResult(name: 'Jonas', placement: 1, stats: const {
            'points': 80,
            'darts': 24,
          }),
          PlayerResult(name: 'Mia', placement: 2, stats: const {
            'points': 41,
            'darts': 24,
          }),
        ],
      ),
    );

    expect(find.text('SCORE PER ROUND'), findsNothing,
        reason: 'the chart stays suppressed on a roster change');
    expect(find.text('18:42'), findsOneWidget,
        reason: 'DURATION is the one summary value that survives a null '
            'throwHistory');
    expect(find.text('MATCH SUMMARY'), findsOneWidget);
    expect(find.text('· partly unavailable'), findsOneWidget,
        reason: 'the summary owns up to the cells it cannot fill');

    // DETAILS is enabled, not just painted: tapping it must open the
    // drill-down on the flagged entry.
    await tester.tap(find.text('▶ DETAILS'));
    await tester.pumpAndSettle();
    expect(find.byType(GameDetailScreen), findsOneWidget);
    expect(find.text('MATCH DETAILS'), findsOneWidget);
  });

  testWidgets('an empty result list does not crash the screen',
      (tester) async {
    await pump(tester, GameResult(gameMode: 'x01', results: const []));
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
