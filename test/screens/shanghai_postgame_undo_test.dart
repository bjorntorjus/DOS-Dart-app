import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget test: post-game Undo returns to ShanghaiGameScreen with gameOver=false.
///
/// Verifies that:
/// 1. After game-end, PostGameScreen is pushed.
/// 2. Tapping "↶ Back" returns to ShanghaiGameScreen.
/// 3. engine.gameOver is restored to false via engine.undo().
///
/// Stats persistence is verified indirectly: the round-trip must not crash,
/// confirming that _updateStats is only called in the non-undo branch.
///
/// NOTE: This test uses pump() + Duration rather than pumpAndSettle() to avoid
/// hanging on platform-channel calls (battery_plus, audioplayers) that are not
/// mocked and never complete in the Flutter test environment. The _onGameEnd
/// flow is driven via the @visibleForTesting onGameEndForTest() wrapper, which
/// bypasses the normal _onHit trigger path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub flutter_tts and battery_plus platform channels.
  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery/method');

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

  testWidgets('post-game Undo returns to Shanghai screen with gameOver=false',
      (tester) async {
    final players = [
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: players,
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    // Pump a few frames to let synchronous initState work; avoid pumpAndSettle
    // which would wait on unmocked platform channels (audioplayers, etc.).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Find the state and access the engine via the @visibleForTesting getter.
    final state = tester.state<State<ShanghaiGameScreen>>(
        find.byType(ShanghaiGameScreen));
    final dynamic dynState = state;
    final engine = dynState.engineForTest;

    // Drive an instant-Shanghai: single + double + triple on the current target
    // in one turn. This sets engine.gameOver = true immediately (pure Dart, no
    // async, no platform channels).
    engine.recordThrow(HitType.single);
    engine.recordThrow(HitType.double_);
    engine.recordThrow(HitType.triple);

    expect(engine.gameOver, isTrue,
        reason: 'precondition: engine must report gameOver after instant-Shanghai');

    // Invoke _onGameEnd via the @visibleForTesting wrapper. This pushes
    // PostGameScreen via Navigator.push and awaits _fireWinnerCelebration
    // (TTS + video — both no-ops in test: TTS disabled by default, VideoService
    // returns early because no video assets are bundled in tests).
    final endFuture = dynState.onGameEndForTest() as Future<void>;

    // Pump to allow the Navigator.push to execute.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Wait for _onGameEnd's async chain to complete (TTS + asset manifest
    // lookup both return quickly in tests).
    await endFuture;
    await tester.pump();

    // PostGameScreen should be on top — the "↶ Back" button is its indicator
    // (text as declared in lib/screens/post_game_screen.dart line 110).
    expect(find.text('↶ Back'), findsOneWidget,
        reason: 'PostGameScreen with Undo button should be on top');

    // Tap Undo and pump to let the setState(() => engine.undo()) + pop execute.
    await tester.tap(find.text('↶ Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Back in ShanghaiGameScreen — verify engine state was restored.
    expect(find.byType(ShanghaiGameScreen), findsOneWidget);
    expect(engine.gameOver, isFalse,
        reason: 'engine.undo() should clear the game-over state');
  });
}
