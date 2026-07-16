import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/one_up_engine.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget test: post-game Undo returns to OneUpGameScreen with gameOver=false
/// and the eliminated player's life restored (Shanghai/Gotcha parity, F17).
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

  testWidgets(
      'post-game Undo reopens a won 1UP game and restores the eliminated player',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 1),
      ),
    ));
    await tester.pump();
    final state = tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
    final engine = (state as dynamic).engineForTest as OneUpEngine;

    // A free-sets 100; B throws 3 misses -> fails -> eliminated -> A wins.
    engine.applyDart(20, 3); engine.applyDart(20, 2); engine.applyDart(0, 1); // 100
    engine.applyDart(0, 1); engine.applyDart(0, 1); engine.applyDart(0, 1);
    expect(engine.gameOver, isTrue);
    (state as dynamic).onGameEndForTest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A third pump call is required here (not just more elapsed time): each
    // `await tester.pump(...)` unwinds one microtask hop of the _onGameEnd
    // await-chain (VideoService -> PlayerStorage.loadPlayers -> Navigator.push),
    // regardless of the Duration passed. Verified empirically — a single
    // pump(seconds: 5) after the first pump() still finds 0 widgets, while a
    // third pump() call (any duration) reveals PostGameScreen.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PostGameScreen), findsOneWidget);

    await tester.tap(find.textContaining('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PostGameScreen), findsNothing);
    expect(engine.gameOver, isFalse);
    expect(engine.livesLeft[1], 1);
  });
}
