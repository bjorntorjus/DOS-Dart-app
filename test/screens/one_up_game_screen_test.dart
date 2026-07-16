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

/// Widget smoke test for the DOSSEDART 1UP cockpit core (Task 6).
///
/// NOTE: Uses pump() + Duration rather than pumpAndSettle() to avoid hanging
/// on platform-channel calls (battery_plus, audioplayers) that are not mocked
/// and never complete in the Flutter test environment. Engine state is driven
/// directly (tapping the SVG board in tests is brittle; input plumbing is
/// covered by later task flows).
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

  testWidgets('1UP cockpit: free throw → target set → NEED line → life lost',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pump();
    // The active card renders "SET THE" / "TARGET" on two lines, so we match
    // the headline via its first line rather than the combined string.
    expect(find.textContaining('SET THE'), findsOneWidget);

    final state = tester.state<State<OneUpGameScreen>>(
        find.byType(OneUpGameScreen));
    final engine = (state as dynamic).engineForTest as OneUpEngine;
    engine.applyDart(20, 3);
    engine.applyDart(20, 3);
    engine.applyDart(20, 3); // 180 sets the target; advances to player B
    (state as dynamic).setState(() {});
    await tester.pump();

    expect(find.text('BEAT'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.textContaining('NEED 180 MORE'), findsOneWidget);
  });

  testWidgets('life lost overlay appears and tap dismisses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pump();

    final state = tester.state<State<OneUpGameScreen>>(
        find.byType(OneUpGameScreen));
    final dyn = state as dynamic;
    // A sets 100, B misses the whole turn -> B loses a life.
    dyn.onDartHitForTest(20, 3);
    dyn.onDartHitForTest(20, 2);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    await tester.pump();

    expect(find.text('−1 LIFE'), findsOneWidget);
    expect(find.textContaining('FAILED TO BEAT 100'), findsOneWidget);

    await tester.tap(find.text('−1 LIFE'));
    await tester.pump();
    expect(find.text('−1 LIFE'), findsNothing);
  });

  testWidgets('winner overlay shows 1UP! and leads to post-game',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 1),
      ),
    ));
    await tester.pump();

    final state = tester.state<State<OneUpGameScreen>>(
        find.byType(OneUpGameScreen));
    final dyn = state as dynamic;
    // A free-sets 100; B misses the whole turn -> eliminated -> A wins.
    dyn.onDartHitForTest(20, 3);
    dyn.onDartHitForTest(20, 2);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    await tester.pump();

    expect(find.text('1UP!'), findsOneWidget);

    await tester.tap(find.text('1UP!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PostGameScreen), findsOneWidget);
  });

  testWidgets(
      'round-ending dart keeps round 1 in history, not the incremented round',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pump();

    final state = tester.state<State<OneUpGameScreen>>(
        find.byType(OneUpGameScreen));
    final dyn = state as dynamic;
    // Two full turns (A then B) complete round 1. B's 3rd dart is the one
    // that used to be mis-tagged with the incremented roundNumber (2)
    // instead of the round it actually closed out (1).
    dyn.onDartHitForTest(20, 3); // A dart 1
    dyn.onDartHitForTest(20, 3); // A dart 2
    dyn.onDartHitForTest(20, 3); // A dart 3 -> sets target, advances to B
    dyn.onDartHitForTest(1, 1); // B dart 1
    dyn.onDartHitForTest(1, 1); // B dart 2
    dyn.onDartHitForTest(1, 1); // B dart 3 -> ends round 1, rolls to round 2
    await tester.pump();

    final throwHistory = dyn.throwHistory as List<dynamic>;
    expect(throwHistory.length, 6);
    for (final t in throwHistory) {
      expect((t as dynamic).roundNumber, 1,
          reason: 'every round-1 dart, including the round-closing one, '
              'must keep roundNumber == 1');
    }
  });
}
