import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/golf_engine.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Smoke test for the DOSSEDART Golf cockpit's core loop: tee off → a miss
/// (lying) → a made dart that ends the hole and advances to the next player.
///
/// Mirrors `shanghai_postgame_undo_test.dart`'s harness: platform channels
/// for flutter_tts/battery_plus are stubbed and pump()+Duration is used
/// instead of pumpAndSettle (which would hang on the unmocked audioplayers
/// channel). The dart-hit path is driven via the @visibleForTesting
/// onDartHitForTest() wrapper, same convention as the other cockpits.
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

  testWidgets('golf cockpit: tee off → lying → hole result', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    expect(find.text('HOLE 1 · PAR 3'), findsOneWidget);
    expect(find.textContaining('TEE OFF'), findsOneWidget);

    final state =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    final dyn = state as dynamic;
    dyn.onDartHitForTest(0); // miss
    await tester.pump();
    expect(find.textContaining('LYING 1'), findsOneWidget);
    dyn.onDartHitForTest(2); // double after 1 miss = 3 = PAR
    await tester.pump();
    final engine = dyn.engineForTest as GolfEngine;
    expect(engine.scorecards[0][0], 3);
    expect(engine.currentPlayerIndex, 1);
  });
}
