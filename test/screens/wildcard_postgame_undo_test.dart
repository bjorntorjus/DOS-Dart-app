import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';
import 'package:dart_scoring/widgets/dossedart/progression_chart.dart';

/// Widget tests for the WILDCARD post-game flow: winner celebration,
/// PostGameScreen navigation, the deferred-stats Undo protocol (Shanghai/
/// Gotcha parity, F17), and the NO-Elo contract (spec §9).
///
/// Every scenario pins `startingChaos: 0` so the turn-modifier roll
/// (`wcModifierChancePct(0) == 0`) never fires and no jokers are assigned
/// (`wcJokerCount(0) == 0`) — darts score exactly `segment * multiplier`
/// with no overlay interruptions, keeping the drive-to-game-over sequence
/// fully deterministic.
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/gotcha_postgame_undo_test.dart. The
/// winner flow calls VideoService.showRandomFromFolder, which is a no-op
/// because VideoService.disableForTest is set globally by
/// test/flutter_test_config.dart — no extra stubbing needed.
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

  /// Drives A to 60 (S20 x3) and B to 41 (S20, S20, S1) in a 1-round,
  /// chaos-0 game — B's 3rd dart ends the only round, which ends the game
  /// with A as the winner. The winner overlay is gone (QA round 3): gameOver
  /// runs the celebration then navigates straight to PostGameScreen, so by
  /// the time this returns, PostGameScreen is already on top with no
  /// overlay tap required. Returns the screen's State so callers can drive
  /// PostGameScreen's navigation from there.
  Future<dynamic> playToGameOver(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(rounds: 1, startingChaos: 0),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // A: S20, S20, S20 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);

    // B: S20, S20, S1 -> 41. The 3rd dart ends round 1/1 -> game over.
    // `totals` only updates when a turn BANKS (at the 3rd dart) — the first
    // two darts live in `turnPoints` until then.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.turnPoints, 40);
    state.onDartHitForTest(1, 1);

    // Let the winner flow (video + TTS celebration) settle, then the
    // Navigator.push to PostGameScreen land.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.engineForTest.gameOver, isTrue);
    expect(state.engineForTest.winnerIndex, 0);
    expect(state.overlayKindForTest, isNull,
        reason: 'no winner overlay any more — straight to PostGameScreen');
    expect(find.text('↶ BACK'), findsOneWidget,
        reason: 'PostGameScreen with Undo button should already be on top');

    return state;
  }

  testWidgets('post-game Undo reopens a finished wildcard game',
      (tester) async {
    final state = await playToGameOver(tester);

    await tester.tap(find.text('↶ BACK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.engineForTest.gameOver, isFalse);
    expect(state.engineForTest.totals[1], 0,
        reason: "B's winning turn should be un-banked, not just un-scored");
    expect(state.engineForTest.turnPoints, 40,
        reason: "B's first two darts (S20, S20) survive the undo");
    expect(find.text('\u{1F0CF} WILDCARD'), findsOneWidget,
        reason: 'should be back on the cockpit');
  });

  testWidgets('no Elo recorded for a finished wildcard game', (tester) async {
    await playToGameOver(tester);

    expect(find.text('↶ BACK'), findsOneWidget);

    // WILDCARD never touches EloService (spec §9) — PlayerResult always
    // carries ratingBefore/After: null, so PostGameScreen's rating-delta
    // row (an arrow icon + "+x.x"/"±0" text) is never built at all.
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.textContaining('±0'), findsNothing);

    await tester.tap(find.text('✓ FINISH GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // The test harness's MaterialApp has no route below the game screen, so
    // popUntil(isFirst) lands back on it — assert the PostGameScreen is
    // gone rather than that the game screen itself was removed.
    expect(find.text('✓ FINISH GAME'), findsNothing,
        reason: 'PostGameScreen should be popped after Finish Game');
  });

  testWidgets('removed players never win', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const WildcardConfig(rounds: 10, startingChaos: 0),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // A takes a commanding lead: S20, S20, S20 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);

    // B misses out its turn.
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));

    // C misses out its turn.
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));

    // Remove the leader (A) and one of the trailers (C), leaving only B —
    // the survivor must win even though A had the lead.
    state.removePlayerForTest(0);
    await tester.pump(const Duration(milliseconds: 50));
    state.removePlayerForTest(2);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.gameOver, isTrue);
    expect(state.engineForTest.winnerIndex, 1);

    // Let the winner flow settle and PostGameScreen appear.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));

    // When roster changes mid-game, the progression chart is suppressed
    // (throwHistory still uses original seat indices, which misaligns with
    // the final roster).
    expect(find.byType(ProgressionChart), findsNothing,
        reason: 'chart should be suppressed when roster changed');
  });
}
