import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget tests for the Gotcha cockpit: renders, registers darts via the
/// @visibleForTesting hooks, and surfaces the KILL helper when an opponent
/// is exactly one dart away.
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

  testWidgets('gotcha cockpit renders and registers darts', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('\u{1F480} GOTCHA \u{00B7} 301'), findsOneWidget);
    expect(find.text('TARGET 301'), findsOneWidget);

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));
    state.onDartHitForTest(20, 3);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.engineForTest.totals[0], 60);

    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.engineForTest.totals[0], 0);
  });

  testWidgets('kill helper appears when an opponent is one dart away',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // P0 (A) throws S20 x3 -> 60.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[0], 60);

    // P1 (B) throws S15 x3 -> 45. P0 is now throwing again but leads
    // (60 > 45), so no kill tip is shown for P0's turn.
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(15, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 45);

    // P0 (A) throws miss x3 -> turn passes to P1 without changing totals.
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(0, 0);
    await tester.pump(const Duration(milliseconds: 50));

    // Now P1 (B, 45) is throwing against P0 (A, 60): diff 15 -> single S15
    // kills A. The KILL helper should show the chip; the CHECKOUT helper
    // should be dim (301-45=256 is beyond a 3-dart straight-out route).
    expect(find.text('S15'), findsOneWidget);
    expect(find.text('→ A'), findsOneWidget);
    expect(find.text('NO ROUTE \u{00B7} > 3 DARTS'), findsOneWidget);
  });
}
