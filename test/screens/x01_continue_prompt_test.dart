import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The keep-playing/end choice moved OUT of the result screen (2026-08-14):
/// a mid-game finisher raises a dialog on the game screen; the result screen
/// only ever appears once the game is final.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpThreePlayerGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501),
          Player(name: 'B', score: 501),
          Player(name: 'C', score: 501),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  // A checks out; B and C each throw three darts so the round resolves.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s) async {
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2); // A: D20 checkout
    for (var p = 0; p < 2; p++) {
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(1, 1);
      }
    }
    await settle(tester);
  }

  testWidgets('mid-game finisher raises the prompt, not the result screen',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    expect(find.text('A checked out!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing resumes the round for the remaining players',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.finishedPlayersForTest, [0]);
    // B (seat 1) is first active and on turn.
    expect(s.currentPlayerIndexForTest, 1);
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
    expect(find.text('↻ PLAY AGAIN'), findsOneWidget);
  });

  // Regression (2026-08-14): END GAME -> ↶ BACK must not strand
  // _gameFullyOver == true when the undone throw isn't itself a finisher's
  // checkout (here: C's final, non-checkout dart of the round). With 2 active
  // seats (B, C) still in play, the game is not actually over.
  testWidgets(
      'END GAME then BACK does not strand the game as fully over '
      'when active players remain', (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    await tester.tap(find.text('↶ BACK'));
    await settle(tester);

    // The undone throw was C's plain single, not a checkout — the only path
    // that already reset this flag before the fix. B and C are both still
    // active, so the game must not be marked fully over.
    expect(s.gameFullyOverForTest, isFalse,
        reason: 'undoing a non-checkout dart with 2+ active players left '
            'must not leave the game stranded as fully over');

    // Replay C's final dart of the round — the round resolves again, and
    // must not force-finalize on the (now correctly cleared) flag.
    await s.onDartHitForTest(1, 1);
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing,
        reason: 'B and C are still active — the round completing again '
            'must not jump straight to the final result screen');
    expect(s.gameFullyOverForTest, isFalse);
  });

  // Same root cause, taken to its observable conclusion: with a 4th player
  // still active after the stranding round, a LATER genuine checkout must
  // re-open the keep-playing prompt instead of force-finalizing on the
  // flag left stranded by the earlier END GAME -> BACK.
  testWidgets(
      'a later checkout re-prompts instead of force-finalizing after '
      'an earlier END GAME was undone', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501),
          Player(name: 'B', score: 501),
          Player(name: 'C', score: 501),
          Player(name: 'D', score: 501),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    // A checks out; B, C, D each throw three darts so the round resolves
    // with 3 players (B, C, D) still active -> the keep-playing prompt.
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2);
    for (var p = 0; p < 3; p++) {
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(1, 1);
      }
    }
    await settle(tester);
    expect(find.text('A checked out!'), findsOneWidget);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    // Back undoes D's final, non-checkout dart of the round.
    await tester.tap(find.text('↶ BACK'));
    await settle(tester);
    expect(s.gameFullyOverForTest, isFalse);

    // Replay D's dart — round resolves again silently (no new finisher),
    // starting a fresh round with B, C, D still active.
    await s.onDartHitForTest(1, 1);
    await settle(tester);
    await settle(tester);
    expect(find.text('✓ FINISH GAME'), findsNothing);

    // Now B genuinely checks out this new round; C and D each finish their
    // turn with plain darts. Two players (C, D) remain active — this must
    // reopen the keep-playing prompt, not jump to the final screen.
    s.injectScoreForTest(1, 40);
    await s.onDartHitForTest(20, 2);
    for (var p = 0; p < 2; p++) {
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(1, 1);
      }
    }
    await settle(tester);
    await settle(tester);

    expect(find.text('B checked out!'), findsOneWidget,
        reason: 'the stranded gameFullyOver flag from the earlier END GAME '
            '-> BACK must not force-finalize while C and D are still active');
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('the LAST finisher goes straight to the final result screen',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);
    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    // B checks out; C throws three darts; round resolves with one active left.
    s.injectScoreForTest(1, 40);
    await s.onDartHitForTest(20, 2);
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(1, 1);
    }
    await settle(tester);
    await settle(tester);

    expect(find.text('Keep playing'), findsNothing);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
  });
}
