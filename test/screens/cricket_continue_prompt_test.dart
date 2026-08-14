import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
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

  Future<dynamic> pumpGame(WidgetTester tester, {int playerCount = 3}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          for (var i = 0; i < playerCount; i++)
            Player(name: String.fromCharCode(65 + i), score: 0),
        ],
        config: CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: true,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<CricketGameScreen>>(
        find.byType(CricketGameScreen));
  }

  // A closes everything over three of A's turns; every other player throws
  // three misses in between so the rotation keeps moving.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s,
      {required int others}) async {
    Future<void> othersMiss() async {
      for (var p = 0; p < others; p++) {
        for (var d = 0; d < 3; d++) {
          await s.registerHitForTest(0, 0);
        }
      }
    }

    await s.registerHitForTest(15, 3);
    await s.registerHitForTest(16, 3);
    await s.registerHitForTest(17, 3);
    await othersMiss();
    await s.registerHitForTest(18, 3);
    await s.registerHitForTest(19, 3);
    await s.registerHitForTest(20, 3);
    await othersMiss();
    await s.registerHitForTest(25, 1);
    await s.registerHitForTest(25, 1);
    await s.registerHitForTest(25, 1);
    await settle(tester);
  }

  testWidgets('finisher with two active left raises the prompt, not the result',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    expect(find.text('A finished!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing advances the turn off the finisher seat',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.finishedPlayersForTest, [0]);
    expect(s.currentPlayerIndexForTest, isNot(0));
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
  });

  testWidgets('two players: the first finisher ends the game with no prompt',
      (tester) async {
    final s = await pumpGame(tester, playerCount: 2);
    await finishPlayerA(tester, s, others: 1);
    await settle(tester);

    expect(find.text('A finished!'), findsNothing);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
  });
}
