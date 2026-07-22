import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';

/// Pumps a 3-player Killer game (random numbers, so the assignment phase is
/// skipped) and returns the dynamic state, arranged so P0 is a killer and P1
/// sits at 1 life — a single hit on P1's number eliminates them.
Future<dynamic> pumpArrangedKillerGame(WidgetTester tester) async {
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
    Player(name: 'P2', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: KillerGameScreen(
      players: players,
      config: const KillerConfig(throwToPick: false, lives: 3),
    ),
  ));
  await tester.pumpAndSettle();

  final dynamic state =
      tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));
  // Arrange directly through state: P0 is a killer, P1 is one hit from out.
  state.isKiller[0] = true;
  state.lives[1] = 1;
  return state;
}

void main() {
  testWidgets('undone elimination rolls back the in-turn kill counter',
      (tester) async {
    final dynamic state = await pumpArrangedKillerGame(tester);
    final int p1Number = state.assignedNumbers[1];

    await state.onDartHitForTest(p1Number, 1); // eliminates P1 → kill
    await tester.pumpAndSettle();
    expect(state.killsThisTurnForTest, 1,
        reason: 'precondition: the elimination must register as a kill');

    state.undoForTest();
    await tester.pumpAndSettle();

    expect(state.killsThisTurnForTest, 0,
        reason: 'undo must roll back the kill counter');
    expect(state.maxKillsInTurnForTest[0] ?? 0, 0);
  });

  testWidgets(
      'undone elimination rolls back committed max-kills (KILLING SPREE)',
      (tester) async {
    final dynamic state = await pumpArrangedKillerGame(tester);
    final int p1Number = state.assignedNumbers[1];

    // Two misses, then the kill on the third dart — the turn commits and the
    // kill lands in the per-player max-kills map that feeds KILLING SPREE.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(p1Number, 1);
    await tester.pumpAndSettle();
    expect(state.maxKillsInTurnForTest[0], 1,
        reason: 'precondition: committed turn must record the kill');

    state.undoForTest(); // undoes the killing dart (and the turn commit)
    await tester.pumpAndSettle();

    expect(state.maxKillsInTurnForTest[0] ?? 0, 0,
        reason: 'undo must roll back the committed max-kills map');
    expect(state.killsThisTurnForTest, 0);
  });
}
