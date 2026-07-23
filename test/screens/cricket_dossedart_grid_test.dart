import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';

/// Regression/coverage for the Cricket DOSSEDART grid restyle (A+
/// w/SEGMENTS): per-player accents, the live 👑 leader on the grid header,
/// DEAD tags on rows closed by every player, and the 3-segment marks meter
/// inside the active player's tappable cells. Every scenario is driven
/// through the screen's real tap targets (the S/D/T sub-cells + the ✗ MISS
/// action), never via engine internals.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Widget buildCricket({bool isCutthroat = false}) {
    return MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
          Player(name: 'P2', score: 0),
        ],
        config: CricketConfig(isCutthroat: isCutthroat),
        useDossedartDesign: true,
      ),
    );
  }

  Future<void> pumpCricket(WidgetTester tester, {bool isCutthroat = false}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildCricket(isCutthroat: isCutthroat));
    await tester.pumpAndSettle();
  }

  /// The active cell's sub-cell labels ('20', 'D20', 'T20', ...) collide with
  /// the plain target-column label ('20') that always renders in the same
  /// row — only the tappable sub-cell is wrapped in a GestureDetector, so
  /// walking up from the matching Text to that ancestor disambiguates them
  /// and gives back the real tap target instead of the static label.
  Future<void> tapSubCell(WidgetTester tester, String label) async {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(GestureDetector),
    );
    expect(finder, findsOneWidget,
        reason: 'expected exactly one tappable sub-cell for "$label"');
    await tester.tap(finder);
  }

  Future<void> tapMiss(WidgetTester tester) async {
    await tester.tap(find.text('✗ MISS'));
  }

  testWidgets('leader crown: unique highest points, none on tie',
      (tester) async {
    await pumpCricket(tester);

    expect(find.text('👑'), findsNothing,
        reason: 'all players start tied at 0 — no unique leader yet');

    // P0 (active) puts a single mark on 20, then a triple on top of it: the
    // triple closes 20 (1 + 3 = 4 marks) AND overflows by 1 mark in the same
    // dart, scoring 20 points to P0 alone (standard rules: overflow scores to
    // the thrower once the target isn't closed by all).
    await tapSubCell(tester, '20');
    await tester.pump();
    await tapSubCell(tester, 'T20');
    await tester.pump();

    expect(find.text('👑'), findsOneWidget,
        reason: 'P0 alone scored points and must be the unique leader');

    final dynamic state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
    expect(state.scores[0], greaterThan(0));
    expect(state.scores[1], 0);
    expect(state.scores[2], 0);
  });

  testWidgets('cutthroat flips the crown to lowest points', (tester) async {
    await pumpCricket(tester, isCutthroat: true);

    expect(find.text('👑'), findsNothing);

    // Same dart sequence, but in cutthroat the overflow point lands on the
    // OPPONENTS (P1/P2), not on the thrower — leaving P0 at 0, the lowest
    // (and therefore leading) score.
    await tapSubCell(tester, '20');
    await tester.pump();
    await tapSubCell(tester, 'T20');
    await tester.pump();

    expect(find.text('👑'), findsOneWidget);

    final dynamic state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
    expect(state.scores[0], 0,
        reason: 'cutthroat overflow never scores to the thrower');
    expect(state.scores[1], greaterThan(0));
    expect(state.scores[2], greaterThan(0));
  });

  testWidgets('segments meter mirrors own marks in the active cell',
      (tester) async {
    await pumpCricket(tester);

    await tapSubCell(tester, '19');
    await tester.pump();

    final accent = dossedartAccent(0); // P0 is the starting active player

    final filled =
        tester.widget<Container>(find.byKey(const ValueKey('seg-19-0')));
    final empty1 =
        tester.widget<Container>(find.byKey(const ValueKey('seg-19-1')));
    final empty2 =
        tester.widget<Container>(find.byKey(const ValueKey('seg-19-2')));

    expect((filled.decoration as BoxDecoration).color, accent,
        reason: 'first segment fills after the single hit');
    expect((empty1.decoration as BoxDecoration).color,
        Colors.black.withValues(alpha: 0.4),
        reason: 'second segment stays empty');
    expect((empty2.decoration as BoxDecoration).color,
        Colors.black.withValues(alpha: 0.4),
        reason: 'third segment stays empty');
  });

  testWidgets('closed-by-all row shows DEAD tag', (tester) async {
    await pumpCricket(tester);

    // Close 20 for every player, rotating turns via two ✗ MISS taps between
    // each player's closing triple (Cricket auto-advances after 3 darts).
    await tapSubCell(tester, 'T20'); // P0 closes 20
    await tester.pump();
    await tapMiss(tester);
    await tester.pump();
    await tapMiss(tester);
    await tester.pump();

    await tapSubCell(tester, 'T20'); // P1 closes 20
    await tester.pump();
    await tapMiss(tester);
    await tester.pump();
    await tapMiss(tester);
    await tester.pump();

    expect(find.text('DEAD'), findsNothing,
        reason: 'only 2 of 3 players have closed 20 so far');

    await tapSubCell(tester, 'T20'); // P2 closes 20 — now closed by all
    await tester.pump();

    expect(find.text('DEAD'), findsOneWidget);
  });
}
