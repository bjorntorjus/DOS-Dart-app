import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  // SoundService.instance is deliberately NOT touched in setUp: constructing
  // the singleton builds an AudioPlayer, and doing that before a widget pump
  // has driven the test binding leaves a stray platform-channel error that
  // surfaces on a LATER test (see x01_sound_hooks_test.dart). Each test clears
  // the spy after pumping instead.
  setUp(() {
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester,
      {int playerCount = 3, Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          for (var i = 0; i < playerCount; i++)
            Player(name: String.fromCharCode(65 + i), score: 0),
        ],
        config: CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: true,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<CricketGameScreen>>(
        find.byType(CricketGameScreen));
  }

  testWidgets('closing a number plays cricket/closed', (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.registerHitForTest(20, 3); // T20 = 3 marks = closed
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('cricket/closed'));
  });

  testWidgets('two marks do NOT play cricket/closed', (tester) async {
    final s = await pumpGame(tester,
        prefs: const {'meme_enabled': true, 'meme_frequency': 10});
    SoundService.instance.playedForTest.clear();
    await s.registerHitForTest(20, 2); // D20 = 2 marks — not closed
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('cricket/closed')));
  });

  testWidgets(
      'closing the last target plays cricket/closed_all (not just closed)',
      (tester) async {
    final s = await pumpGame(tester,
        playerCount: 3, prefs: const {'meme_enabled': true, 'meme_frequency': 10});

    // Close 15-20 with triples + bull with 3 singles over A's turns, with B
    // and C throwing misses between (mirrors
    // test/screens/cricket_continue_prompt_test.dart's finishPlayerA).
    Future<void> othersMiss() async {
      for (var p = 0; p < 2; p++) {
        for (var d = 0; d < 3; d++) {
          await s.registerHitForTest(0, 0);
        }
      }
    }

    await s.registerHitForTest(15, 3);
    await s.registerHitForTest(16, 3);
    await s.registerHitForTest(17, 3);
    await othersMiss();
    await s.registerHitForTest(18, 3);
    await s.registerHitForTest(19, 3);
    await s.registerHitForTest(20, 3);
    await othersMiss();
    await s.registerHitForTest(25, 1);
    await s.registerHitForTest(25, 1);
    // Clear the seam right before the closing dart to isolate its sounds.
    SoundService.instance.playedForTest.clear();
    await s.registerHitForTest(25, 1); // 3rd bull single closes everything
    await settle(tester);

    final played = SoundService.instance.playedForTest;
    expect(played, contains('cricket/closed_all'));
    expect(played, isNot(contains('cricket/closed')));
  });
}
