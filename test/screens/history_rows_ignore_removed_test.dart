import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_stats_screen.dart';
import 'package:dart_scoring/screens/stats_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Spec 2026-08-26: a player removed mid-game stays in the history entry's
/// `players` list (seat ↔ throw alignment) but is flagged `removed`, and no
/// consumer that RANKS or CREDITS may read them. Both history lists used to
/// sort `entry.players`, which floats a Family-B removed seat — placement 0 —
/// straight to the top and paints it the winner.
void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  /// One finished game: seat 0 walked out mid-game (Family B → placement 0),
  /// seat 1 actually won, seat 2 came second.
  final entry = GameHistoryEntry(
    id: '1',
    gameMode: 'cricket',
    date: DateTime(2026, 8, 26),
    gameConfig: 'Standard',
    players: [
      GameHistoryPlayer(
          name: 'Ghost', placement: 0, stats: const {}, removed: true),
      GameHistoryPlayer(name: 'Winna', placement: 1, stats: const {}),
      GameHistoryPlayer(name: 'Runner', placement: 2, stats: const {}),
    ],
  );

  void seed() {
    SharedPreferences.setMockInitialValues({
      'saved_players': jsonEncode([
        SavedPlayer(id: '1', name: 'Winna', createdAt: DateTime(2020))
            .toJson(),
      ]),
      'game_history_v1': GameHistoryEntry.encodeList([entry]),
    });
  }

  /// Every rendered (on-stage) Text string, in tree order.
  List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();

  testWidgets('DOSSEDART MATCHES row ranks active players only',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('Ghost'), findsNothing,
        reason: 'a player who left the game is not part of its ranking');

    final rendered = texts(tester);
    expect(rendered.contains('Winna'), isTrue);
    expect(rendered.indexOf('Winna') < rendered.indexOf('Runner'), isTrue,
        reason: 'the real winner heads the list');
    expect(rendered.contains('0'), isFalse,
        reason: "the removed seat's placement 0 is never rendered as a rank");
  });

  testWidgets('classic History card ranks active players only', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // The collapsed card's title is the podium row: `sorted.take(3)`.
    expect(find.textContaining('Ghost'), findsNothing,
        reason: 'a player who left the game is not part of its ranking');
    expect(find.text('#0 Ghost'), findsNothing);
    expect(find.text('🥇 Winna'), findsOneWidget,
        reason: 'the real winner takes the gold medal');
    expect(find.text('🥈 Runner'), findsOneWidget);

    final rendered = texts(tester);
    expect(rendered.indexOf('🥇 Winna') < rendered.indexOf('🥈 Runner'),
        isTrue);
  });
}
