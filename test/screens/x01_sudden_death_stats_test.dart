import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Regression test for audit 2026-07-06 F4/B9: sudden death parked scores at
/// 999 and let tiebreak throws leak into stats — both tied players got
/// "best checkout 999" (an impossible record that also unlocked checkout
/// achievements) and an SD turn of 180 became a fake best-turn. Undo during
/// sudden death left one player stranded at 999.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets(
      'X01 sudden death: tiebreak throws never reach stats, '
      'undo is blocked, result screen offers no Back', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501, savedPlayerId: 'a'),
          Player(name: 'B', score: 501, savedPlayerId: 'b'),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Both players play identical real turns from 501 down to 40
    // (180, 177, 104 → 40 left), then check out D20 with the first dart of
    // the same round: identical darts + identical checkout score → tie →
    // sudden death. Real throws are required so scoreAtStartOfTurn is right.
    const turns = [
      [(20, 3), (20, 3), (20, 3)], // 180 → 321
      [(20, 3), (20, 3), (19, 3)], // 177 → 144
      [(20, 3), (12, 3), (8, 1)], // 104 → 40
    ];
    for (final turn in turns) {
      // Each turn is thrown twice: rotation gives it to P0, then P1.
      for (var p = 0; p < 2; p++) {
        for (final (seg, mul) in turn) {
          await s.onDartHitForTest(seg, mul);
        }
      }
    }
    await s.onDartHitForTest(20, 2); // P0 checks out from 40 with dart 1
    await s.onDartHitForTest(20, 2); // P1 checks out identically → SD
    await settle();

    // Sudden death round: P0 throws 180, P1 throws 3.
    await s.onDartHitForTest(20, 3);
    // Undo must be blocked mid-sudden-death (used to strand 999 state).
    final throwsBeforeUndo = s.throwCountForTest;
    s.undoForTest();
    await tester.pump();
    expect(s.throwCountForTest, throwsBeforeUndo,
        reason: 'undo during sudden death must be a no-op');
    for (var d = 0; d < 2; d++) {
      await s.onDartHitForTest(20, 3);
    }
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(1, 1);
    }
    await settle();

    // Result screen: sudden-death games offer no Back. Since the DOSSEDART
    // round (2026-08-10) an unavailable action is rendered and dimmed rather
    // than removed, so the primary action never shifts position — the button
    // is present but must not do anything.
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('↶ BACK'), findsOneWidget);
    await tester.tap(find.text('↶ BACK'), warnIfMissed: false);
    await settle();
    expect(find.text('✓ FINISH GAME'), findsOneWidget,
        reason: 'a sudden-death tiebreak cannot be rewound — Back is inert');

    // Displayed checkout must be the real one (40), not the parked 999.
    final result = s.buildGameResultForTest();
    for (final pr in result.results) {
      expect(pr.stats['checkout'], 40);
    }

    // Leave and check persisted stats.
    await tester.tap(find.text('✓ FINISH GAME'));
    await settle();
    await settle();

    final saved = await PlayerStorage.loadPlayers();
    final a = saved.firstWhere((p) => p.id == 'a');
    final b = saved.firstWhere((p) => p.id == 'b');
    expect(a.gamesWon, 1, reason: 'A won the sudden death (180 vs 3)');
    expect(b.gamesWon, 0);
    for (final sp in [a, b]) {
      expect(sp.gamesPlayed, 1);
      final x01 = sp.modeStats['x01']!;
      expect(x01.get('bestCheckout'), 40,
          reason: 'checkout 999 must never be persisted');
      expect(x01.get('totalTurns'), 4,
          reason: 'only real turns count — the sudden-death turn must not');
      expect(x01.get('totalTurnScore'), 501,
          reason: '180+177+104+40; SD points (180/3) must not leak in');
    }
  });
}
