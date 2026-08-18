import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  // SoundService.instance is deliberately NOT touched here: constructing the
  // singleton builds an AudioPlayer, and doing that before a widget pump has
  // driven the test binding leaves a stray platform-channel error that
  // surfaces on a LATER test (see x01_meme_gate_test.dart). Each test clears
  // the spy after pumping instead.
  setUp(() {
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester,
      {int players = 2, Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          for (var i = 0; i < players; i++)
            Player(name: String.fromCharCode(65 + i), score: 501),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  testWidgets('a 180 turn plays x01/one_eighty when memes are on',
      (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3); // 180!
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('x01/one_eighty'));
  });

  testWidgets('a 174 turn does NOT play x01/one_eighty', (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(18, 3); // 174
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('x01/one_eighty')));
  });

  testWidgets(
      'a 180 turn does NOT play x01/one_eighty when memes are off',
      (tester) async {
    // meme_enabled unset/false (memes off) is the point of this test, but
    // meme_frequency is pinned to 10 (frequencyChance == 1) anyway: with the
    // default frequency (3 -> chance 1/6), an unseeded Random means a broken
    // gate would still only fire the sound 1/6 of the time, so this negative
    // would pass ~83% of runs even without the gate. Pinning makes a missing
    // gate fail deterministically instead of flakily.
    final s = await pumpGame(tester, prefs: const {'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3); // 180!
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('x01/one_eighty')));
  });

  testWidgets('sudden death start plays x01/sudden_death', (tester) async {
    final s = await pumpGame(tester);
    SoundService.instance.playedForTest.clear();
    // Force the tie → sudden-death path the way
    // test/screens/x01_sudden_death_stats_test.dart does: both players
    // checkout on equal darts in the same round.
    const turns = [
      [(20, 3), (20, 3), (20, 3)], // 180 → 321
      [(20, 3), (20, 3), (19, 3)], // 177 → 144
      [(20, 3), (12, 3), (8, 1)], // 104 → 40
    ];
    for (final turn in turns) {
      for (var p = 0; p < 2; p++) {
        for (final (seg, mul) in turn) {
          await s.onDartHitForTest(seg, mul);
        }
      }
    }
    await s.onDartHitForTest(20, 2); // P0 checks out from 40 with dart 1
    await s.onDartHitForTest(20, 2); // P1 checks out identically → SD
    await settle(tester);

    expect(SoundService.instance.playedForTest.join(','),
        contains('x01/sudden_death'));
  });
}
