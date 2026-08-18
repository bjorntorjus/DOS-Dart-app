import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';

/// Splitscore sound hooks (Task 6, sound-event-hooks 2026-08-18):
///   - `halve_it/halved` fires from the halving branch of `_finishTurn`
///     (a full-turn miss on the round target).
///   - `halve_it/clutch` fires when the third dart saves a turn from
///     halving after the first two darts missed (CLUTCH SAVE tracking).
/// The two are mutually exclusive per turn by definition: a turn either
/// bags points (possibly via a clutch save) or is halved, never both.
///
/// Drives mirror halve_it_halving_test.dart (halving) and
/// halve_it_clutch_undo_test.dart (clutch).

Future<dynamic> _pumpSplitscore(WidgetTester tester) async {
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
  testWidgets('a full-turn miss plays halve_it/halved', (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    // P0 plays out round 0 with any values (irrelevant to this test) so
    // round 1 begins with P0 again once P1 also plays.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    expect(state.currentRoundIndexForTest, 1);
    expect(state.currentPlayerIndexForTest, 0);

    SoundService.instance.playedForTest.clear();

    // Round 1: P0 misses all three darts -> full-turn halving.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest.join(','),
        contains('halve_it/halved'));
  });

  testWidgets('a clutch save plays halve_it/clutch and NOT halved',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);
    final int target = state.rounds[0].targetNumber as int;

    SoundService.instance.playedForTest.clear();

    // Two misses then a hit on the round target with the 3rd dart.
    await state.onDartHitForTest(0, 0); // dart 1 miss
    await state.onDartHitForTest(0, 0); // dart 2 miss
    await state.onDartHitForTest(target, 1); // dart 3 hit -> clutch save
    await tester.pumpAndSettle();

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('halve_it/clutch'));
    expect(played, isNot(contains('halve_it/halved')));
  });

  testWidgets('a normal hit-turn plays neither halved nor clutch',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);
    final int target = state.rounds[0].targetNumber as int;

    SoundService.instance.playedForTest.clear();

    // First dart hits the target -> not a clutch save, and the turn bags
    // points rather than being halved.
    await state.onDartHitForTest(target, 1); // dart 1 hit
    await state.onDartHitForTest(0, 0); // dart 2 miss
    await state.onDartHitForTest(0, 0); // dart 3 miss
    await tester.pumpAndSettle();

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('halve_it/halved')));
    expect(played, isNot(contains('halve_it/clutch')));
  });
}
