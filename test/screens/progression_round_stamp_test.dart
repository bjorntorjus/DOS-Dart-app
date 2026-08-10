import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';
import 'package:dart_scoring/stats/mode_progression.dart';

/// MATCH FLOW needs one plotted point PER ROUND. The series is built by
/// grouping throws on `DartThrow.roundNumber`, so a mode that never stamps it
/// puts every dart in round 0 and the chart collapses to two points — start
/// and finish, a straight line with no story (tester feedback 2026-08-10).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> sized(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Cricket stamps a rising round number and plots per round',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const CricketConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // Three full rounds: 2 players × 3 darts × 3.
    for (var i = 0; i < 18; i++) {
      await s.registerHitForTest(20, 1);
      await tester.pump();
    }

    final throws = s.throwHistory as List;
    final mine = throws.where((t) => t.playerIndex == 0).toList();
    final rounds = {for (final t in mine) t.roundNumber}.toList()..sort();
    expect(rounds.length, 3,
        reason: 'three rounds played must produce three distinct round numbers');

    final series = progressionForMode('cricket', List.from(throws))!
        .seriesFor(List.from(throws), playerIndex: 0);
    expect(series.length, 4,
        reason: 'start + one point per round — not just start and finish');
    // Marks accumulate, so the line has to actually move between points.
    expect(series.toSet().length, greaterThan(2),
        reason: 'a flat two-value series is the bug being fixed');
  });

  testWidgets('Splitscore stamps a rising round number and plots per round',
      (tester) async {
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

    for (var i = 0; i < 18; i++) {
      await s.onDartHitForTest(20, 1);
      await tester.pump();
    }

    final throws = s.throwHistory as List;
    final mine = throws.where((t) => t.playerIndex == 0).toList();
    final rounds = {for (final t in mine) t.roundNumber}.toList()..sort();
    expect(rounds.length, greaterThan(1),
        reason: 'several rounds played must produce several round numbers');

    final series = progressionForMode('halveIt', List.from(throws))!
        .seriesFor(List.from(throws), playerIndex: 0);
    expect(series.length, rounds.length + 1,
        reason: 'start + one point per round');
  });
}
