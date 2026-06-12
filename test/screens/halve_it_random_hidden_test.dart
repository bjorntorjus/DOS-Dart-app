import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

Future<dynamic> _pumpSplitscore(WidgetTester tester,
    {required bool isRandom}) async {
  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: HalveItGameScreen(
      players: players,
      config: HalveItConfig(isRandom: isRandom),
      useDossedartDesign: true,
    ),
  ));
  await tester.pumpAndSettle();
  return tester
      .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
}

void main() {
  testWidgets(
      'random mode hides future round targets as ? but shows the current one',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester, isRandom: true);

    final rounds = state.rounds as List;
    expect(rounds.length, greaterThan(1),
        reason: 'sanity: the random config must produce multiple rounds');

    // Every round except the current (first) one is hidden behind '?'.
    expect(find.text('?'), findsNWidgets(rounds.length - 1),
        reason: 'all future rounds must be masked in random mode');

    // The CURRENT round keeps its real label in the scorecard (it also shows
    // in the MÅL chip, so at least one occurrence is required).
    final currentLabel = (rounds[0].label as String).toUpperCase();
    expect(find.text(currentLabel), findsWidgets,
        reason: 'the active round must stay readable');
  });

  testWidgets('fixed mode never masks round targets', (tester) async {
    final dynamic state = await _pumpSplitscore(tester, isRandom: false);

    expect(find.text('?'), findsNothing,
        reason: 'fixed rounds are known up front — nothing to hide');

    // All round labels are visible from the start.
    final rounds = state.rounds as List;
    for (final r in rounds) {
      expect(find.text((r.label as String).toUpperCase()), findsWidgets,
          reason: 'fixed round ${r.label} must be visible in the scorecard');
    }
  });
}
