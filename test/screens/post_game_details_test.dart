import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/dossedart/game_detail_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Post-game v2 Task 5: the "▶ DETAILS" button opens the KAMPDETALJER
/// drill-down (GameDetailScreen) backed by an EPHEMERAL GameHistoryEntry
/// (`GameResult.detailEntry`) — no history entry is persisted yet while the
/// post-game screen shows (stats recording is deferred until Finish).
void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  GameHistoryEntry entry() => GameHistoryEntry(
        id: '123',
        gameMode: 'x01',
        date: DateTime(2026, 7, 22),
        gameConfig: '501 · Double-Out',
        players: [
          GameHistoryPlayer(name: 'A', placement: 1, stats: const {'darts': 9}),
          GameHistoryPlayer(name: 'B', placement: 2, stats: const {'darts': 12}),
        ],
      );

  GameResult resultWith({GameHistoryEntry? detailEntry}) => GameResult(
        gameMode: 'x01',
        results: [
          PlayerResult(name: 'A', placement: 1, stats: const {'darts': 9}),
          PlayerResult(name: 'B', placement: 2, stats: const {'darts': 12}),
        ],
        detailEntry: detailEntry,
      );

  testWidgets('DETAILS button is visible when detailEntry is set',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PostGameScreen(result: resultWith(detailEntry: entry()))),
    );
    await tester.pumpAndSettle();

    expect(find.text('▶ DETAILS'), findsOneWidget);
  });

  testWidgets('DETAILS is rendered but inert when detailEntry is null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PostGameScreen(result: resultWith(detailEntry: null))),
    );
    await tester.pumpAndSettle();

    // Dimmed, not removed (DOSSEDART round 2026-08-10) so the primary action
    // never moves between two games. Tapping it must go nowhere.
    expect(find.text('▶ DETAILS'), findsOneWidget);
    await tester.tap(find.text('▶ DETAILS'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(GameDetailScreen), findsNothing);
  });

  testWidgets('DETAILS is offered whenever a detailEntry exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PostGameScreen(result: resultWith(detailEntry: entry()))),
    );
    await tester.pumpAndSettle();

    expect(find.text('▶ DETAILS'), findsOneWidget);
    await tester.tap(find.text('▶ DETAILS'));
    await tester.pumpAndSettle();
    expect(find.byType(GameDetailScreen), findsOneWidget);
  });

  testWidgets('tapping DETAILS pushes GameDetailScreen with the ephemeral entry',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PostGameScreen(result: resultWith(detailEntry: entry()))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ DETAILS'));
    await tester.pumpAndSettle();

    expect(find.byType(GameDetailScreen), findsOneWidget);
    expect(find.text('MATCH DETAILS'), findsOneWidget);
  });
}
