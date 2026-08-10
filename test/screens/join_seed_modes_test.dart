import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// A mid-game joiner is seeded from the LAST-PLACED active player, never the
/// table average (tester feedback 2026-08-10). Cricket, Golf, 1UP and WILDCARD
/// have their own files — this covers the six screen-state modes.
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

  testWidgets('X01: joiner inherits the HIGHEST remaining score',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'P0', score: 501),
          Player(name: 'P1', score: 501),
        ],
        startingScore: 501,
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    s.playersForTest[0].score = 40; // nearly finished
    s.playersForTest[1].score = 380; // last place

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Averaging would have produced 210. Last place is 380.
    expect(s.playersForTest[2].score, 380);
  });

  testWidgets('Shanghai: joiner inherits the LOWEST total', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const ShanghaiConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester
        .state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));

    s.engineForTest.totalScores[0] = 120;
    s.engineForTest.totalScores[1] = 30;

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Averaging would have produced 75. Last place is 30.
    expect(s.engineForTest.totalScores[2], 30);
  });

  testWidgets('Gotcha: joiner inherits the LOWEST total', (tester) async {
    await sized(tester);
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

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Averaging would have produced 110. Last place is 40.
    expect(s.engineForTest.totals[2], 40);
  });

  testWidgets('Splitscore: joiner inherits the LOWEST total', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const HalveItConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester
        .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));

    s.totalScoresForTest[0] = 200;
    s.totalScoresForTest[1] = 60;

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Averaging would have produced 130. Last place is 60.
    expect(s.totalScoresForTest[2], 60);
  });

  testWidgets('ATC: joiner inherits the LEAST-advanced target', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'P0', score: 1),
          Player(name: 'P1', score: 1),
        ],
        config: const AroundTheClockConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));

    s.currentTargetsForTest[0] = 17; // well ahead
    s.currentTargetsForTest[1] = 3; // last place

    s.addPlayerForTest(joiner());
    await tester.pump();

    // The old average-of-remaining walk landed near 10. Last place is on 3.
    expect(s.currentTargetsForTest[2], 3);
  });

  group('Killer', () {
    Future<dynamic> boot(WidgetTester tester) async {
      await sized(tester);
      await tester.pumpWidget(MaterialApp(
        home: KillerGameScreen(
          players: [
            Player(name: 'P0', score: 0),
            Player(name: 'P1', score: 0),
          ],
          config: const KillerConfig(lives: 3),
        ),
      ));
      await tester.pumpAndSettle();
      return tester
          .state<State<KillerGameScreen>>(find.byType(KillerGameScreen));
    }

    testWidgets('joiner inherits the FEWEST lives — no floor', (tester) async {
      final dynamic s = await boot(tester);
      s.livesForTest[0] = 3;
      s.livesForTest[1] = 1;

      s.addPlayerForTest(joiner());
      await tester.pump();

      // Averaging would have produced 2. Last place is on 1 — deliberately no
      // floor, so a future "be nice to joiners" change breaks this on purpose.
      expect(s.livesForTest[2], 1);
    });

    testWidgets('eliminated players are not treated as last place',
        (tester) async {
      final dynamic s = await boot(tester);
      s.livesForTest[0] = 3;
      s.livesForTest[1] = 0;
      s.isEliminatedForTest[1] = true;

      s.addPlayerForTest(joiner());
      await tester.pump();

      expect(s.livesForTest[2], 3,
          reason: 'a dead player is not the worst ACTIVE player');
    });
  });
}
