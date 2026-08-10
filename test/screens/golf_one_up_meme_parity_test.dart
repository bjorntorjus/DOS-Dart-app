import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Golf and 1UP used to reach only the miss meme (audit 2026-08-10, F3).
///
/// SoundService.instance is not touched in setUp on purpose — constructing
/// the singleton builds an AudioPlayer, and doing that before the binding is
/// up leaves a platform-channel error that lands after the test finishes.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'meme_enabled': true, 'meme_frequency': 10, 'meme_67': true});
    VideoService.instance.setEnabled(false);
  });

  Future<void> sized(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('1UP: a 6 then a 7 triggers the six-seven meme', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)],
        config: const OneUpConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
    SoundService.instance.playedForTest.clear();

    s.onDartHitForTest(6, 1);
    await tester.pumpAndSettle();
    s.onDartHitForTest(7, 1);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest.join(','), contains('six_seven'));
  });

  testWidgets('Golf: a hit produces no meme sound — miss stings only',
      (tester) async {
    // Golf is the documented exception (see golf_game_screen.dart's comment
    // in _onDartHit): every dart in a turn targets the same hole, so no 6-7
    // sequence is possible, and DartThrow.points is a placeholder, so the
    // point-summing memes have nothing real to read. This pins the deviation
    // so it reads as a decision rather than an oversight.
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));
    SoundService.instance.playedForTest.clear();

    s.onDartHitForTest(3); // a hit on hole 1
    await tester.pumpAndSettle();

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('six_seven')));
    expect(played, isNot(contains('end of round')));
  });
}
