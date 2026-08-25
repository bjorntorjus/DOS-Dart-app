import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/widgets/dossedart/stats/seasons_tab.dart';

SeasonPlayerRow row(String name, double rating, {int games = 1, int wins = 0}) =>
    SeasonPlayerRow(
        playerId: name,
        name: name,
        rating: rating,
        games: games,
        wins: wins,
        dartsThrown: 0,
        dartsHit: 0,
        gamesWithThrows: 0);

void main() {
  final season = SeasonRecord(
    number: 2,
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 9, 30),
    rows: [row('Ada', 1300, games: 12, wins: 8)],
  );
  final closed = EventRecord(
    id: 'evt_1',
    name: 'Jobbfest 2026',
    start: DateTime(2026, 8, 25, 19),
    end: DateTime(2026, 8, 25, 23),
    savedRatings: const {},
    rows: [row('Bo', 1264, games: 3, wins: 3), row('Ada', 1136, games: 3)],
  );

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
    await t.pumpAndSettle();
  }

  testWidgets('closed event card renders above the season, everyone ranked',
      (tester) async {
    await pump(tester, SeasonsTab(seasons: [season], events: [closed]));
    expect(find.text('EVENT · JOBBFEST 2026'), findsOneWidget);
    expect(find.text('SEASON 2'), findsOneWidget);
    expect(find.textContaining('BO'), findsWidgets); // winner header + row
    // One-game players are ranked, never shown as UNQUALIFIED.
    expect(find.text('UNQUALIFIED'), findsNothing);
    final eventY = tester.getTopLeft(find.text('EVENT · JOBBFEST 2026')).dy;
    final seasonY = tester.getTopLeft(find.text('SEASON 2')).dy;
    expect(eventY, lessThan(seasonY));
  });

  testWidgets('live event card is labelled LIVE and sits on top',
      (tester) async {
    final open = EventRecord(
        id: closed.id,
        name: closed.name,
        start: closed.start,
        savedRatings: const {},
        rows: [row('Bo', 1232, games: 1, wins: 1)]);
    await pump(tester, SeasonsTab(seasons: [season], liveEvent: open));
    expect(find.text('EVENT · JOBBFEST 2026 · LIVE'), findsOneWidget);
  });

  testWidgets('no events → tab looks as before', (tester) async {
    await pump(tester, SeasonsTab(seasons: [season]));
    expect(find.textContaining('EVENT ·'), findsNothing);
    expect(find.text('SEASON 2'), findsOneWidget);
  });
}
