import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Regression test for the defer-until-leave recording protocol (audit
/// 2026-07-06, F2/F3): stats/Elo/history must be persisted exactly once, when
/// the user LEAVES the result screen — never before. "↶ BACK" (undo) must
/// leave no trace, so re-finishing after an undo cannot double-record.
///
/// One single test on purpose: it ends by leaving the game cleanly. Ending a
/// test with the game/result screen still alive leaks running services into
/// the next test and hangs its first pump.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Winner videos would push a modal overlay that never settles in tests.
    VideoService.instance.setEnabled(false);
  });

  testWidgets(
      'X01: nothing recorded while result screen is open; '
      'Back leaves no trace; leaving records exactly once', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501, savedPlayerId: 'a'),
          Player(name: 'B', score: 501, savedPlayerId: 'b'),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    // Bounded pumps throughout: the live game screen can keep animating, so
    // pumpAndSettle is unsafe once navigation bounces between screens.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // P0 checks out for real (D20 from 40); P1 finishes the round with three
    // singles so the round resolves → result screen.
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2);
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(20, 1);
    }
    await settle();
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    // Deferred: nothing persisted while the result screen is open.
    var saved = await PlayerStorage.loadPlayers();
    expect(saved.every((p) => p.gamesPlayed == 0), isTrue,
        reason: 'stats must not be persisted while the result screen is open');
    expect(await GameHistoryService.load(), isEmpty);

    // But the rating preview must still be shown on the result screen.
    final result = s.buildGameResultForTest();
    expect(result.results.first.ratingBefore, isNotNull,
        reason: 'rating deltas must be previewed despite deferred recording');
    expect(result.results.first.ratingAfter, isNotNull);
    expect(result.results.first.ratingAfter,
        isNot(equals(result.results.first.ratingBefore)));

    // Back pops P1's last dart and re-opens the game → still nothing.
    await tester.tap(find.text('↶ BACK'));
    await settle();
    saved = await PlayerStorage.loadPlayers();
    expect(saved.every((p) => p.gamesPlayed == 0), isTrue,
        reason: 'Back must not leave a recorded game behind');
    expect(await GameHistoryService.load(), isEmpty);

    // P1 re-throws the third dart → round resolves → result screen again
    // (the double-record scenario from B1).
    await s.onDartHitForTest(20, 1);
    await settle();
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    // Leave via Finish Game → recorded exactly once.
    await tester.tap(find.text('✓ FINISH GAME'));
    await settle();
    await settle();

    saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    expect(a.gamesPlayed, 1, reason: 'undo cycle must not double-count');
    expect(a.gamesWon, 1);
    expect(b.gamesPlayed, 1);
    expect(b.gamesWon, 0);
    expect((await GameHistoryService.load()).length, 1,
        reason: 'exactly one history entry per real game');
  });
}
