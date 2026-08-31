import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
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

  testWidgets(
      'Cricket: removed seat excluded from stats/Elo/history; remaining '
      'players still count', (tester) async {
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
      home: CricketGameScreen(
        players: [
          Player(name: 'A', score: 0, savedPlayerId: 'a'),
          Player(name: 'B', score: 0, savedPlayerId: 'b'),
          Player(name: 'C', score: 0, savedPlayerId: 'c'),
        ],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // Play a couple of darts, then remove seat 2 (C) mid-game.
    await s.registerHitForTest(20, 3);
    await s.registerHitForTest(19, 1);
    s.removePlayerForTest(2);
    await tester.pump();

    await s.updateStatsForTest();
    await tester.pump();

    final saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    final c = saved.firstWhere((p) => p.id == 'c');

    expect(a.gamesPlayed, 1, reason: 'active seat counts');
    expect(b.gamesPlayed, 1, reason: 'active seat counts');
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
