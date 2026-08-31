import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  // SoundService.instance is deliberately NOT touched in setUp (see
  // x01_sound_hooks_test.dart) — each test clears the spy after pumping
  // instead of constructing the singleton before the widget pump.
  setUp(() {
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: AroundTheClockConfig(
          includeBull: false,
          countMultiples: true,
          reverse: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
  }

  // Seat A hits its current target with a triple (3 steps) each dart; B and C
  // are not involved until this helper hands the turn back to A. Mirrors
  // atc_continue_prompt_test.dart's finishPlayerA loop, but stops once A's
  // next target is 19 instead of driving to a finish: 1→4→7→10→13→16→19 is
  // exactly two 3-dart turns (6 hits × 3 steps), landing on 19 on the dot.
  Future<void> advanceATo19(WidgetTester tester, dynamic s) async {
    for (var round = 0; round < 2; round++) {
      for (var d = 0; d < 3; d++) {
        final target = (s.currentTargetsForTest as List)[0] as int;
        await s.onDartHitForTest(target, 3);
      }
      for (var p = 0; p < 2; p++) {
        for (var d = 0; d < 3; d++) {
          await s.onDartHitForTest(0, 0);
        }
      }
    }
  }

  testWidgets('a triple advance (3 steps) plays triple_jump when memes are on',
      (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(1, 3); // T1 at target 1 → 3 steps
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('around_the_clock/triple_jump'));
  });

  testWidgets('a single advance does NOT play triple_jump', (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(1, 1);
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('around_the_clock/triple_jump')));
  });

  testWidgets(
      'a triple advance does NOT play triple_jump when memes are off',
      (tester) async {
    // meme_enabled unset/false (memes off) is the point of this test, but
    // meme_frequency is pinned to 10 (frequencyChance == 1) anyway: with the
    // default frequency (3 -> chance 1/6), an unseeded Random means a broken
    // gate would still only fire the sound 1/6 of the time, so this negative
    // would pass ~83% of runs even without the gate. Pinning makes a missing
    // gate fail deterministically instead of flakily.
    final s = await pumpGame(tester, prefs: const {'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.onDartHitForTest(1, 3); // 3 steps, but memes are off
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('around_the_clock/triple_jump')));
  });

  testWidgets('arriving at the final target plays final_target',
      (tester) async {
    final s = await pumpGame(tester);
    await advanceATo19(tester, s);
    expect((s.currentTargetsForTest as List)[0], 19);

    SoundService.instance.playedForTest.clear();
    // Single at 19 (the last-but-one target with includeBull: false) → 1
    // step → arrives at 20, the sequence's last target.
    await s.onDartHitForTest(19, 1);
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('around_the_clock/final_target'));
  });
}
