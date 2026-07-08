import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget tests for the WILDCARD cockpit: renders, registers darts via the
/// @visibleForTesting hooks, and drives the overlay state machine (bull
/// choice, forced-modifier announcement + dimming, input guard while an
/// overlay is up).
///
/// Most scenarios pin `startingChaos: 0` so the RNG-driven turn-modifier
/// roll (`wcModifierChancePct`) never fires spontaneously — the only
/// modifier that appears is the one explicitly forced via
/// `debugForceModifier`, keeping these tests deterministic.
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/gotcha_game_screen_test.dart.
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

  testWidgets('wildcard cockpit renders and banks a turn', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('\u{1F0CF} WILDCARD'), findsOneWidget);
    expect(find.text('ROUND 1/10'), findsOneWidget);
    expect(find.text('CHAOS'), findsOneWidget);

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.totals[0], 60);
    expect(state.engineForTest.currentPlayerIndex, 1);
  });

  testWidgets('bull hit opens the choice overlay; resolving moves the meter '
      'and a single undo reverts dart and meter together', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // D-Bull -> needs a +/-3 choice.
    state.onDartHitForTest(25, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.bull);

    state.resolveBullForTest(3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.chaos, 3);
    expect(state.overlayKindForTest, isNull);

    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.chaos, 0);
    expect(state.engineForTest.totals[0], 0);
  });

  testWidgets(
      'a forced modifier announces on the next turn, dims its restricted '
      'segments once dismissed, and a dimmed dart scores nothing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // Force the SECOND player's turn modifier (the very first turn's roll
    // already happened in the engine's constructor, at chaos 0 -> none).
    state.engineForTest.debugForceModifier('onlyEvens');

    // Bank player A's turn to roll (and consume) the forced modifier for B.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.overlayKindForTest, WcOverlayKind.announce);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, isNull);
    expect(state.engineForTest.dimPredicate, isNotNull);
    expect(state.engineForTest.dimPredicate!(7), isTrue);

    // A dimmed single-7 scores nothing.
    state.onDartHitForTest(7, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 0);
  });

  testWidgets('board input is a no-op while an overlay is showing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    state.engineForTest.debugForceModifier('onlyEvens');
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.overlayKindForTest, WcOverlayKind.announce);

    // Dart input while the announce overlay is up must be a no-op.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 0);
    expect(state.engineForTest.dartsInTurn, 0);
    expect(state.overlayKindForTest, WcOverlayKind.announce);
  });
}
