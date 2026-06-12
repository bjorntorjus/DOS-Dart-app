import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/halve_it_round.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

// The fixed (non-random) HalveItConfig round list is:
//   0: 15, 1: 16, 2: anyDouble, 3: 17, 4: 18, 5: anyTriple, 6: 19, 7: 20, 8: bull
// so the D-keypad shows in round index 2 and the T-keypad in round index 5.

Future<dynamic> _pumpSplitscore(WidgetTester tester) async {
  // Tablet portrait (Galaxy Tab A target).
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: HalveItGameScreen(
      players: players,
      config: const HalveItConfig(),
      useDossedartDesign: true,
    ),
  ));
  await tester.pumpAndSettle();
  return tester
      .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
}

/// Plays one full round (3 darts x 2 players) hitting [segment]x[mult].
/// Hits (not misses) are used so no three-miss video event can fire, and the
/// segments are picked low enough that no high-round (>=120) event fires.
Future<void> _playRound(dynamic state, WidgetTester tester,
    {required int segment, required int mult}) async {
  for (int dart = 0; dart < 6; dart++) {
    await state.onDartHitForTest(segment, mult);
  }
  await tester.pumpAndSettle();
}

Rect _btnRect(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first);

void main() {
  testWidgets('double round shows D1-D20 in 4 rows of 5 plus full-width D-BULL',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    await _playRound(state, tester, segment: 15, mult: 1); // round 0
    await _playRound(state, tester, segment: 16, mult: 1); // round 1
    expect(state.rounds[state.currentRoundIndex].type,
        HalveItRoundType.anyDouble,
        reason: 'sanity: round index 2 of the fixed config is Any Double');

    // All 21 keys are present.
    for (int k = 1; k <= 20; k++) {
      expect(find.text('D$k'), findsOneWidget);
    }
    expect(find.text('D-BULL'), findsOneWidget);

    // 4 rows of 5: D1-D5 share a row, D6 starts the next one, and the row
    // starters line up in a column.
    final d1 = _btnRect(tester, 'D1');
    final d5 = _btnRect(tester, 'D5');
    final d6 = _btnRect(tester, 'D6');
    final d11 = _btnRect(tester, 'D11');
    final d16 = _btnRect(tester, 'D16');
    final d20 = _btnRect(tester, 'D20');
    expect(d1.top, d5.top, reason: 'D1 and D5 must sit on the same row');
    expect(d6.top, greaterThan(d1.top),
        reason: 'D6 must start the second row');
    expect(d11.top, greaterThan(d6.top),
        reason: 'D11 must start the third row');
    expect(d16.top, greaterThan(d11.top),
        reason: 'D16 must start the fourth row');
    expect(d6.left, d1.left, reason: 'row starters must align in a column');
    expect(d11.left, d1.left);
    expect(d16.left, d1.left);

    // All 20 number keys share the same (bigger) size.
    for (int k = 2; k <= 20; k++) {
      final r = _btnRect(tester, 'D$k');
      expect(r.width, moreOrLessEquals(d1.width, epsilon: 1.0),
          reason: 'D$k must be as wide as D1');
      expect(r.height, moreOrLessEquals(d1.height, epsilon: 1.0),
          reason: 'D$k must be as tall as D1');
    }

    // D-BULL is a full-width row below the grid.
    final dbull = _btnRect(tester, 'D-BULL');
    expect(dbull.top, greaterThan(d20.top),
        reason: 'D-BULL must sit on its own row below D20');
    expect(dbull.width, greaterThan(d1.width * 4),
        reason: 'D-BULL must span the full keypad width');

    expect(tester.takeException(), isNull,
        reason: 'the keypad must build without overflow');
  });

  testWidgets('triple round shows T1-T20 in 4 rows of 5 without a bull key',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    await _playRound(state, tester, segment: 15, mult: 1); // round 0
    await _playRound(state, tester, segment: 16, mult: 1); // round 1
    await _playRound(state, tester, segment: 1, mult: 2); //  round 2 (D1 hits)
    await _playRound(state, tester, segment: 17, mult: 1); // round 3
    await _playRound(state, tester, segment: 18, mult: 1); // round 4
    expect(state.rounds[state.currentRoundIndex].type,
        HalveItRoundType.anyTriple,
        reason: 'sanity: round index 5 of the fixed config is Any Triple');

    for (int k = 1; k <= 20; k++) {
      expect(find.text('T$k'), findsOneWidget);
    }
    expect(find.text('D-BULL'), findsNothing,
        reason: 'the triple round has no bull key');

    final t1 = _btnRect(tester, 'T1');
    final t5 = _btnRect(tester, 'T5');
    final t6 = _btnRect(tester, 'T6');
    expect(t1.top, t5.top, reason: 'T1 and T5 must sit on the same row');
    expect(t6.top, greaterThan(t1.top),
        reason: 'T6 must start the second row');
    expect(t6.left, t1.left, reason: 'row starters must align in a column');

    expect(tester.takeException(), isNull,
        reason: 'the keypad must build without overflow');
  });
}
