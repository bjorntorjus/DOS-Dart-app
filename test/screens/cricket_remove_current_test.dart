import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Regression test for the final review of the 2026-07-06 audit fix round 5:
/// removing the CURRENT player used to only bump `_turnIdCounter`, dropping
/// the `_scoreAtStartOfTurn` refresh + advance log/announce that
/// `_advancePlayer` performed pre-refactor. A stale `_scoreAtStartOfTurn`
/// skews the next player's `turnTotal` computation (spurious/suppressed
/// high-round video trigger).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets(
      'Cricket: removing the current player refreshes _scoreAtStartOfTurn '
      'for the new current player', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          // Cutthroat: P0's overflow lands points on the OPPONENTS, so the
          // new current player's score differs from the stale
          // _scoreAtStartOfTurn (0). With standard rules the removal would
          // happen while everyone else is still at 0 and the assertion
          // would pass with or without the fix (vacuous).
          isCutthroat: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    expect(s.currentPlayerIndexForTest, 0);

    // P0 closes 20 (triple) then overflows it with a second triple, mid-turn
    // (only 2 of 3 darts thrown) so P0 is still current. In cutthroat the
    // 3-mark overflow puts 60 points on each opponent.
    await s.registerHitForTest(20, 3);
    await s.registerHitForTest(20, 3);
    await tester.pump();
    expect(s.currentPlayerIndexForTest, 0);
    expect(s.scores[1], greaterThan(0),
        reason: 'the next player must have overflow points so a stale '
            '_scoreAtStartOfTurn (0) is distinguishable from the refresh');

    // Remove P0 while still current, mid-turn.
    s.removePlayerForTest(0);
    await tester.pump();

    expect(s.currentPlayerIndexForTest, isNot(0),
        reason: 'removing the current player must advance the rotation');
    final newCurrent = s.currentPlayerIndexForTest as int;
    expect(s.scoreAtStartOfTurnForTest, s.scores[newCurrent],
        reason: '_scoreAtStartOfTurn must be refreshed for the new current '
            'player, not left stale from the removed player\'s turn');
  });
}
