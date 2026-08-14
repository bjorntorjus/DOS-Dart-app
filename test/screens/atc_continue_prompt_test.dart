import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

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

  Future<dynamic> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: AroundTheClockConfig(
          includeBull: false,
          countMultiples: true,
          reverse: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
  }

  // Seat A always hits its CURRENT target with a triple (3 steps with
  // countMultiples); B and C miss. Loop until A appears in finishedPlayers —
  // reading currentTargetsForTest keeps the sequence correct regardless of
  // exactly how the engine steps past 20.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s) async {
    for (var round = 0; round < 10; round++) {
      for (var d = 0; d < 3; d++) {
        if ((s.finishedPlayersForTest as List).contains(0)) break;
        final target = (s.currentTargetsForTest as List)[0] as int;
        await s.onDartHitForTest(target, target <= 20 ? 3 : 1);
      }
      if ((s.finishedPlayersForTest as List).contains(0)) break;
      for (var p = 0; p < 2; p++) {
        for (var d = 0; d < 3; d++) {
          await s.onDartHitForTest(0, 0);
        }
      }
    }
    await settle(tester);
    expect(s.finishedPlayersForTest, contains(0));
  }

  testWidgets('finisher with two active left raises the prompt, not the result',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    expect(find.text('A finished!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing resumes with the next active player',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.currentPlayerIndexForTest, isNot(0));
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
  });

  // A, B and C advance in lockstep (all hit trebles) until each needs exactly
  // one more hit. Then A finishes; because B and C can still theoretically
  // catch up this same turn, they genuinely throw (and miss) rather than
  // being auto-completed — so the round's LAST recorded throw is C's own
  // miss, not A's finish. This is the exact precondition from the finding:
  // "the last throw before END was a non-checkout dart ... by a non-finisher".
  Future<void> advanceAllToOneAway(WidgetTester tester, dynamic s) async {
    for (var round = 0; round < 6; round++) {
      for (var p = 0; p < 3; p++) {
        final target = (s.currentTargetsForTest as List)[p] as int;
        await s.onDartHitForTest(target, 3);
        await s.onDartHitForTest(0, 0);
        await s.onDartHitForTest(0, 0);
      }
    }
  }

  // Regression (2026-08-14): END GAME -> ↶ BACK must not strand
  // _gameFullyOver == true when the undone throw isn't itself a finisher's
  // own throw (here: C's final, non-finishing miss). With 2 active seats
  // (B, C) still in play, the game is not actually over.
  testWidgets(
      'END GAME then BACK does not strand the game as fully over '
      'when active players remain', (tester) async {
    final s = await pumpGame(tester);
    await advanceAllToOneAway(tester, s);

    // A finishes with one treble; B and C can still catch up this turn, so
    // they genuinely throw (and miss) rather than being auto-completed.
    await s.onDartHitForTest(19, 3);
    for (var p = 0; p < 2; p++) {
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(0, 0);
      }
    }
    await settle(tester);
    expect(find.text('A finished!'), findsOneWidget);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    await tester.tap(find.text('↶ BACK'));
    await settle(tester);

    // The undone throw was C's plain miss, not a finish — the only path
    // that already reset this flag before the fix. B and C are both still
    // active, so the game must not be marked fully over.
    expect(s.gameFullyOverForTest, isFalse,
        reason: 'undoing a non-finish dart with 2+ active players left '
            'must not leave the game stranded as fully over');

    // Replay C's final dart of the round — the round resolves again, and
    // must not force-finalize on the (now correctly cleared) flag.
    await s.onDartHitForTest(0, 0);
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing,
        reason: 'B and C are still active — the round completing again '
            'must not jump straight to the final result screen');
    expect(s.gameFullyOverForTest, isFalse);
  });
}
