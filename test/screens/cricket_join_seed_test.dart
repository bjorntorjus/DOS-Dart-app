import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// A joiner starts where the LAST-PLACED active player stands — not at the
/// table average (tester feedback 2026-08-10).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  SavedPlayer joiner() =>
      SavedPlayer(id: 'x', name: 'Late', createdAt: DateTime(2026));

  Future<dynamic> boot(WidgetTester tester, {required bool cutthroat}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: CricketConfig(isCutthroat: cutthroat),
      ),
    ));
    await tester.pumpAndSettle();
    return tester
        .state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
  }

  testWidgets('standard: joiner copies the LOWEST-scoring active player',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    // P0 leads on points, P1 trails.
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;
    s.engine.marks[0][20] = 3;
    s.engine.marks[1][20] = 3;
    s.engine.marks[0][19] = 3;
    s.engine.marks[1][19] = 1;

    s.addPlayerForTest(joiner());
    await tester.pump();

    // Averaging would have produced 29 points. Last place is 12.
    expect(s.engine.scores[2], 12);
    expect(s.engine.marks[2][19], 1, reason: 'copies last place, not average');
  });

  testWidgets('standard: a number closed by everyone stays closed',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;
    // 20 is dead — both players closed it.
    s.engine.marks[0][20] = 3;
    s.engine.marks[1][20] = 3;
    // 18 is closed by the leader only; last place has 1 mark.
    s.engine.marks[0][18] = 3;
    s.engine.marks[1][18] = 1;

    s.addPlayerForTest(joiner());
    await tester.pump();

    expect(s.engine.marks[2][20], 3,
        reason: '20 was closed by all — the joiner must not reopen it');
    expect(s.engine.isClosedByAll(20), isTrue);
    expect(s.engine.marks[2][18], 1,
        reason: '18 was NOT closed by all — copy last place verbatim');
  });

  testWidgets('cutthroat: joiner copies the HIGHEST-scoring active player',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: true);
    // In cutthroat, points are damage taken — highest is worst.
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;

    s.addPlayerForTest(joiner());
    await tester.pump();

    expect(s.engine.scores[2], 45,
        reason: 'cutthroat flips the direction of "last place"');
  });

  testWidgets('empty table falls back to zero without throwing',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    s.finishedPlayersForTest.addAll([0, 1]);

    s.addPlayerForTest(joiner());
    await tester.pump();

    expect(s.engine.scores[2], 0);
  });
}
