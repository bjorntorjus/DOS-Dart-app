import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

void main() {
  testWidgets('cricket throws get distinct turnIds per turn', (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: players,
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // P0 full turn (3 darts) — Cricket auto-advances after the third dart —
    // then P1's first dart lands in a new turn.
    await state.registerHitForTest(20, 1);
    await state.registerHitForTest(20, 1);
    await state.registerHitForTest(20, 1);
    await tester.pumpAndSettle();
    await state.registerHitForTest(19, 1);
    await tester.pumpAndSettle();

    final history = state.throwHistory as List<DartThrow>;
    final ids = history.map((t) => t.turnId).toSet();
    expect(ids.length, 2, reason: 'two turns → two distinct turnIds');
    expect(history.take(3).map((t) => t.turnId).toSet().length, 1,
        reason: 'all three darts of P0\'s turn share one turnId');

    // Undo P1's dart — the counter must rewind to P1's turnId so a re-thrown
    // dart lands in the same turn (multi-undo across the turn boundary).
    state.undoForTest();
    await tester.pumpAndSettle();
    await state.registerHitForTest(18, 1);
    await tester.pumpAndSettle();

    final historyAfter = state.throwHistory as List<DartThrow>;
    expect(historyAfter.map((t) => t.turnId).toSet().length, 2,
        reason: 'undo + rethrow must reuse the same turnId, not mint a third');
  });
}
