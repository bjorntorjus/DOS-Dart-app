import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Spec 2026-08-26: a mid-game roster change no longer skips stats/history
/// entirely. Removed players are excluded (seats skipped, not dropped);
/// everyone else — including joiners — counts as normal. Killer is unrated,
/// so this asserts modeStats/gamesPlayed rather than Elo.
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
      'Killer: removed seat excluded from stats/history; remaining '
      'players still count; a kill made BEFORE the removal still lands in '
      "the survivor's persisted counters (fix-round-1 #1 — a roster change "
      'clears _undoStack, so the pre-removal kill must be carried forward)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'c', name: 'C', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'd', name: 'D', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(
        players: [
          Player(name: 'A', score: 0, savedPlayerId: 'a'),
          Player(name: 'B', score: 0, savedPlayerId: 'b'),
          Player(name: 'C', score: 0, savedPlayerId: 'c'),
          Player(name: 'D', score: 0, savedPlayerId: 'd'),
        ],
        config: const KillerConfig(throwToPick: false, lives: 3),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));

    // A is a killer and lands a kill on B — BEFORE any roster change, so
    // this event lives only in _undoStack at this point.
    s.isKiller[0] = true;
    s.lives[1] = 1;
    final int bNumber = s.assignedNumbers[1];
    await s.onDartHitForTest(bNumber, 1); // kill #1 (pre-removal)
    await tester.pump();

    // Remove seat 2 (C) mid-game — this clears _undoStack. Without the
    // fix, kill #1 above would be lost from A's eventual persisted stats.
    s.removePlayerForTest(2);
    await tester.pump();

    // A lands a second kill on D, post-clear — this one is the last alive,
    // so A wins.
    s.lives[3] = 1;
    final int dNumber = s.assignedNumbers[3];
    await s.onDartHitForTest(dNumber, 1); // kill #2 (post-removal)
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    await tester.tap(find.text('✓ FINISH GAME'));
    await settle(tester);
    await settle(tester);

    final saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    final c = saved.firstWhere((p) => p.id == 'c');
    final d = saved.firstWhere((p) => p.id == 'd');

    expect(a.gamesPlayed, 1, reason: 'winner counts');
    expect(a.gamesWon, 1);
    expect(b.gamesPlayed, 1, reason: 'eliminated-but-not-removed still counts');
    expect(d.gamesPlayed, 1, reason: 'eliminated-but-not-removed still counts');
    expect(a.modeStats['killer']?.played, 1);

    // The carry-forward assertion: both kills — the one before the roster
    // change and the one after — must be present in A's persisted counters.
    expect(a.modeStats['killer']?.get('kills'), 2,
        reason: 'the pre-removal kill (recorded in _undoStack, then '
            'cleared by the roster change) must be carried forward into '
            "A's persisted kill count, not lost");

    expect(c.gamesPlayed, 0, reason: 'removed seat excluded entirely');
    expect(c.modeStats.containsKey('killer'), isFalse,
        reason: 'removed seat gets no mode stats from this game');

    final history = await GameHistoryService.load();
    expect(history.length, 1, reason: 'one game-history entry is written');
    final entry = history.first;
    expect(entry.players[2].removed, isTrue,
        reason: 'removed seat flagged on the history entry');
    expect(entry.activePlayers.length, 3,
        reason: 'only the three active seats count toward the entry');

    // Placements the removed seat left a hole in are closed up before they
    // are persisted (spec 2026-08-26 / denseRankActive): the active field
    // reads 1, 2, 3, … with no gap where the removed seat's rank used to be.
    final activePlacements =
        entry.activePlayers.map((p) => p.placement).toList()..sort();
    expect(activePlacements.first, 1,
        reason: 'the active field starts at rank 1');
    for (var i = 1; i < activePlacements.length; i++) {
      expect(activePlacements[i] - activePlacements[i - 1], lessThanOrEqualTo(1),
          reason: 'active placements are contiguous (ties may repeat): '
              '$activePlacements');
    }
    expect(entry.players[0].placement, 1,
        reason: "the winner's own row carries placement 1");
  });
}
