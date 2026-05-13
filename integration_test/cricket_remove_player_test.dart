import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cricket: removed mid-game player does not become winner',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      CricketGameScreen(
        players: buildPlayers(names: ['P0', 'P1', 'P2'], startingScore: 0),
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
    final dynamic dynState = state;

    // Remove P0 mid-game — same call the unit test uses.
    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'Precondition: removed player is first in finishedPlayers; '
            'the bug surfaces if computeWinnerForTest does not skip them');

    // Simulate P1 finishing — append to finishedPlayers second.
    dynState.finishedPlayersForTest.add(1);

    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
}
