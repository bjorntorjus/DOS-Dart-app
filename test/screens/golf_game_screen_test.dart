import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/golf_engine.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_hero.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_leaderboard.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_status_plate.dart'
    show GolfPlateMode;

/// Smoke test for the DOSSEDART Golf cockpit's core loop: tee off → a miss
/// (lying) → a made dart that ends the hole and advances to the next player.
///
/// Mirrors `shanghai_postgame_undo_test.dart`'s harness: platform channels
/// for flutter_tts/battery_plus are stubbed and pump()+Duration is used
/// instead of pumpAndSettle (which would hang on the unmocked audioplayers
/// channel). The dart-hit path is driven via the @visibleForTesting
/// onDartHitForTest() wrapper, same convention as the other cockpits.
///
/// Cockpit v2 (2026-07-20) is taller than the old single-active-card
/// layout (hero block + standalone leaderboard + windowed strip), so every
/// test below sizes the test surface to a tablet-like viewport before
/// pumping — same pattern as `wildcard_game_screen_test.dart`'s
/// physicalSize overrides, just applied per-test via [_useTabletViewport].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel = MethodChannel(
    'dev.fluttercommunity.plus/battery/method',
  );
  final spoken = <String>[];

  void useTabletViewport(WidgetTester tester) {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    tester.view.physicalSize = const Size(820, 1500);
    tester.view.devicePixelRatio = 1.0;
  }

  setUp(() {
    spoken.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
          if (call.method == 'speak') {
            spoken.add(call.arguments as String);
            // TtsService's queue only advances once flutter_tts reports
            // speak.onComplete; simulate it so every queued announcement
            // (not just the first) reaches this mock — same pattern as
            // undo_back_tts_test.dart.
            scheduleMicrotask(() {
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .handlePlatformMessage(
                    'flutter_tts',
                    const StandardMethodCodec().encodeMethodCall(
                      const MethodCall('speak.onComplete'),
                    ),
                    (data) {},
                  );
            });
          }
          if (call.method == 'getVoices' || call.method == 'getLanguages') {
            return <dynamic>[];
          }
          return 1;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
          if (call.method == 'getBatteryLevel') return 100;
          if (call.method == 'getBatteryState') return 'full';
          return null;
        });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    TtsService.instance.resetForTesting();
  });

  testWidgets('golf cockpit: tee off → lying → hole result', (tester) async {
    useTabletViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: GolfGameScreen(
          players: [
            Player(name: 'A', score: 0),
            Player(name: 'B', score: 0),
          ],
          config: const GolfConfig(holes: 9),
        ),
      ),
    );
    await tester.pump();
    var hero = tester.widget<GolfHero>(find.byType(GolfHero));
    expect(hero.targetNumber, 1);
    expect(hero.playoff, isFalse);
    expect(find.textContaining('TEE OFF'), findsOneWidget);

    final state = tester.state<State<GolfGameScreen>>(
      find.byType(GolfGameScreen),
    );
    final dyn = state as dynamic;
    dyn.onDartHitForTest(0); // miss
    await tester.pump();
    expect(find.text('1 MISS'), findsOneWidget);
    dyn.onDartHitForTest(2); // double after 1 miss = 3 = PAR
    await tester.pump();
    final engine = dyn.engineForTest as GolfEngine;
    expect(engine.scorecards[0][0], 3);
    expect(engine.currentPlayerIndex, 1);
    hero = tester.widget<GolfHero>(find.byType(GolfHero));
    expect(hero.lie, 3); // result window still showing A's PAR
    expect(hero.plateMode, GolfPlateMode.result);
  });

  testWidgets(
    'hole-result window shows the finishing player, not the incoming one',
    (tester) async {
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();

      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      dyn.onDartHitForTest(0); // A misses
      await tester.pump();
      dyn.onDartHitForTest(2); // A hits a double after 1 miss = 3 strokes = PAR
      await tester.pump();

      // Immediately (before the 1s result window elapses) the engine has
      // already advanced to B, but the hero must still read A's identity and
      // A's just-finished result — not B's, and not a phantom pip for B.
      final engine = dyn.engineForTest as GolfEngine;
      expect(engine.currentPlayerIndex, 1); // engine moved on to B
      var hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.playerName, 'A');
      expect(hero.lie, 3);
      expect(hero.plateMode, GolfPlateMode.result);
      expect(hero.dartLabels.length, 2); // A's actual darts: 1 miss + 1 hit
      expect(hero.nextPlayerName, 'B');
      // The term chip inside the hero (not the constant "PAR 3" text — the
      // input console no longer carries term sub-labels at all).
      expect(
        find.descendant(of: find.byType(GolfHero), matching: find.text('PAR')),
        findsOneWidget,
      );
      expect(find.textContaining('LYING'), findsNothing);
      // The leaderboard is a live readout (not frozen to the hero's window):
      // A's just-earned result and B's now-active status are both visible.
      var board = tester.widget<GolfLeaderboard>(find.byType(GolfLeaderboard));
      expect(board.entries.map((e) => e.name).toSet(), {'A', 'B'});
      expect(board.entries.firstWhere((e) => e.name == 'B').isActive, isTrue);
      expect(board.entries.firstWhere((e) => e.name == 'A').holeStroke, 3);

      // After the 1s window elapses the hero hands off to B for their tee off.
      await tester.pump(const Duration(milliseconds: 1100));
      hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.playerName, 'B');
      expect(hero.lie, isNull);
      expect(hero.plateMode, GolfPlateMode.teeOff);
      expect(find.text('▸ TEE OFF · LAST DART COUNTS'), findsOneWidget);
      board = tester.widget<GolfLeaderboard>(find.byType(GolfLeaderboard));
      expect(board.entries.map((e) => e.name).toSet(), {'A', 'B'});
      expect(board.entries.firstWhere((e) => e.name == 'B').isActive, isTrue);
    },
  );

  testWidgets(
    'hole-result window keeps the finished hole target when rotation wraps',
    (tester) async {
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();

      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      dyn.onDartHitForTest(1); // A pars hole 1
      await tester.pump();

      // B is last in rotation this hole — when B finishes, the engine's
      // _advanceToNextActive() already bumps currentHole to hole 2 before
      // _handleHoleEnd runs. The hero must still show hole 1's target next to
      // B's just-finished result, not hole 2's.
      dyn.onDartHitForTest(1); // B pars hole 1, wraps rotation
      await tester.pump();

      var hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.playerName, 'B');
      expect(hero.lie, 3);
      expect(hero.targetNumber, 1);
      expect(hero.playoff, isFalse);

      // After the 1s window elapses the hero hands off to hole 2's live target.
      await tester.pump(const Duration(milliseconds: 1100));
      hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.targetNumber, 2);
    },
  );

  testWidgets(
    'dart round-tagging: the hole-closing dart keeps the hole it closed, '
    'not the incremented one',
    (tester) async {
      // Regression pin (final review, item 1): _onDartHit used to read
      // engine.holeNumber AFTER applyDart. When the finishing seat is last in
      // rotation, applyDart's _advanceToNextActive() already bumps
      // currentHole, so B's hole-closing dart got mis-tagged with hole 2
      // instead of the hole it actually closed out (1).
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();

      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      dyn.onDartHitForTest(1); // A pars hole 1
      await tester.pump();
      dyn.onDartHitForTest(1); // B pars hole 1, wraps rotation to hole 2
      await tester.pump();

      final throwHistory = dyn.throwHistory as List<dynamic>;
      expect(throwHistory.length, 2);
      for (final t in throwHistory) {
        expect(
          (t as dynamic).roundNumber,
          1,
          reason:
              'both hole-1 darts, including the hole-closing one for '
              'the last seat in rotation, must keep roundNumber == 1',
        );
      }

      dyn.onDartHitForTest(1); // A pars hole 2
      await tester.pump();
      expect((throwHistory.last as dynamic).roundNumber, 2);
    },
  );

  testWidgets('sudden death overlay appears on tie and auto-dismisses', (
    tester,
  ) async {
    useTabletViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: GolfGameScreen(
          players: [
            Player(name: 'A', score: 0),
            Player(name: 'B', score: 0),
          ],
          config: const GolfConfig(holes: 9),
        ),
      ),
    );
    await tester.pump();
    final dyn =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
            as dynamic;
    for (var h = 0; h < 9; h++) {
      dyn.onDartHitForTest(1); // A par
      await tester.pump(
        const Duration(seconds: 2),
      ); // let result-display timers elapse
      dyn.onDartHitForTest(1); // B par
      if (h < 8) await tester.pump(const Duration(seconds: 2));
    }
    await tester
        .pump(); // final dart tied the round → overlay is up; do NOT elapse its 1s timer yet
    // Both the moment overlay's title AND the always-present strip zone's
    // GolfSuddenDeathChain header read "SUDDEN DEATH" once the playoff opens.
    expect(find.text('SUDDEN DEATH'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 1100)); // 1s auto-dismiss
    // The overlay is gone, but the chain (v3 D4: zone is always present)
    // keeps its header up for the rest of the playoff.
    expect(find.text('SUDDEN DEATH'), findsOneWidget);
    expect(find.textContaining('19'), findsWidgets); // playoff target visible
  });

  testWidgets(
    'regulation end with visible opponents does not crash the cockpit build',
    (tester) async {
      // Regression pin for the game-end build guard: once regulation ends
      // outright (no tie -> no sudden death), engine.currentHole == holes,
      // one past the scorecards' valid indices. The leaderboard-entries
      // builder in golf_game_screen.dart short-circuits on engine.gameOver
      // before indexing engine.scorecards[i][engine.currentHole] — this test
      // drives a real game to that exact state via the screen's dart-hit path
      // (not the engine directly) so the build actually runs with the
      // leaderboard visible on the winning final dart.
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
              Player(name: 'C', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();
      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      final engine = dyn.engineForTest as GolfEngine;

      // A doubles every hole (2 strokes), B and C single every hole (3
      // strokes) -> A finishes on 18, B and C tie for 2nd on 27. A is the
      // sole leader, so regulation ends outright, with no sudden death.
      for (var h = 0; h < 9; h++) {
        dyn.onDartHitForTest(2); // A: double -> 2 strokes
        await tester.pump(const Duration(seconds: 2));
        dyn.onDartHitForTest(1); // B: single -> 3 strokes
        await tester.pump(const Duration(seconds: 2));
        dyn.onDartHitForTest(1); // C: single -> 3 strokes
        if (h < 8) await tester.pump(const Duration(seconds: 2));
      }
      // C's final dart wrapped the rotation, advancing currentHole to 9
      // (== holes) and ending the game with A as the sole leader -- the
      // leaderboard just rendered with engine.gameOver == true and
      // engine.currentHole one past the scorecards' valid range.
      expect(tester.takeException(), isNull);
      expect(engine.gameOver, isTrue);
      expect(engine.winnerIndex, 0);
      expect(engine.wonBySuddenDeath, isFalse);

      // The screen's own _handleHoleEnd already called _onGameEnd on that
      // final dart; onGameEndForTest must be a safe no-op against the
      // _gameEndFired guard, not a double-fire.
      dyn.onGameEndForTest();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(PostGameScreen), findsOneWidget);
    },
  );

  testWidgets(
    'removing the finishing seat during the hole-result window does not '
    'crash and the game continues',
    (tester) async {
      // No existing test removes a player while the 1s hole-result window
      // (_lastHoleStrokes/_lastHoleSeat/_resultTimer) is open. This pins that
      // the window's captured seat survives a roster mutation on the very
      // seat it is displaying -- removing the FINISHING player mid-window,
      // before the timer elapses.
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
              Player(name: 'C', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();
      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      final engine = dyn.engineForTest as GolfEngine;

      dyn.onDartHitForTest(1); // A: single -> pars hole 1, window opens
      // Remove A -- the seat the just-opened result window is displaying --
      // BEFORE the 1s window elapses.
      dyn.removePlayerForTest(0);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(engine.gameOver, isFalse);
      expect(dyn.removedPlayerIndicesForTest, {0});

      // The window is still showing A's just-finished result even though A
      // is now a skipped seat -- but the leaderboard (a live readout) already
      // excludes A entirely, since it filters skipped seats every build.
      var hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.playerName, 'A');
      expect(hero.lie, 3);
      var board = tester.widget<GolfLeaderboard>(find.byType(GolfLeaderboard));
      expect(board.entries.map((e) => e.name), isNot(contains('A')));

      // Let the 1s result window elapse -- the hero must hand off to the
      // engine's actual next (non-skipped) thrower, B, and the game must
      // still be playable.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(tester.takeException(), isNull);
      expect(engine.currentPlayerIndex, 1);
      hero = tester.widget<GolfHero>(find.byType(GolfHero));
      expect(hero.playerName, 'B');
      expect(hero.lie, isNull);
      expect(find.text('▸ TEE OFF · LAST DART COUNTS'), findsOneWidget);
      board = tester.widget<GolfLeaderboard>(find.byType(GolfLeaderboard));
      expect(board.entries.map((e) => e.name).toSet(), {
        'B',
        'C',
      }); // A excluded (skipped)

      dyn.onDartHitForTest(1); // B: single -> pars hole 1, game continues
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(engine.scorecards[1][0], 3);
      expect(engine.currentPlayerIndex, 2); // advanced to C
    },
  );

  testWidgets(
    'TTS diet: misses are spoken, hits carry no dart callout, the hole '
    'result speaks the term, and the next-player handoff carries the hole',
    (tester) async {
      // Spec rev 2026-07-20b (golf-design.md §6): no dart-value callouts on
      // hits, the hole-result phrase is the golf term alone, and
      // announceNextPlayer carries the upcoming target so players know what
      // to throw at next. Revised 2026-08-07 (tablet QA): a miss now speaks
      // 'miss' — silence read as a dropped tap at the oche.
      // tts_enabled defaults to false in AppSettings, so it must be set
      // explicitly for TTS output to reach the mocked channel.
      useTabletViewport(tester);
      SharedPreferences.setMockInitialValues({'tts_enabled': true});
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;

      spoken.clear();
      dyn.onDartHitForTest(0); // A misses — must be audibly confirmed
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        spoken,
        contains('miss'),
        reason: 'a registered miss must be spoken, not silent',
      );

      spoken.clear();
      dyn.onDartHitForTest(1); // A single after 1 miss -> 4 strokes = BOGEY
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        spoken,
        contains('bogey!'),
        reason: 'hole result must speak the bare term, no Ace!/points',
      );
      expect(
        spoken.any((s) => s == 'S7' || s == 'single 7' || s == '7'),
        isFalse,
        reason: 'a hit still gets no dart-value callout',
      );
      expect(
        spoken.any((s) => s == 'B, hole 1'),
        isTrue,
        reason: 'next-player handoff must carry the still-open hole target',
      );

      spoken.clear();
      dyn.onDartHitForTest(1); // B single, no misses -> 3 strokes = PAR, wraps
      await tester.pump(const Duration(milliseconds: 100));
      expect(spoken, contains('par!'));
      expect(
        spoken.any((s) => s == 'A, hole 2'),
        isTrue,
        reason: 'once the round wraps, the target rides to the new hole',
      );
    },
  );

  testWidgets('holeDartLabels tracks the displayed hole in throw order', (
    tester,
  ) async {
    // v3 hero chip plumbing (Task 1): a hit always ends the hole, so the
    // mid-hole (no result window) state can only ever be a run of misses —
    // the full label list including the finishing hit only ever exists
    // during the 1s result window (or, for a wash, at hole-close). This
    // drives: miss, miss, then a hit that closes the hole with 2 misses
    // stacked (BOGEY, since strokes = (4-1)+2 = 5... use a double instead so
    // the arithmetic stays legible: (4-2)+2 = 4 = BOGEY).
    useTabletViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: GolfGameScreen(
          players: [
            Player(name: 'A', score: 0),
            Player(name: 'B', score: 0),
          ],
          config: const GolfConfig(holes: 9),
        ),
      ),
    );
    await tester.pump();

    final dyn =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
            as dynamic;

    expect(dyn.holeDartLabels, <String>[]);

    dyn.onDartHitForTest(0); // A misses
    await tester.pump();
    expect(dyn.holeDartLabels, ['✗']);

    dyn.onDartHitForTest(0); // A misses again
    await tester.pump();
    expect(dyn.holeDartLabels, ['✗', '✗']);

    dyn.onDartHitForTest(2); // A doubles hole 1 after 2 misses -> ends hole
    await tester.pump();
    // Result window: frozen labels include the finishing hit, in throw order.
    expect(dyn.holeDartLabels, ['✗', '✗', 'D1']);

    // After the 1s result window elapses, the hero hands off to B's fresh
    // hole — labels reset to empty.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(dyn.holeDartLabels, <String>[]);
  });

  testWidgets(
    'undo during the hole-result window clears frozen labels and steps '
    'back through the live miss-derived state',
    (tester) async {
      // Reviewer-verified scenario promoted to the permanent suite: undoing
      // WHILE the 1s result window is still open must clear
      // _lastHoleDartLabels immediately (not wait for the timer), falling
      // back to holeDartLabels' live derivation — which, per the getter's own
      // invariant, is just List.filled(engine.missesThisHole, '✗') — and each
      // further undo steps that live count back down one dart at a time,
      // since GolfEngine.undo() restores missesThisHole to its value as of
      // just-before the undone dart.
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();

      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;

      dyn.onDartHitForTest(0); // A misses
      await tester.pump();
      dyn.onDartHitForTest(0); // A misses again
      await tester.pump();
      dyn.onDartHitForTest(1); // A singles hole 1 after 2 misses -> ends hole
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗', '✗', 'S1']);

      // Undo mid-window, before the 1s timer ever fires.
      dyn.onUndoForTest();
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗', '✗']);

      dyn.onUndoForTest();
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗']);

      dyn.onUndoForTest();
      await tester.pump();
      expect(dyn.holeDartLabels, <String>[]);
    },
  );

  testWidgets(
    'sudden death: playoff turns sharing engine.holeNumber never leak '
    "labels across seats or across the next target's fresh turn",
    (tester) async {
      // Reviewer-verified scenario promoted to the permanent suite. Once
      // regulation ends in a tie, GolfEngine.currentHole is pinned at `holes`
      // for the rest of the game — every playoff turn, on every target (19,
      // 20, Bull, cycling), reads the exact same engine.holeNumber (and so
      // the exact same DartThrow.roundNumber). This is precisely why
      // holeDartLabels' live derivation is engine.missesThisHole-based (never
      // a roundNumber filter over throwHistory) and the frozen capture in
      // _showHoleResult slices the LAST N throws for the finishing seat
      // rather than filtering by round: a roundNumber-based filter would
      // accumulate every prior playoff turn's darts for that seat. This test
      // pins that no such leakage happens, across a seat handoff (A -> B) and
      // across a target change (19 -> 20 -> Bull), and exercises the bull
      // '25'/'50' labels along the way.
      useTabletViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: GolfGameScreen(
            players: [
              Player(name: 'A', score: 0),
              Player(name: 'B', score: 0),
            ],
            config: const GolfConfig(holes: 9),
          ),
        ),
      );
      await tester.pump();
      final dyn =
          tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
              as dynamic;
      final engine = dyn.engineForTest as GolfEngine;

      // Tie every regulation hole on PAR so sudden death opens on target 19 —
      // same setup as the "sudden death overlay" test above.
      for (var h = 0; h < 9; h++) {
        dyn.onDartHitForTest(1); // A par
        await tester.pump(const Duration(seconds: 2));
        dyn.onDartHitForTest(1); // B par
        if (h < 8) await tester.pump(const Duration(seconds: 2));
      }
      await tester.pump(); // final dart tied the round -> overlay is up
      await tester.pump(const Duration(milliseconds: 1100)); // overlay dismiss

      expect(engine.inSuddenDeath, isTrue);
      expect(engine.targetNumber, 19);
      expect(engine.currentPlayerIndex, 0); // A throws first in the playoff
      final fixedHoleNumber = engine.holeNumber;
      expect(dyn.holeDartLabels, <String>[]);

      // --- Target 19: A misses, then singles -> ends A's turn, ties nobody
      // yet (B hasn't thrown). Result window freezes A's labels.
      dyn.onDartHitForTest(0); // A misses on 19
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗']);
      dyn.onDartHitForTest(1); // A singles 19 -> 4 strokes, ends A's turn
      await tester.pump();
      expect(engine.holeNumber, fixedHoleNumber); // unchanged by the turn
      expect(dyn.holeDartLabels, ['✗', 'S19']); // A's frozen result

      // B's turn is already live on the engine, but the getter must keep
      // returning A's frozen result until the window elapses.
      expect(engine.currentPlayerIndex, 1);
      expect(dyn.holeDartLabels, ['✗', 'S19']);

      await tester.pump(const Duration(milliseconds: 1100));
      // B's turn starts with EMPTY live labels — no leakage from A's frozen
      // ['✗', 'S19'], despite sharing the exact same engine.holeNumber.
      expect(dyn.holeDartLabels, <String>[]);

      // B misses, then singles -> ties A at 4 strokes -> playoff continues to
      // target 20 (still sharing the same fixedHoleNumber).
      dyn.onDartHitForTest(0); // B misses on 19
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗']);
      dyn.onDartHitForTest(1); // B singles 19 -> ties A -> on to target 20
      await tester.pump();
      expect(engine.holeNumber, fixedHoleNumber);
      expect(dyn.holeDartLabels, ['✗', 'S19']); // B's frozen result

      await tester.pump(const Duration(milliseconds: 1100));
      expect(engine.targetNumber, 20);
      expect(engine.currentPlayerIndex, 0); // A leads off the new target too
      expect(dyn.holeDartLabels, <String>[]); // no leakage from B's turn

      // --- Target 20: same shape, both tie again -> on to Bull (25).
      dyn.onDartHitForTest(0); // A misses on 20
      await tester.pump();
      dyn.onDartHitForTest(1); // A singles 20 -> 4 strokes
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗', 'S20']);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(dyn.holeDartLabels, <String>[]);

      dyn.onDartHitForTest(0); // B misses on 20
      await tester.pump();
      dyn.onDartHitForTest(1); // B singles 20 -> ties A -> on to Bull
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗', 'S20']);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(engine.targetNumber, 25);
      expect(engine.currentPlayerIndex, 0);
      expect(dyn.holeDartLabels, <String>[]);

      // --- Bull (25): no triple, so the tie is engineered with single/double
      // only. A misses then doubles (3 strokes) -> label '50'; B singles
      // clean (3 strokes) -> label '25' -> tie -> cycles back to target 19.
      dyn.onDartHitForTest(0); // A misses on Bull
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗']);
      dyn.onDartHitForTest(2); // A doubles Bull -> 3 strokes, ends A's turn
      await tester.pump();
      expect(dyn.holeDartLabels, ['✗', '50']);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(engine.currentPlayerIndex, 1);
      expect(dyn.holeDartLabels, <String>[]); // no leakage from A's '50'

      dyn.onDartHitForTest(1); // B singles Bull clean -> 3 strokes, ties A
      await tester.pump();
      expect(dyn.holeDartLabels, ['25']); // single dart, no prior miss
      await tester.pump(const Duration(milliseconds: 1100));

      // Tied again -> cycles back to target 19; fresh turn, no leakage from
      // B's Bull result despite the whole playoff sharing fixedHoleNumber.
      expect(engine.targetNumber, 19);
      expect(engine.currentPlayerIndex, 0);
      expect(engine.holeNumber, fixedHoleNumber);
      expect(dyn.holeDartLabels, <String>[]);
    },
  );
}
