import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
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
      'X01: removed seat excluded from stats/Elo/history; remaining '
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
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501, savedPlayerId: 'a'),
          Player(name: 'B', score: 501, savedPlayerId: 'b'),
          Player(name: 'C', score: 501, savedPlayerId: 'c'),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    // Remove seat 2 (C) mid-game — it's still A's turn (seat 0).
    s.removePlayerForTest(2);
    await tester.pump();

    // A checks out; B then throws a full (missed) turn so the round
    // resolves — with C removed, B is the only other active seat, so the
    // game ends immediately once the round closes.
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2); // D20 checkout
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(1, 1);
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

    expect(a.gamesPlayed, 1, reason: 'winner counts');
    expect(a.gamesWon, 1);
    expect(b.gamesPlayed, 1, reason: 'runner-up still counts');
    expect(a.rating, isNot(1200.0), reason: 'winner rating moved');
    expect(b.rating, isNot(1200.0), reason: 'runner-up rating moved');

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
