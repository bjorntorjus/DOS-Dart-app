import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

Future<dynamic> _pumpGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 501),
    Player(name: 'P1', score: 501),
  ];
  await tester.pumpWidget(MaterialApp(
    home: GameScreen(
      players: players,
      startingScore: 501,
      masterOut: 'double',
      handicap: false,
      noBust: false,
      useDossedartDesign: true,
    ),
  ));
  await tester.pumpAndSettle();
  return tester.state<State<GameScreen>>(find.byType(GameScreen));
}

void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);
  tearDownAll(() => ArcadeFrame.disableBeamForTest = false);

  testWidgets('LAST updates live as darts land in the current turn',
      (tester) async {
    final dynamic state = await _pumpGame(tester);

    // Dart 1 of the very first turn: visible immediately, not next turn.
    await state.onDartHitForTest(20, 3);
    await tester.pumpAndSettle();
    expect(find.text('T20'), findsWidgets,
        reason: 'LAST must show the in-progress turn after the first dart');

    // Dart 2 appends to the same row.
    await state.onDartHitForTest(19, 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('T20 · S19'), findsWidgets,
        reason: 'LAST must grow dart-by-dart within the turn');

    // Undo the second dart → label shows only T20 again (history-derived).
    state.undoForTest();
    await tester.pumpAndSettle();
    expect(find.text('T20'), findsWidgets,
        reason: 'undo must roll the live LAST row back to the first dart');
    expect(find.textContaining('S19'), findsNothing,
        reason: 'the undone dart must disappear from the LAST row');
  });

  testWidgets('between turns LAST shows the previous completed turn',
      (tester) async {
    final dynamic state = await _pumpGame(tester);

    // P0 throws a full turn (84 total — no special video events fire).
    await state.onDartHitForTest(20, 3);
    await state.onDartHitForTest(19, 1);
    await state.onDartHitForTest(5, 1);
    await tester.pumpAndSettle();

    // Turn auto-advanced: P1 is active with no darts, so the card shows the
    // placeholder — P0's turn label is gone (card renders active player only).
    expect(find.textContaining('T20 · S19 · S5'), findsNothing,
        reason: 'the card shows the active player (P1), not P0');
    expect(find.text('— · — · —'), findsOneWidget,
        reason: 'P1 has thrown nothing yet — placeholder expected');

    // P1 throws a full turn → play returns to P0; the card now shows P0's
    // previous completed turn.
    await state.onDartHitForTest(20, 1);
    await state.onDartHitForTest(5, 1);
    await state.onDartHitForTest(5, 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('T20 · S19 · S5'), findsOneWidget,
        reason: 'back on P0: LAST shows their previous completed turn');
  });
}
