import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

void main() {
  testWidgets('undone third-dart hit removes the clutch-save flag',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(
        players: players,
        config: const HalveItConfig(),
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic state = tester
        .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
    // The fixed (non-random) config starts on a plain number round; hitting
    // its target with the third dart after two misses is a clutch save.
    final int target = state.rounds[0].targetNumber;

    await state.onDartHitForTest(0, 0); // dart 1 miss
    await state.onDartHitForTest(0, 0); // dart 2 miss
    await state.onDartHitForTest(target, 1); // dart 3 hit -> clutch flagged
    await tester.pumpAndSettle();
    expect(state.clutchSaversForTest, contains(0),
        reason: 'precondition: the saving dart must flag the clutch save');

    state.undoForTest(); // undo the saving dart
    await tester.pumpAndSettle();
    expect(state.clutchSaversForTest, isNot(contains(0)),
        reason: 'undo must unwind the clutch flag');
  });
}
