import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/golf_engine.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// Widget test: post-game Undo returns to GolfGameScreen with gameOver=false
/// and the last hole reopened (1UP/Shanghai post-game-undo parity).
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/one_up_postgame_undo_test.dart.
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

  testWidgets('post-game Undo reopens a finished golf game', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    final state = tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    final dyn = state as dynamic;
    final engine = dyn.engineForTest as GolfEngine;

    for (var h = 0; h < 9; h++) { engine.applyDart(3); engine.applyDart(1); }
    expect(engine.gameOver, isTrue);
    dyn.onGameEndForTest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PostGameScreen), findsOneWidget);

    await tester.tap(find.textContaining('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PostGameScreen), findsNothing);
    expect(engine.gameOver, isFalse);
    expect(engine.scorecards[1][8], isNull); // B's last hole reopened
  });

  testWidgets('golf: removed mid-game player does not become winner',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    final state = tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    final dyn = state as dynamic;
    final engine = dyn.engineForTest as GolfEngine;

    // A aces hole 1 (best possible card) then is removed mid-game.
    dyn.onDartHitForTest(3); // A: triple on the first dart -> ace
    dyn.removePlayerForTest(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // B pars every hole (S on the first dart -> 3 strokes); C bogeys every
    // hole (a miss then a single -> 4 strokes) so B ends up the clear
    // winner without either total/vs-par reaching the double/triple-digit
    // widths that overflow the opponent tile (a separate, pre-existing
    // DossedartGolfActiveCard layout issue, out of scope here).
    for (var h = 0; h < 9; h++) {
      dyn.onDartHitForTest(1); // B: single -> par
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      dyn.onDartHitForTest(0); // C: miss
      dyn.onDartHitForTest(1); // C: single after the miss -> bogey
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    expect(engine.gameOver, isTrue);
    expect(engine.winnerIndex, 1); // B (27), not the removed A or C (36)
    expect(dyn.removedPlayerIndicesForTest, {0});
  });

  testWidgets('golf: removed player is excluded from the result screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pump();
    final state = tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    final dyn = state as dynamic;

    // Remove all but one player -> the survivor wins immediately.
    dyn.removePlayerForTest(0);
    dyn.removePlayerForTest(2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(PostGameScreen), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('C'), findsNothing);
    expect(find.text('B'), findsWidgets);

    // Critical requirement (Task 9 review): every roster-change path must
    // set the gating flag FIRST, unconditionally -- including the
    // removePlayerForTest seam driven above -- so _updateStats takes the
    // recordMidGameChanges branch instead of the full recordGame/Elo path
    // (which would misread the skipped seats' placement 0 as "winner").
    expect(dyn.midGamePlayerChangesForTest, isTrue);

    // "Finish Game" pops 'home', which drives _updateStats(placements) --
    // confirm it completes via the mid-game-changes short-circuit without
    // throwing (same bar as the Gotcha/Wildcard equivalents).
    await tester.tap(find.text('Finish Game'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(PostGameScreen), findsNothing);
  });
}
