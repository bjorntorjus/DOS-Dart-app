import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';

void main() {
  testWidgets('undone bust does not count toward bustCount', (tester) async {
    final players = [
      Player(name: 'P0', score: 41),
      Player(name: 'P1', score: 41),
    ];
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: players,
        startingScore: 41, // small score so a T20 busts immediately
        masterOut: 'double',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic state =
        tester.state<State<GameScreen>>(find.byType(GameScreen));

    await state.onDartHitForTest(20, 3); // 41-60 → bust, recorded in history
    await tester.pumpAndSettle();
    state.undoForTest(); // pops the bust throw
    await tester.pumpAndSettle();

    expect(state.bustCountForTest(0), 0,
        reason: 'an undone bust must not count toward SURGEON');
  });
}
