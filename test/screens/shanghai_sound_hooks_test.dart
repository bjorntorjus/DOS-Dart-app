import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
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
      home: ShanghaiGameScreen(
        players: [Player(name: 'P1', score: 0), Player(name: 'P2', score: 0)],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<ShanghaiGameScreen>>(
        find.byType(ShanghaiGameScreen));
  }

  testWidgets('instant shanghai plays shanghai/shanghai', (tester) async {
    final s = await pumpGame(tester);
    SoundService.instance.playedForTest.clear();
    // Round 1 target = 1: S1, D1, T1 in one turn = instant Shanghai.
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.double_);
    s.onHitForTest(HitType.triple);
    await settle(tester);
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('shanghai/shanghai'));
    expect(played, isNot(contains('shanghai/hole_cleared')));
  });

  testWidgets('three singles on the target play hole_cleared, not shanghai',
      (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    await settle(tester);
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('shanghai/hole_cleared'));
    expect(played, isNot(contains('shanghai/shanghai')));
  });

  testWidgets('two hits and a miss play neither', (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.miss);
    await settle(tester);
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('shanghai/')));
  });

  testWidgets(
      'three singles do NOT play hole_cleared when memes are off',
      (tester) async {
    // meme_enabled unset/false (memes off) is the point of this test, but
    // meme_frequency is pinned to 10 (frequencyChance == 1) anyway: with the
    // default frequency (3 -> chance 1/6), an unseeded Random means a broken
    // gate would still only fire the sound 1/6 of the time, so this negative
    // would pass ~83% of runs even without the gate. Pinning makes a missing
    // gate fail deterministically instead of flakily.
    final s = await pumpGame(tester, prefs: const {'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    s.onHitForTest(HitType.single);
    await settle(tester);
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('shanghai/hole_cleared')));
  });
}
