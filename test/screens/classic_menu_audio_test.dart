import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F15 (audit 2026-07-06): X01's classic "Sound" toggle used to write BOTH
/// sound_effects_enabled and meme_enabled. Sound and memes are independent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');

  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'sound_effects_enabled': true, 'meme_enabled': true});
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

  Future<void> pumpX01(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501), Player(name: 'P1', score: 501)],
        startingScore: 501,
        masterOut: 'double',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('X01 sound toggle leaves meme setting untouched', (tester) async {
    await pumpX01(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound on'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_effects_enabled'), isFalse);
    expect(prefs.getBool('meme_enabled'), isTrue,
        reason: 'F15: the sound toggle must not silently disable memes');
  });

  testWidgets('X01 classic menu exposes the standard meme items', (tester) async {
    await pumpX01(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Memes on'), findsOneWidget);
    expect(find.text('Meme frequency'), findsOneWidget);
    expect(find.text('Offensive off'), findsOneWidget);
  });

  testWidgets('Cricket classic menu exposes an independent sound toggle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sound on'), findsOneWidget);

    await tester.tap(find.text('Sound on'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_effects_enabled'), isFalse);
    expect(prefs.getBool('meme_enabled'), isTrue,
        reason: 'F15: the sound toggle must not silently disable memes');
  });
}
