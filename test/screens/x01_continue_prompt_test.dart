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
