import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The meme switch must mean OFF. Two X01 sounds used to fire regardless of
/// it, and the bull sound had no chance gate at all (audit 2026-08-10, F1).
void main() {
  // SoundService.instance is deliberately NOT touched here: constructing the
  // singleton builds an AudioPlayer, and doing that before the test binding
  // is up leaves a platform-channel error that lands after the test finishes.
  // Each test clears the spy after pumping instead.
  setUp(() {
    VideoService.instance.setEnabled(false);
  });

  Future<dynamic> boot(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501)],
        startingScore: 501,
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  // Frequency 10 = chance 1 = "always", so playRandomMaybe's dice cannot make
  // a pass look clean by luck. With memes OFF the gate must still hold.
  const memesOffLoudDice = {'meme_enabled': false, 'meme_frequency': 10};

  testWidgets('memes off: a bull plays no sound', (tester) async {
    final dynamic s = await boot(tester, memesOffLoudDice);
    SoundService.instance.playedForTest.clear();

    await s.onDartHitForTest(25, 1);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest, isEmpty,
        reason: 'bull used to call play() unconditionally');
  });

  testWidgets('memes off: a T20 plays no sound', (tester) async {
    final dynamic s = await boot(tester, memesOffLoudDice);
    SoundService.instance.playedForTest.clear();

    await s.onDartHitForTest(20, 3);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest, isEmpty);
  });

  testWidgets('memes on at max frequency: a bull still plays', (tester) async {
    final dynamic s = await boot(
        tester, {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();

    await s.onDartHitForTest(25, 1);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest, isNotEmpty,
        reason: 'gating must not silence the sound when memes are ON');
  });
}
