import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';

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

  testWidgets('Splitscore: removed player is excluded from the result screen',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    // Tablet-sized surface — the classic Splitscore scaffold overflows the
    // 800×600 test default, which is unrelated to the placement logic here.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(players: players, config: const HalveItConfig()),
    ));
    await tester.pumpAndSettle();

    final state =
        tester.state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    final result = dynState.buildGameResultForTest();
    final names = [for (final r in result.results) r.name as String];

    expect(names.contains('P0'), isFalse,
        reason: 'removed player must not appear on the result screen');
    expect(result.results.length, equals(2),
        reason: 'only the two remaining players are ranked');
  });

  testWidgets('Killer: removed player is excluded from the result screen',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(
        players: players,
        config: const KillerConfig(throwToPick: false),
      ),
    ));
    await tester.pumpAndSettle();

    final state =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    final result = dynState.buildGameResultForTest();
    final names = [for (final r in result.results) r.name as String];

    expect(names.contains('P0'), isFalse,
        reason: 'removed player must not appear on the result screen');
    expect(result.results.length, equals(2),
        reason: 'only the two remaining players are ranked');
  });

  testWidgets('Cricket: removed player is excluded from the result screen',
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

    dynState.removePlayerForTest(0); // removed → sits first in finishedPlayers
    await tester.pumpAndSettle();
    dynState.finishedPlayersForTest.add(1); // P1 actually finishes

    final result = dynState.buildGameResultForTest();
    final names = [for (final r in result.results) r.name as String];

    expect(names.contains('P0'), isFalse,
        reason: 'removed player must not appear on the result screen');
    final p1 = result.results.firstWhere((r) => r.name == 'P1');
    expect(p1.placement, equals(1),
        reason: 'the real finisher P1 takes 1st, not the removed P0');
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

  testWidgets('X01: removed player is excluded from the result screen',
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

    final state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0); // removed → sits first in finishedPlayers
    await tester.pumpAndSettle();
    dynState.finishedPlayersForTest.add(1); // P1 actually finishes

    final result = dynState.buildGameResultForTest();
    final names = [for (final r in result.results) r.name as String];

    expect(names.contains('P0'), isFalse,
        reason: 'removed player must not appear on the result screen');
    final p1 = result.results.firstWhere((r) => r.name == 'P1');
    expect(p1.placement, equals(1),
        reason: 'the real finisher P1 takes 1st, not the removed P0');
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

  testWidgets('ATC: removed player is excluded from the result screen',
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

    dynState.removePlayerForTest(0); // removed → sits first in finishedPlayers
    await tester.pumpAndSettle();
    dynState.finishedPlayersForTest.add(1); // P1 actually finishes

    final result = dynState.buildGameResultForTest();
    final names = [for (final r in result.results) r.name as String];

    expect(names.contains('P0'), isFalse,
        reason: 'removed player must not appear on the result screen');
    final p1 = result.results.firstWhere((r) => r.name == 'P1');
    expect(p1.placement, equals(1),
        reason: 'the real finisher P1 takes 1st, not the removed P0');
  });
}
