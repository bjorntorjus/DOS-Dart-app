import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Regression tests for the mid-game roster rules from the 2026-07-06 audit
/// (F5-F9): removals must not soft-lock/freeze/corrupt games, and undo must
/// neither crash after an add nor resurrect a removed player.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> sized(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('ATC F5: a player removed mid-round cannot hold the round open',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'P0', score: 1),
          Player(name: 'P1', score: 1),
          Player(name: 'P2', score: 1),
        ],
        config: const AroundTheClockConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));

    // P0 completes a full turn (3 misses).
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(0, 1);
    }
    // P1 is now current, mid-round — remove them.
    expect(s.currentPlayerIndexForTest, 1);
    s.removePlayerForTest(1);
    await tester.pump();
    final roundBefore = s.roundNumberForTest;
    // P2 completes their turn.
    expect(s.currentPlayerIndexForTest, 2);
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(0, 1);
    }
    await tester.pump();

    // Before the fix, the removed P1 kept _isRoundComplete false forever, so
    // the round never resolved and the game could never end.
    expect(s.roundNumberForTest, roundBefore + 1,
        reason: 'removed player must not hold the round open (soft-lock)');
  });

  testWidgets(
      'Cricket F7: removing the last active players ends the game '
      'instead of freezing the rotation', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // Remove two players; the last removal leaves one active → game over
    // (before the fix this could spin _advancePlayer forever).
    s.removePlayerForTest(1);
    await tester.pump();
    s.removePlayerForTest(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Game ended: the result screen is shown instead of a frozen UI.
    expect(find.text('✓ FINISH GAME'), findsOneWidget,
        reason: 'removal down to one active player must end the game');
  });

  testWidgets(
      'Cricket F8/F9: undo after add-player is a safe no-op, and undo '
      'never resurrects a removed player', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // P0 throws a dart, then a player is added mid-game.
    await s.registerHitForTest(20, 1);
    s.addPlayerForTest(
        SavedPlayer(id: 'x', name: 'X', createdAt: DateTime(2026, 1, 1)));
    await tester.pump();

    // Undo across the add boundary used to RangeError mid-setState; it must
    // now be a no-op (roster changes reset undo history).
    s.undoForTest();
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'undo across an add must not crash');

    // F9: P0 throws again and is removed right after their dart (while still
    // current), then undo — P0 must stay removed.
    await s.registerHitForTest(20, 1);
    expect(s.currentPlayerIndexForTest, 0);
    s.removePlayerForTest(0);
    await tester.pump();
    final currentAfterRemoval = s.currentPlayerIndexForTest;
    expect(currentAfterRemoval, isNot(0));

    s.undoForTest();
    await tester.pump();
    expect(s.finishedPlayersForTest.contains(0), isTrue,
        reason: 'undo must not resurrect a removed player into the rotation');
    expect(s.currentPlayerIndexForTest, isNot(0),
        reason: 'a removed player must never become the current thrower');
  });

  testWidgets(
      'Splitscore F6: removing the last-in-rotation player advances the '
      'round instead of replaying it, and turn state does not leak',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const HalveItConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));

    // Splitscore starts every player at 40. Round 1 (target 15): P0 and P1
    // each score 3×15=45 → 85; P2 hits one 15 mid-turn and is then removed.
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(15, 1); // P0: 40+45 = 85
    }
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(15, 1); // P1: 85
    }
    expect(s.currentPlayerIndexForTest, 2);
    await s.onDartHitForTest(15, 1); // P2 has 15 turn points, turnHasHit=true
    expect(s.currentRoundIndexForTest, 0);
    expect(s.totalScoresForTest[0], 85);

    s.removePlayerForTest(2);
    await tester.pump();

    // The round must ADVANCE (P2 was last in rotation) — not wrap back to P0
    // in the same round, which double-counted everyone's turns.
    expect(s.currentRoundIndexForTest, 1,
        reason: 'removing the last player in rotation ends the round');
    expect(s.currentPlayerIndexForTest, 0);

    // And P2's half-played turn must not leak: P0 misses round 2 (target 16)
    // → P0 must be HALVED from 85 to 42. If turnHasHit had leaked from P2,
    // P0 would keep 85 (halving is skipped when the turn had a hit).
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(3, 1); // wrong number = miss for round 16
    }
    expect(s.totalScoresForTest[0], 42,
        reason: 'P0 halved from 85 — no inherited turn points/hit flag');
  });

  testWidgets(
      'Killer F7: removing the second-to-last alive player ends the game',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const KillerConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));

    // Assignment phase: each player claims a number.
    await s.onDartHitForTest(5, 1);
    await s.onDartHitForTest(7, 1);
    await s.onDartHitForTest(9, 1);
    await tester.pump();

    // Remove P1, then P2 → only P0 alive → winner + result screen
    // (before the fix the rotation looped forever).
    s.removePlayerForTest(1);
    await tester.pump();
    s.removePlayerForTest(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(s.winnerIndexForTest, 0,
        reason: 'last player standing after removals must win');
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
  });

  testWidgets('Killer F8: undo after add-player is a safe no-op',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const KillerConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));

    // Assignment phase.
    await s.onDartHitForTest(5, 1);
    await s.onDartHitForTest(7, 1);
    await s.onDartHitForTest(9, 1);
    await tester.pump();

    // P0 throws in the main phase, then a player joins.
    await s.onDartHitForTest(5, 2);
    s.addPlayerForTest(
        SavedPlayer(id: 'x', name: 'X', createdAt: DateTime(2026, 1, 1)));
    await tester.pump();

    // Undo used to restore N-length lists over an N+1 roster → RangeError on
    // the next build. Must be a no-op now.
    s.undoForTest();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(s.livesForTest.length, 4,
        reason: 'state lists must keep the post-add length');
  });
}
