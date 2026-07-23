import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F10 (audit 2026-07-06): Shanghai used to record a full game (and a history
/// entry with placement 0 for the removed player) even after a mid-game roster
/// change. It must instead record only join/leave counters — no game entry —
/// like every other mode.
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

  testWidgets('mid-game removal writes no game-history entry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
          Player(name: 'P3', score: 0),
        ],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic s =
        tester.state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));

    // Play a couple of darts, then remove a player mid-game.
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.miss);
    s.removePlayerForTest(2);
    await tester.pump();

    // Finish + persist via the leave path.
    await s.updateStatsForTest();
    await tester.pump();

    final history = await GameHistoryService.load();
    expect(history, isEmpty,
        reason: 'a roster-changed Shanghai game must not be written to '
            'history (no placement-0 phantom entry)');
  });

  testWidgets('turn-hit slots stay in sync after an undo across a turn',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic s =
        tester.state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
    final engine = s.engineForTest;

    // Complete P1's full turn (3 darts) → turn ends, _turnHits cleared.
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    await tester.pump();
    expect(engine.currentPlayerIndex, 1, reason: 'turn advanced to P2');
    expect(s.turnHitsForTest, isEmpty);

    // Undo across the turn boundary — the slots must reflect P1's turn again
    // (2 darts remaining after popping the 3rd), not a stale/empty list.
    s.onUndoForTest();
    await tester.pump();
    expect(engine.currentPlayerIndex, 0,
        reason: 'undo returned to P1 mid-turn');
    expect(s.turnHitsForTest.length, engine.dartNumber,
        reason: 'dart slots must match the engine dart count after undo (F13)');
  });

  testWidgets(
      'last active player\'s round-closing 3rd dart stays tagged with the '
      'round it was thrown in, not the round the engine just advanced to',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic s =
        tester.state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
    final engine = s.engineForTest;

    // P1's full turn in round 0 (all singles — avoids the S+D+T instant
    // Shanghai trigger, which would end the game early).
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    await tester.pump();
    expect(engine.currentPlayerIndex, 1, reason: 'turn advanced to P2');
    expect(engine.currentRound, 0, reason: 'still round 0 — 2 players in');

    // P2 — the last active player this round — throws their turn. The 3rd
    // dart is the one that flips currentPlayerIndex back to 0 AND bumps
    // engine.currentRound to 1 inside recordThrow.
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    await tester.pump();
    expect(engine.currentPlayerIndex, 0, reason: 'wrapped to P1');
    expect(engine.currentRound, 1,
        reason: 'engine advanced to round 1 on P2\'s 3rd dart');

    // But all 3 of P2's darts were thrown DURING round 0 — the capture-
    // before-apply fix must have tagged every one of them with roundNumber 0,
    // not just the first two.
    final List<DartThrow> allThrows =
        List<DartThrow>.from(s.throwHistoryForTest as List);
    final p2Throws = allThrows.where((t) => t.playerIndex == 1).toList();
    expect(p2Throws.length, 3);
    expect(p2Throws.map((t) => t.roundNumber).toSet(), {0},
        reason: "P2's round-closing 3rd dart must not bleed into round 1's "
            'bucket');

    // …and so bestRound correctly sums all 3 darts of that single round,
    // rather than undercounting because the 3rd dart landed in a phantom
    // round-1 bucket of its own.
    final expectedPoints =
        p2Throws.fold<int>(0, (acc, t) => acc + t.points);
    expect(s.bestRoundForTest(1), expectedPoints);
    expect(s.bestRoundForTest(1), 3,
        reason: '3 singles at round-0 target (1) = 1pt each = 3 total');
  });
}
