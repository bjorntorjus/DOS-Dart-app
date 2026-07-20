import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Undo must announce 'Back' (tablet-QA 2026-07-17): the classic modes
/// (X01/Cricket/ATC/Splitscore/Killer) all speak 'Back' via
/// announceGameEvent in their undo handlers so users hear that the tap
/// registered — the DOSSEDART cockpits (Shanghai/Gotcha/Wildcard/1UP)
/// were silent. Same TTS harness as test/screens/shanghai_announcer_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    SharedPreferences.setMockInitialValues({'tts_enabled': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') {
        spoken.add(call.arguments as String);
        // TtsService's queue only advances once flutter_tts reports
        // speak.onComplete; simulate it so every queued announcement
        // (not just the first) reaches this mock.
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

  testWidgets('1UP: undo announces Back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
    state.onDartHitForTest(5, 1);
    await tester.pump(const Duration(milliseconds: 50));

    spoken.clear();
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('Back'),
        reason: '1UP undo must speak Back like the classic modes');
  });

  testWidgets('Shanghai: undo announces Back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
    state.onHitForTest(HitType.single);
    await tester.pump(const Duration(milliseconds: 50));

    spoken.clear();
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('Back'),
        reason: 'Shanghai undo must speak Back like the classic modes');
  });

  testWidgets('Gotcha: undo announces Back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));
    state.onDartHitForTest(5, 1);
    await tester.pump(const Duration(milliseconds: 50));

    spoken.clear();
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('Back'),
        reason: 'Gotcha undo must speak Back like the classic modes');
  });

  testWidgets('Wildcard: undo announces Back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        // startingChaos: 0 keeps the RNG modifier roll from firing so no
        // overlay/announcement interferes (same pinning as the other
        // wildcard widget tests).
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));
    state.onDartHitForTest(5, 1);
    await tester.pump(const Duration(milliseconds: 50));

    spoken.clear();
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('Back'),
        reason: 'Wildcard undo must speak Back like the classic modes');
  });

  testWidgets('Golf: undo announces Back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    state.onDartHitForTest(1);
    await tester.pump(const Duration(milliseconds: 50));

    spoken.clear();
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('Back'),
        reason: 'Golf undo must speak Back like the classic modes');
  });
}
