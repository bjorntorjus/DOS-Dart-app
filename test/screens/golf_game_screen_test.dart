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
import 'package:dart_scoring/widgets/dossedart/golf/dossedart_golf_active_card.dart';

/// Smoke test for the DOSSEDART Golf cockpit's core loop: tee off → a miss
/// (lying) → a made dart that ends the hole and advances to the next player.
///
/// Mirrors `shanghai_postgame_undo_test.dart`'s harness: platform channels
/// for flutter_tts/battery_plus are stubbed and pump()+Duration is used
/// instead of pumpAndSettle (which would hang on the unmocked audioplayers
/// channel). The dart-hit path is driven via the @visibleForTesting
/// onDartHitForTest() wrapper, same convention as the other cockpits.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');
  final spoken = <String>[];

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
            const StandardMethodCodec()
                .encodeMethodCall(const MethodCall('speak.onComplete')),
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
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    expect(find.text('HOLE 1 · PAR 3'), findsOneWidget);
    expect(find.textContaining('TEE OFF'), findsOneWidget);

    final state =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    final dyn = state as dynamic;
    dyn.onDartHitForTest(0); // miss
    await tester.pump();
    expect(find.textContaining('LYING 1'), findsOneWidget);
    dyn.onDartHitForTest(2); // double after 1 miss = 3 = PAR
    await tester.pump();
    final engine = dyn.engineForTest as GolfEngine;
    expect(engine.scorecards[0][0], 3);
    expect(engine.currentPlayerIndex, 1);
  });

  testWidgets(
      'hole-result window shows the finishing player, not the incoming one',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();

    final dyn =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
            as dynamic;
    dyn.onDartHitForTest(0); // A misses
    await tester.pump();
    dyn.onDartHitForTest(2); // A hits a double after 1 miss = 3 strokes = PAR
    await tester.pump();

    // Immediately (before the 1s result window elapses) the engine has
    // already advanced to B, but the card must still read A's identity and
    // A's just-finished result — not B's, and not a phantom pip for B.
    final engine = dyn.engineForTest as GolfEngine;
    expect(engine.currentPlayerIndex, 1); // engine moved on to B
    var card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.playerName, 'A');
    expect(card.holeStrokes, 3);
    expect(card.dartsThrown, 2); // A's actual darts this hole: 1 miss + 1 hit
    expect(card.statusLine, contains('PAR — 3 STROKES'));
    expect(card.opponents.map((o) => o.name), ['B']);

    // After the 1s window elapses the card hands off to B for their tee off.
    await tester.pump(const Duration(milliseconds: 1100));
    card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.playerName, 'B');
    expect(card.holeStrokes, isNull);
    expect(card.statusLine, contains('TEE OFF'));
    expect(card.opponents.map((o) => o.name), ['A']);
  });

  testWidgets(
      'hole-result window keeps the finished hole label when rotation wraps',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();

    final dyn =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
            as dynamic;
    dyn.onDartHitForTest(1); // A pars hole 1
    await tester.pump();

    // B is last in rotation this hole — when B finishes, the engine's
    // _advanceToNextActive() already bumps currentHole to hole 2 before
    // _handleHoleEnd runs. The card must still show hole 1's label next to
    // B's just-finished result, not hole 2's.
    dyn.onDartHitForTest(1); // B pars hole 1, wraps rotation
    await tester.pump();

    var card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.playerName, 'B');
    expect(card.holeStrokes, 3);
    expect(card.holeLabel, 'HOLE 1 · PAR 3');

    // After the 1s window elapses the card hands off to hole 2's live label.
    await tester.pump(const Duration(milliseconds: 1100));
    card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.holeLabel, 'HOLE 2 · PAR 3');
  });

  testWidgets(
      'dart round-tagging: the hole-closing dart keeps the hole it closed, '
      'not the incremented one',
      (tester) async {
    // Regression pin (final review, item 1): _onDartHit used to read
    // engine.holeNumber AFTER applyDart. When the finishing seat is last in
    // rotation, applyDart's _advanceToNextActive() already bumps
    // currentHole, so B's hole-closing dart got mis-tagged with hole 2
    // instead of the hole it actually closed out (1).
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
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
      expect((t as dynamic).roundNumber, 1,
          reason: 'both hole-1 darts, including the hole-closing one for '
              'the last seat in rotation, must keep roundNumber == 1');
    }

    dyn.onDartHitForTest(1); // A pars hole 2
    await tester.pump();
    expect((throwHistory.last as dynamic).roundNumber, 2);
  });

  testWidgets('sudden death overlay appears on tie and auto-dismisses',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    final dyn = tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
        as dynamic;
    for (var h = 0; h < 9; h++) {
      dyn.onDartHitForTest(1); // A par
      await tester.pump(const Duration(seconds: 2)); // let result-display timers elapse
      dyn.onDartHitForTest(1); // B par
      if (h < 8) await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump(); // final dart tied the round → overlay is up; do NOT elapse its 1s timer yet
    expect(find.text('SUDDEN DEATH'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100)); // 1s auto-dismiss
    expect(find.text('SUDDEN DEATH'), findsNothing);
    expect(find.textContaining('19'), findsWidgets); // playoff target visible
  });

  testWidgets(
      'regulation end with visible opponents does not crash the cockpit build',
      (tester) async {
    // Regression pin for the game-end build guard: once regulation ends
    // outright (no tie -> no sudden death), engine.currentHole == holes,
    // one past the scorecards' valid indices. The opponents-strip builder
    // in golf_game_screen.dart short-circuits on engine.gameOver before
    // indexing engine.scorecards[i][engine.currentHole] — this test drives
    // a real game to that exact state via the screen's dart-hit path (not
    // the engine directly) so the build actually runs with opponents
    // visible on the winning final dart.
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const GolfConfig(holes: 9),
      ),
    ));
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
    // opponents strip just rendered with engine.gameOver == true and
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
  });

  testWidgets(
      'removing the finishing seat during the hole-result window does not '
      'crash and the game continues',
      (tester) async {
    // No existing test removes a player while the 1s hole-result window
    // (_lastHoleStrokes/_lastHoleSeat/_resultTimer) is open. This pins that
    // the window's captured seat survives a roster mutation on the very
    // seat it is displaying -- removing the FINISHING player mid-window,
    // before the timer elapses.
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const GolfConfig(holes: 9),
      ),
    ));
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
    // is now a skipped seat.
    var card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.playerName, 'A');
    expect(card.holeStrokes, 3);

    // Let the 1s result window elapse -- the card must hand off to the
    // engine's actual next (non-skipped) thrower, B, and the game must
    // still be playable.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
    expect(engine.currentPlayerIndex, 1);
    card = tester.widget<DossedartGolfActiveCard>(
        find.byType(DossedartGolfActiveCard));
    expect(card.playerName, 'B');
    expect(card.holeStrokes, isNull);
    expect(card.statusLine, contains('TEE OFF'));
    expect(card.opponents.map((o) => o.name), ['C']); // A excluded (skipped)

    dyn.onDartHitForTest(1); // B: single -> pars hole 1, game continues
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(engine.scorecards[1][0], 3);
    expect(engine.currentPlayerIndex, 2); // advanced to C
  });

  testWidgets(
      'TTS diet: hole result speaks only the term, no per-dart callouts, '
      'and the next-player handoff carries the target hole',
      (tester) async {
    // Spec rev 2026-07-20b (golf-design.md §6): announceThrow is dropped
    // entirely (no dart-value callouts, misses are TTS-silent), the
    // hole-result phrase is the golf term alone, and announceNextPlayer
    // carries the upcoming target so players know what to throw at next.
    // tts_enabled defaults to false in AppSettings, so it must be set
    // explicitly for TTS output to reach the mocked channel.
    SharedPreferences.setMockInitialValues({'tts_enabled': true});
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dyn =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen))
            as dynamic;

    spoken.clear();
    dyn.onDartHitForTest(0); // A misses — must stay TTS-silent
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, isEmpty,
        reason: 'a miss must not produce any TTS utterance');

    dyn.onDartHitForTest(1); // A single after 1 miss -> 4 strokes = BOGEY
    await tester.pump(const Duration(milliseconds: 100));
    expect(spoken, contains('bogey!'),
        reason: 'hole result must speak the bare term, no Ace!/points');
    expect(spoken.any((s) => s == 'B, hole 1'), isTrue,
        reason: 'next-player handoff must carry the still-open hole target');

    spoken.clear();
    dyn.onDartHitForTest(1); // B single, no misses -> 3 strokes = PAR, wraps
    await tester.pump(const Duration(milliseconds: 100));
    expect(spoken, contains('par!'));
    expect(spoken.any((s) => s == 'A, hole 2'), isTrue,
        reason: 'once the round wraps, the target rides to the new hole');
  });
}
