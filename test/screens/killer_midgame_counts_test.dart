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
      home: KillerGameScreen(
        players: [
          Player(name: 'A', score: 0, savedPlayerId: 'a'),
          Player(name: 'B', score: 0, savedPlayerId: 'b'),
          Player(name: 'C', score: 0, savedPlayerId: 'c'),
        ],
        config: const KillerConfig(throwToPick: false, lives: 3),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));

    // Remove seat 2 (C) mid-game.
    s.removePlayerForTest(2);
    await tester.pump();

    // Arrange A as a killer with B one hit from elimination, then land the
    // killing blow — A is now the last one standing (C already removed).
    s.isKiller[0] = true;
    s.lives[1] = 1;
    final int bNumber = s.assignedNumbers[1];
    await s.onDartHitForTest(bNumber, 1);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    await tester.tap(find.text('✓ FINISH GAME'));
    await settle(tester);
    await settle(tester);

    final saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    final c = saved.firstWhere((p) => p.id == 'c');

    expect(a.gamesPlayed, 1, reason: 'winner counts');
    expect(a.gamesWon, 1);
    expect(b.gamesPlayed, 1, reason: 'runner-up still counts');
    expect(a.modeStats['killer']?.played, 1);
    expect(b.modeStats['killer']?.played, 1);

    expect(c.gamesPlayed, 0, reason: 'removed seat excluded entirely');
    expect(c.modeStats.containsKey('killer'), isFalse,
        reason: 'removed seat gets no mode stats from this game');

    final history = await GameHistoryService.load();
    expect(history.length, 1, reason: 'one game-history entry is written');
    final entry = history.first;
    expect(entry.players[2].removed, isTrue,
        reason: 'removed seat flagged on the history entry');
    expect(entry.activePlayers.length, 2,
        reason: 'only the two active seats count toward the entry');
  });
}
