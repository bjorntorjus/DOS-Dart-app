import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';

/// Pumps a 3-player Killer game with random (pre-assigned) numbers, so the
/// assignment phase is skipped — copied verbatim from the harness in
/// test/screens/killer_kills_undo_test.dart, with `suicide: true` added so
/// the self-hit rule is on.
Future<dynamic> pumpKillerGame(WidgetTester tester) async {
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
    Player(name: 'P2', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: KillerGameScreen(
      players: players,
      config: const KillerConfig(
        throwToPick: false,
        lives: 3,
        multiplyHits: false,
        shields: false,
        suicide: true,
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final dynamic state =
      tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));
  return state;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('hitting own double plays killer/became_killer', (tester) async {
    final s = await pumpKillerGame(tester);
    final int p0Number = s.assignedNumbers[0];
    SoundService.instance.playedForTest.clear();

    // P0 hits their own number's double, is not a Killer yet → becomes one.
    await s.onDartHitForTest(p0Number, 2);
    await settle(tester);

    expect(SoundService.instance.playedForTest.join(','),
        contains('killer/became_killer'));
  });

  testWidgets('a killer hitting their own number plays killer/self_hit',
      (tester) async {
    final s = await pumpKillerGame(tester);
    final int p0Number = s.assignedNumbers[0];

    // Become a Killer first (not the moment under test).
    await s.onDartHitForTest(p0Number, 2);
    SoundService.instance.playedForTest.clear();

    // P0 (already a Killer) hits their own number again → self-hit, costs
    // a life under the suicide rule.
    await s.onDartHitForTest(p0Number, 1);
    await settle(tester);

    expect(SoundService.instance.playedForTest.join(','),
        contains('killer/self_hit'));
  });

  testWidgets(
      'hitting another player\'s number before becoming a Killer plays neither',
      (tester) async {
    final s = await pumpKillerGame(tester);
    final int p1Number = s.assignedNumbers[1];
    SoundService.instance.playedForTest.clear();

    // P0 is not a Killer yet: a hit on P1's number has no game effect at
    // all (the "Must be Killer first!" branch), so neither hook should fire.
    // (Note: unlike the brief's suggested negative — a non-double hit on
    // OWN number before becoming Killer — the own-number branch makes you
    // a Killer on ANY hit regardless of multiplier, so that scenario would
    // actually fire killer/became_killer. This scenario is the true negative.)
    await s.onDartHitForTest(p1Number, 1);
    await settle(tester);

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('killer/became_killer')));
    expect(played, isNot(contains('killer/self_hit')));
  });
}
