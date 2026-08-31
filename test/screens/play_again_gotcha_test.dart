import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_gotcha_setup_screen.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// PLAY AGAIN (task 11, continue-dialog-play-again): Gotcha is DOSSEDART-only
/// — the result screen's rematch button must record stats exactly once (same
/// protocol as the home/leave path) and then land on
/// [DossedartGotchaSetupScreen] prefilled with the previous rules and roster
/// — never fall through to the home path silently.
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle(), same
/// harness as test/screens/gotcha_postgame_undo_test.dart — avoids hanging on
/// unmocked platform channels (battery_plus, audioplayers).
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'Gotcha: PLAY AGAIN records exactly once and reopens the DOSSEDART '
      'setup screen with the same players preselected', (tester) async {
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [
          Player(name: 'A', score: 0, savedPlayerId: 'a'),
          Player(name: 'B', score: 0, savedPlayerId: 'b'),
        ],
        config: const GotchaConfig(targetScore: 101),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // A: S20, S20, S20 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    // B: S20, S20, S1 -> 41.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(1, 1);
    await tester.pump(const Duration(milliseconds: 50));

    // A: S20 -> 80; S20 -> 100; S1 -> 101 EXACT -> game over, A wins.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(1, 1);

    // Let the winner flow (video + TTS + rating preview + PostGameScreen
    // push) settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(state.engineForTest.gameOver, isTrue);

    await tester.tap(find.text('↻ PLAY AGAIN'));
    await settle(tester);
    await settle(tester);

    expect(find.byType(DossedartGotchaSetupScreen), findsOneWidget);
    final saved = await PlayerStorage.loadPlayers();
    // Gotcha (DOSSEDART-only) only ever writes the per-mode counter, never
    // the legacy top-level SavedPlayer.gamesPlayed field — same as its own
    // home/leave path (StatsRecorder.recordGame's `mode.played++`).
    expect(saved.firstWhere((p) => p.id == 'a').modeStats['gotcha']?.played, 1,
        reason: 'again records exactly once');
  });
}
