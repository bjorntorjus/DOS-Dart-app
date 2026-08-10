import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// A joiner is seeded from last place and is therefore tied with them. The
/// player who earned last place must keep their position (join-fairness
/// 2026-08-10, §2).
///
/// CHARACTERIZATION, not a regression guard. These assertions pass with or
/// without `withSeatTiebreak`: Dart's `List.sort` falls back to insertion sort
/// below 32 elements, and insertion sort is stable, so at realistic player
/// counts seat order already survives a tie. Verified by removing the tiebreak
/// and re-running (2026-08-10) — still green. The tiebreak stays because it
/// makes the invariant explicit and holds if a comparator is ever reordered,
/// but do NOT trust this file to catch its removal. The real coverage of the
/// tiebreak function itself is in test/utils/join_seed_test.dart.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('a zero-dart joiner never outranks the seat it copied',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const GotchaConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    s.engineForTest.totals[0] = 180;
    s.engineForTest.totals[1] = 40;
    s.addPlayerForTest(
        SavedPlayer(id: 'x', name: 'Late', createdAt: DateTime(2026)));
    await tester.pump();

    expect(s.engineForTest.totals[2], 40, reason: 'seeded from last place');

    for (var i = 0; i < 20; i++) {
      final List<int> ranked = s.rankPlayersForTest();
      expect(ranked.indexOf(1), lessThan(ranked.indexOf(2)),
          reason: 'P1 earned last place; the joiner sits below them');
    }
  });

  testWidgets('the post-game list puts the later seat below on a tie',
      (tester) async {
    // Two players tied on placement 2. The later seat — a mid-game joiner —
    // must be listed second.
    final result = GameResult(
      gameMode: 'gotcha',
      results: [
        PlayerResult(name: 'Winner', placement: 1),
        PlayerResult(name: 'Earned it', placement: 2),
        PlayerResult(name: 'Joiner', placement: 2),
      ],
    );

    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: result)));
      await tester.pumpAndSettle();

      final earned = tester.getTopLeft(find.text('Earned it')).dy;
      final joiner = tester.getTopLeft(find.text('Joiner')).dy;
      expect(earned, lessThan(joiner),
          reason: 'tied players keep seat order, newest last');
    }
  });
}
