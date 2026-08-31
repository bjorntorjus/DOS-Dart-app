import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';

DartThrow t(int seat, int seg, int mul, {int turn = 0, int sb = 0}) =>
    DartThrow(
      playerIndex: seat,
      segment: seg,
      multiplier: mul,
      points: seg * mul,
      scoreBefore: sb,
      turnNumber: 0,
      scoreAtStartOfTurn: sb,
      turnId: turn,
      roundNumber: 0,
    );

void main() {
  testWidgets('cricket result carries its target list for the summary replay',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: true,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
    final result = state.buildGameResultForTest() as GameResult;

    expect(result.modeExtras?['targets'], [15, 16, 17, 18, 19, 20, 25]);
  });

  testWidgets('ATC result carries countMultiples and the target sequence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [Player(name: 'A', score: 1), Player(name: 'B', score: 1)],
        config: const AroundTheClockConfig(),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic state = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
    final result = state.buildGameResultForTest() as GameResult;

    expect(result.modeExtras?['countMultiples'], isTrue);
    expect(result.modeExtras?['sequence'],
        [for (var n = 1; n <= 20; n++) n]);
  });

  testWidgets('the ATC result screen labels the cell BEST ROUND with hits',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PostGameScreen(
        result: GameResult(
          gameMode: 'aroundTheClock',
          durationSeconds: 60,
          results: [
            PlayerResult(
                name: 'Jonas',
                placement: 1,
                stats: const {'reached': 21, 'darts': 6}),
            PlayerResult(
                name: 'Mia',
                placement: 2,
                stats: const {'reached': 5, 'darts': 6}),
          ],
          throwHistory: [
            t(0, 5, 1, turn: 0, sb: 5),
            t(0, 6, 2, turn: 0, sb: 6), // double = 2 targets → turn clears 3
            t(0, 0, 0, turn: 0, sb: 8),
            t(1, 4, 1, turn: 1, sb: 4),
          ],
          progressionMode: 'aroundTheClock',
          modeExtras: {
            'countMultiples': true,
            'sequence': [for (var n = 1; n <= 20; n++) n],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('BEST ROUND'), findsOneWidget);
    expect(find.text('BEST TURN'), findsNothing);
    expect(find.text('3'), findsWidgets);
    expect(find.text('JONAS · R1'), findsOneWidget);
  });
}
