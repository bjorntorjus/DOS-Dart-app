import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget tests for the Gotcha post-game flow: winner ranking, PostGameScreen
/// navigation, and the deferred-stats Undo protocol (Shanghai parity, F17).
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/shanghai_postgame_undo_test.dart. The
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

  testWidgets(
      'post-game Undo reopens a won gotcha game and restores kill victims',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 101),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A: S20, S20, S20 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);

    // B: S20, S20, S1 -> 41.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(1, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 41);

    // A: S20 -> 80; S20 -> 100; S1 -> 101 EXACT -> game over, A wins.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 80);
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 100);
    state.onDartHitForTest(1, 1);

    // Let the winner flow (video + TTS + rating preview + PostGameScreen
    // push) settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(state.engineForTest.gameOver, isTrue);
    expect(state.engineForTest.totals[0], 101);
    expect(find.text('↶ BACK'), findsOneWidget,
        reason: 'PostGameScreen with Undo button should be on top');

    await tester.tap(find.text('↶ BACK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.engineForTest.gameOver, isFalse);
    expect(state.engineForTest.totals[0], 100,
        reason: 'winning dart should be undone');
    expect(find.text('\u{1F480} GOTCHA \u{00B7} 101'), findsOneWidget,
        reason: 'should be back on the cockpit');
  });

  testWidgets('removed mid-game player never wins', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

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

    // Remove the leader (A) and the last remaining opponent's rival (C),
    // leaving only B — the survivor must win even though A had the lead.
    state.removePlayerForTest(0);
    await tester.pump(const Duration(milliseconds: 50));
    state.removePlayerForTest(2);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.gameOver, isTrue);
    expect(state.engineForTest.winnerIndex, 1);
  });
}
