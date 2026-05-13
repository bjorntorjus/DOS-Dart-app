import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/player.dart';

/// Convenience: build a list of `Player`s with the given starting score.
List<Player> buildPlayers({
  required List<String> names,
  required int startingScore,
}) {
  return [
    for (final name in names)
      Player(name: name, score: startingScore, savedPlayerId: null),
  ];
}

/// Pump a single screen as the home of a fresh MaterialApp.
///
/// Use this from each integration test after [setupTestEnvironment]. It
/// matches what production does in `main.dart` (no DOSSEDART chrome).
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  // pump() once to schedule init; do NOT pumpAndSettle here because some
  // screens kick off Future.delayed work (battery sampler etc.) that never
  // completes in a test environment. Each scenario decides how long to pump.
  await tester.pump();
}
