import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shanghai: post-game Undo returns to game with gameOver=false',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      ShanghaiGameScreen(
        players: buildPlayers(names: ['P0', 'P1'], startingScore: 0),
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    );
    await tester.pumpAndSettle();

    final state =
        tester.state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
    final dynamic dynState = state;
    final engine = dynState.engineForTest;

    // Trigger instant Shanghai for P0: S+D+T on target 1 in one turn.
    engine.recordThrow(HitType.single);
    engine.recordThrow(HitType.double_);
    engine.recordThrow(HitType.triple);
    expect(engine.gameOver, isTrue);
    expect(engine.isInstantShanghai, isTrue);

    // Fire the game-end + post-game push through the production code path.
    await dynState.onGameEndForTest();
    await tester.pump(const Duration(milliseconds: 500));

    // PostGameScreen should now be visible. The Undo button is labelled
    // '↶ Back' in lib/screens/post_game_screen.dart.
    expect(find.text('↶ Back'), findsOneWidget,
        reason: 'PostGameScreen should show the Undo/Back button');

    // Tap Undo.
    await tester.tap(find.text('↶ Back').first);
    await tester.pump(const Duration(milliseconds: 500));

    // Back in ShanghaiGameScreen — verify engine state was restored.
    expect(find.byType(ShanghaiGameScreen), findsOneWidget,
        reason: 'After Undo, ShanghaiGameScreen should be on top again');
    expect(engine.gameOver, isFalse,
        reason: 'engine.undo() should clear gameOver');
  });
}
