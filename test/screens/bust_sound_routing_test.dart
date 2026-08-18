import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/tts_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Bust cleanup (2026-08-18 sound spec): X01 busts pull from the GLOBAL
/// bust/ folder (the old x01/negative/out), Gotcha busts play the same
/// folder explicitly, and no path double-plays via announceGameEvent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');

  setUp(() {
    // SoundService.instance is deliberately NOT touched here: constructing
    // the singleton builds an AudioPlayer, and doing that before a widget
    // pump has driven the test binding leaves a stray platform-channel
    // error that surfaces on a LATER test (see x01_meme_gate_test.dart).
    VideoService.instance.setEnabled(false);
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
  }

  testWidgets('X01 bust plays the global bust folder, never x01/negative/out',
      (tester) async {
    // Pin meme frequency so the chance-gated bust roll always fires — same
    // "loud dice" key/value test/screens/x01_meme_gate_test.dart uses.
    SharedPreferences.setMockInitialValues({
      'meme_enabled': true,
      'meme_frequency': 10,
    });
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'A', score: 501), Player(name: 'B', score: 501)],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));
    SoundService.instance.playedForTest.clear();

    s.injectScoreForTest(0, 20);
    await s.onDartHitForTest(20, 3); // T20 over 20 remaining -> BUST
    await settle(tester);

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('x01/negative/out')));
    // Video is force-disabled above, so the screen's own gated bust call
    // always fires here. playRandom logs TWO entries per legitimate call —
    // the folder-join ('bust') and the resolved filename ('bust/<file>') —
    // so an exact match on the join string isolates just the "how many
    // times was a bust sound kicked off" count. The old bug had the
    // announcer ALSO calling play('bust') directly (a third, exact-match
    // 'bust' entry from a completely separate call site) — this must be
    // gone now that announceGameEvent lost its side effect.
    final exactBustCalls =
        SoundService.instance.playedForTest.where((f) => f == 'bust').length;
    expect(exactBustCalls, 1,
        reason: 'announcer + screen must not both fire a bust sound');
  });

  testWidgets('Gotcha bust plays the global bust folder exactly once',
      (tester) async {
    // Pin meme frequency so the explicit bust hook's chance roll (reusing
    // MemeService.frequencyChance) always fires.
    SharedPreferences.setMockInitialValues({'meme_frequency': 10});
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final dynamic s =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // Force player A right up to the edge of the target, then overshoot
    // with a T20 to bust — turn rotation/kill logic is irrelevant here, only
    // the bust sound path is under test.
    s.engineForTest.totals[0] = 290;
    SoundService.instance.playedForTest.clear();
    s.onDartHitForTest(20, 3); // 290 + 60 = 350 > 301 -> BUST
    await settle(tester);

    final bustHits = SoundService.instance.playedForTest
        .where((f) => f == 'bust')
        .length;
    expect(bustHits, 1);
  });
}
