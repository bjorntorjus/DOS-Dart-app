import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';

void main() {
  testWidgets('Cricket: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: players,
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<State<CricketGameScreen>>(
        find.byType(CricketGameScreen));
    final dynamic dynState = state;

    // Remove P0 mid-game — index 0 lands in both finishedPlayers and
    // _removedPlayerIndices, mimicking the production handler.
    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'precondition: removed player must be first in finishedPlayers '
            'for the bug to surface; the helper must skip them');

    // Simulate P1 finishing — add to finishedPlayers second.
    dynState.finishedPlayersForTest.add(1);

    // Call the helper directly to verify it skips removed player.
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });

  testWidgets('X01: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 301),
      Player(name: 'P1', score: 301),
      Player(name: 'P2', score: 301),
    ];

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: players,
        startingScore: 301,
        masterOut: 'none',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pumpAndSettle();

    final state =
        tester.state<State<GameScreen>>(find.byType(GameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'precondition: removed player must be first in finishedPlayers '
            'for the bug to surface; the helper must skip them');

    dynState.finishedPlayersForTest.add(1);
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });

  testWidgets('ATC: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: players,
        config: const AroundTheClockConfig(
          includeBull: false,
          countMultiples: false,
          reverse: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'precondition: removed player must be first in finishedPlayers '
            'for the bug to surface; the helper must skip them');

    dynState.finishedPlayersForTest.add(1);
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
}
