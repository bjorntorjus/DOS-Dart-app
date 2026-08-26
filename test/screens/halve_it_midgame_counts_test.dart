import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Spec 2026-08-26: a mid-game roster change no longer skips stats/Elo/
/// history entirely. Removed players are excluded (seats skipped, not
/// dropped); everyone else — including joiners — counts as normal.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'Splitscore: removed seat excluded from stats/Elo/history; '
      'remaining players still count', (tester) async {
    // Tablet-sized surface — the classic Splitscore scaffold overflows the
    // 800×600 test default.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'c', name: 'C', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(
        players: [
          Player(name: 'A', score: 0, savedPlayerId: 'a'),
          Player(name: 'B', score: 0, savedPlayerId: 'b'),
          Player(name: 'C', score: 0, savedPlayerId: 'c'),
        ],
        // Two plain number rounds (no double/triple/bull) so the game
        // finishes in minimal darts; targets are random but read at runtime.
        config: const HalveItConfig(
          isRandom: true,
          roundCount: 2,
          includeDouble: false,
          includeTriple: false,
          includeBull: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s =
        tester.state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));

    // Remove seat 2 (C) mid-game — it's still A's turn (seat 0).
    s.removePlayerForTest(2);
    await tester.pump();

    // Both remaining rounds: A hits the round's target with all three
    // darts; B misses every dart (halved both rounds), so the two seats end
    // with different placements and a real rating delta on both sides. C is
    // skipped in rotation (removed).
    for (var round = 0; round < 2; round++) {
      final target = s.rounds[round].targetNumber as int;
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(target, 1); // A
      }
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(0, 0); // B misses
      }
    }
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    await tester.tap(find.text('✓ FINISH GAME'));
    await settle(tester);
    await settle(tester);

    final saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    final c = saved.firstWhere((p) => p.id == 'c');

    expect(a.gamesPlayed, 1, reason: 'A still counts');
    expect(b.gamesPlayed, 1, reason: 'B still counts');
    expect(a.rating, isNot(1200.0), reason: 'A rating moved');
    expect(b.rating, isNot(1200.0), reason: 'B rating moved');

    expect(c.gamesPlayed, 0, reason: 'removed seat excluded entirely');
    expect(c.rating, 1200.0, reason: 'removed seat rating untouched');

    final history = await GameHistoryService.load();
    expect(history.length, 1, reason: 'one game-history entry is written');
    final entry = history.first;
    expect(entry.players[2].removed, isTrue,
        reason: 'removed seat flagged on the history entry');
    expect(entry.activePlayers.length, 2,
        reason: 'only the two active seats count toward the entry');
  });
}
