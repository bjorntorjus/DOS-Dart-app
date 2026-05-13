import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('X01 501 free-out: P0 checks out via triggerCheckoutForTest, post-game shows P0 as winner',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      GameScreen(
        players: buildPlayers(names: ['P0', 'P1'], startingScore: 501),
        startingScore: 501,
        masterOut: 'none',
        handicap: false,
        noBust: false,
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    final dynamic dynState = state;

    // Fast-forward P0 to score 40, leaving D20 for checkout.
    dynState.injectScoreForTest(0, 40);
    await tester.pump();

    // Verify the displayed score reads 40 for P0 (sanity check that the
    // injection reached the UI).
    expect(find.text('40'), findsWidgets);

    // Fire the production game-end path via the @visibleForTesting hook.
    // This mirrors what _onHit does when it detects score == 0:
    // adds the player to finishedPlayers, sets winnerIndex, marks game
    // fully over, and calls _showPostGame().
    dynState.injectScoreForTest(0, 0);
    await tester.pump();
    dynState.triggerCheckoutForTest(0);

    // Pump until PostGameScreen appears (Navigator.push is async).
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.byType(PostGameScreen), findsOneWidget,
        reason: 'PostGameScreen should appear after P0 checks out');

    // Winner name should appear on the post-game screen.
    expect(find.text('P0'), findsWidgets,
        reason: 'Winner name P0 should appear on PostGameScreen');

    // The Undo button is labelled '↶ Back' in post_game_screen.dart.
    expect(find.text('↶ Back'), findsOneWidget,
        reason: 'PostGameScreen should show the Undo/Back button');
  });
}
