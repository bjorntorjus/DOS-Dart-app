import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The three engine-backed modes seed their joiner from the last-placed
/// active player (spec 2026-08-10).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  SavedPlayer joiner() =>
      SavedPlayer(id: 'x', name: 'Late', createdAt: DateTime(2026));

  Future<void> sized(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('1UP: joiner inherits the FEWEST lives, not a full set',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const OneUpConfig(lives: 3),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));

    s.engineForTest.livesLeft[0] = 3;
    s.engineForTest.livesLeft[1] = 1;

    s.addPlayerForTest(joiner());
    await tester.pump();

    expect(s.engineForTest.livesLeft[2], 1,
        reason: 'a full 3 lives would out-rank everyone still playing');
  });

  testWidgets('Golf: joiner matches the HIGHEST stroke total exactly',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));

    final e = s.engineForTest;
    for (var h = 0; h < 5; h++) {
      e.scorecards[0][h] = 3; // 15 total — sharp
      e.scorecards[1][h] = h == 0 ? 6 : 4; // 22 total — last place
    }
    e.currentHole = 5;

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Par backfill would have given 15 — level with the LEADER.
    expect(e.total(2), 22);
  });

  testWidgets('WILDCARD: joiner inherits the LOWEST total, not 0',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const WildcardConfig(),
      ),
    ));
    // pump() with an explicit Duration, not pumpAndSettle: the WILDCARD
    // cockpit animates continuously (chaos meter), so it never settles —
    // same convention as wildcard_game_screen_test.dart.
    await tester.pump(const Duration(milliseconds: 300));
    final dynamic s = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    s.engineForTest.totals[0] = 300;
    s.engineForTest.totals[1] = 85;

    s.addPlayerForTest(joiner());
    await tester.pump();

    expect(s.engineForTest.totals[2], 85,
        reason: 'spec §7.2 amended 2026-08-10 — joiners follow the shared rule');
  });
}
