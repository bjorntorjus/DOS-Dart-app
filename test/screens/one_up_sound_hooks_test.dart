import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';

/// Sound-hook coverage for the 1UP moments not exercised by the smoke tests
/// in one_up_game_screen_test.dart: the last-life callout (which REPLACES
/// the plain life-lost sound for that beat) and the "Beat that!" big-target
/// callout.
void main() {
  testWidgets('dropping to the last life plays one_up/last_life, not life_lost',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 2),
      ),
    ));
    await tester.pump();

    final state =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
    final dyn = state as dynamic;
    SoundService.instance.playedForTest.clear();

    // A sets 100, B misses the whole turn -> B's 2 lives drop to 1.
    dyn.onDartHitForTest(20, 3);
    dyn.onDartHitForTest(20, 2);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    dyn.onDartHitForTest(0, 1);
    await tester.pump();

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('one_up/last_life'));
    expect(played, isNot(contains('one_up/life_lost')));
  });

  testWidgets('a fresh 100+ target plays one_up/target_set', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pump();

    final state =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
    final dyn = state as dynamic;
    SoundService.instance.playedForTest.clear();

    dyn.onDartHitForTest(20, 3);
    dyn.onDartHitForTest(20, 3);
    dyn.onDartHitForTest(20, 3); // 180 sets the target; advances to player B
    await tester.pump();

    expect(SoundService.instance.playedForTest.join(','),
        contains('one_up/target_set'));
  });
}
