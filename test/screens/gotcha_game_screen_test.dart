import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget tests for the Gotcha cockpit: renders, registers darts via the
/// @visibleForTesting hooks, and surfaces the KILL helper when an opponent
/// is exactly one dart away.
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/shanghai_postgame_undo_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return null;
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

  testWidgets('gotcha cockpit renders and registers darts', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('\u{1F480} GOTCHA \u{00B7} 301'), findsOneWidget);
    expect(find.text('TARGET 301'), findsOneWidget);

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));
    state.onDartHitForTest(20, 3);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.engineForTest.totals[0], 60);

    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.engineForTest.totals[0], 0);
  });

  testWidgets('kill helper appears when an opponent is one dart away',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // P0 (A) throws S20 x3 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);

    // P1 (B) throws S15 x3 -> 45. P0 is now throwing again but leads
    // (60 > 45), so no kill tip is shown for P0's turn.
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 45);

    // P0 (A) throws miss x3 -> turn passes to P1 without changing totals.
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));

    // Now P1 (B, 45) is throwing against P0 (A, 60): diff 15 -> single S15
    // kills A. The KILL helper should show the chip; the CHECKOUT helper
    // should be dim (301-45=256 is beyond a 3-dart straight-out route).
    expect(find.text('S15'), findsOneWidget);
    expect(find.text('→ A'), findsOneWidget);
    expect(find.text('NO ROUTE \u{00B7} > 3 DARTS'), findsOneWidget);
  });

  testWidgets(
      'removing the mid-turn current player advances the turn, and a '
      'roster-changed stats update completes without recording a game',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A throws one dart, leaving their turn open (dartsInTurn == 1).
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.currentPlayerIndex, 0);

    // Remove A while they are still the current, mid-turn thrower.
    state.removePlayerForTest(0);
    await tester.pump();

    expect(state.engineForTest.currentPlayerIndex, 1,
        reason: 'removing the mid-turn current player advances to the next '
            'seat');
    expect(state.midGamePlayerChangesForTest, isTrue);

    // Roster changed -> early return: join/leave counters only, no game
    // recorded. The bar here is simply that this completes without error.
    await state.updateStatsForTest();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mid-game add joins level with the last-placed player and clears the '
      'undo stack', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A: T20 (60), then two misses to close out the turn.
    state.onDartHitForTest(20, 3);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);
    expect(state.engineForTest.currentPlayerIndex, 1);

    // B: D20 (40), then two misses to close out the turn, back to A.
    state.onDartHitForTest(20, 2);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 40);
    expect(state.engineForTest.canUndo, isTrue);

    state.addPlayerForTest(
        SavedPlayer(id: 'x', name: 'C', createdAt: DateTime(2026, 1, 1)));
    await tester.pump();

    expect(state.engineForTest.totals.length, 3);
    expect(state.engineForTest.totals[2], 40,
        reason: 'joins level with the LAST-PLACED active player (B on 40), '
            'not the average of 60 and 40 — join-fairness 2026-08-10');
    expect(state.engineForTest.canUndo, isFalse,
        reason: 'roster changes clear the undo stack');
  });

  testWidgets('default config: a kill halves the victim, not resets to 0',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A (P0): S20, S20, miss -> total 40, turn passes to B.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 40);
    expect(state.engineForTest.currentPlayerIndex, 1);

    // B (P1): D20 -> 40 points, lands exactly on A's 40 -> kill A, halved.
    state.onDartHitForTest(20, 2);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.totals[0], 20,
        reason: 'default (non-hardcore) kill halves 40 -> 20, floor division');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hardcore config: a kill resets the victim to 0',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301, hardcore: true),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A (P0): S20, S20, miss -> total 40, turn passes to B.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 40);
    expect(state.engineForTest.currentPlayerIndex, 1);

    // B (P1): D20 -> 40 points, lands exactly on A's 40 -> kill A, reset to 0.
    state.onDartHitForTest(20, 2);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.totals[0], 0,
        reason: 'hardcore kill resets the victim to 0');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'game end with a kill on the log runs the achievement-event wiring '
      'without error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A (P0): S20, S20, miss -> total 40, turn passes to B.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));

    // B (P1): D20 -> kills A (halved 40 -> 20). killLog now has one entry.
    state.onDartHitForTest(20, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.killLog, isNotEmpty);

    // Drive the same roster-unchanged path _updateStats takes at game end:
    // gotchaEventsFromKillLog -> awardGameEnd -> buildEarnedFeats ->
    // StatsRecorder.recordGame. The pure derivation logic itself is covered
    // by test/utils/gotcha_achievement_feats_test.dart; this just confirms
    // the wiring doesn't throw.
    await state.updateStatsForTest();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
