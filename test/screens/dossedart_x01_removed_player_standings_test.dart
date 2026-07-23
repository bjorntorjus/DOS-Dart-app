import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Regression for the standings rail leaking mid-game-removed players
/// (companion to the June 2026 removed-player-wins fixes in
/// test/screens/removed_player_winner_test.dart — same setup pattern,
/// applied to the DOSSEDART X01 cockpit's standings rail).
void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);
  tearDownAll(() => ArcadeFrame.disableBeamForTest = false);

  testWidgets(
      'removed player disappears from the standings rail; remaining '
      'players stay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final players = [
      Player(name: 'P0', score: 301),
      Player(name: 'P1', score: 301),
      Player(name: 'P2', score: 301),
    ];

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: players,
        startingScore: 301,
        masterOut: 'none',
        handicap: false,
        noBust: false,
        useDossedartDesign: true,
      ),
    ));
    await tester.pumpAndSettle();

    // Sanity: before removal, all three names appear in the rail. P0 is
    // the starting active player, so it renders twice (header + own row).
    expect(find.text('P0'), findsNWidgets(2));
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);

    final dynamic state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    state.removePlayerForTest(0);
    await tester.pumpAndSettle();

    // P0 was current when removed, so play auto-advances to P1, who is
    // now both the header's active player and the rail's active row —
    // hence 2 occurrences. P0 must not appear anywhere; P2 stays at 1.
    expect(find.text('P0'), findsNothing,
        reason: 'removed player must not appear in the standings rail');
    expect(find.text('P1'), findsNWidgets(2),
        reason: 'P1 became active: header + own rail row');
    expect(find.text('P2'), findsOneWidget,
        reason: 'untouched player must still render in the rail');
  });
}
