import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

/// F20c (audit 2026-07-06): Splitscore's core halving rule (`_finishTurn` in
/// halve_it_game_screen.dart: hit -> add points; miss all 3 darts ->
/// `totalScores[pi] ~/= 2`, with the round cell storing `-lost`) was asserted
/// nowhere. These tests lock it in via the ForTest hooks, mirroring the
/// pump/config setup used in halve_it_keypad_test.dart's `_pumpSplitscore`.
///
/// The fixed (non-random) HalveItConfig round list is:
///   0: 15, 1: 16, 2: anyDouble, 3: 17, 4: 18, 5: anyTriple, 6: 19, 7: 20, 8: bull
/// Rounds 0 and 1 are plain "number" rounds: any dart with segment ==
/// targetNumber hits, regardless of multiplier (see HalveItRound.isHit).
/// `onDartHitForTest(0, 0)` never matches any round type, so it is always a
/// guaranteed miss.

Future<dynamic> _pumpSplitscore(WidgetTester tester) async {
  // Tablet portrait (Galaxy Tab A target) — small windows overflow the
  // scorecard layout, which flutter_test treats as a hard test failure.
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
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
  return tester
      .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
}

void main() {
  testWidgets(
      'a full-turn miss floor-halves the total and records the -lost cell',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    // Every player starts at Splitscore's fixed base score of 40.
    expect(state.totalScoresForTest, [40, 40]);
    expect(state.currentPlayerIndexForTest, 0);
    expect(state.currentRoundIndexForTest, 0);
    final int round0Target = state.rounds[0].targetNumber as int;

    // P0's turn, round 0: hit the target with 2 of the 3 darts (miss the
    // 3rd). turnHasHit is true, so the turn banks points -> an even total,
    // keeping this test's halving a plain, non-flooring case (Test 2 below
    // covers the odd/flooring case explicitly).
    await state.onDartHitForTest(round0Target, 1); // hit  (+target)
    await state.onDartHitForTest(round0Target, 1); // hit  (+target)
    await state.onDartHitForTest(0, 0); // miss
    await tester.pumpAndSettle();

    expect(state.currentPlayerIndexForTest, 1,
        reason: 'turn must rotate to P1 after 3 darts');
    final int before = state.totalScoresForTest[0] as int;
    expect(before, 40 + 2 * round0Target,
        reason: 'a banked (hit) turn must add its points to the total');
    expect(before.isEven, isTrue,
        reason: 'precondition: this test exercises the non-flooring case');
    expect(state.roundScores[0][0], 2 * round0Target,
        reason: 'a banked round must record its positive turn total');

    // P1 plays out round 0 (values irrelevant to this test) so round 1
    // begins with P0 again.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    expect(state.currentRoundIndexForTest, 1);
    expect(state.currentPlayerIndexForTest, 0);

    // Round 1: P0 misses all three darts -> full-turn halving.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    final int expectedHalved = before ~/ 2;
    final int expectedLost = before - expectedHalved;
    expect(state.totalScoresForTest[0], expectedHalved,
        reason: 'a full-turn miss must floor-halve the total');
    expect(state.roundScores[1][0], -expectedLost,
        reason: 'a halved round must record the negative amount lost');
  });

  testWidgets('halving an odd total floors down rather than rounding',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);
    final int round0Target = state.rounds[0].targetNumber as int;

    // P0 hits the round-0 target with exactly 1 of 3 darts: 40 (even start)
    // + one target hit (the fixed config's round-0 target, 15, is odd) ->
    // an ODD total before halving.
    await state.onDartHitForTest(round0Target, 1); // hit
    await state.onDartHitForTest(0, 0); // miss
    await state.onDartHitForTest(0, 0); // miss
    await tester.pumpAndSettle();

    final int before = state.totalScoresForTest[0] as int;
    expect(before, 40 + round0Target);
    expect(before.isOdd, isTrue,
        reason: 'precondition: the pre-halving total must be odd to '
            'exercise floor division');

    // P1 plays out round 0 so round 1 begins with P0.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(state.currentRoundIndexForTest, 1);
    expect(state.currentPlayerIndexForTest, 0);

    // Round 1: P0 misses all three darts -> halved with floor division.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    final int expectedHalved = before ~/ 2;
    expect(before - expectedHalved * 2, 1,
        reason: 'sanity: floor division on an odd number must drop a '
            'remainder of exactly 1, not round up');
    expect(state.totalScoresForTest[0], expectedHalved,
        reason: 'an odd total must floor down, not round, when halved');
    expect(state.roundScores[1][0], -(before - expectedHalved));
  });
}
