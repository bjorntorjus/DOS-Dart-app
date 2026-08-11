import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/widgets/dossedart/stats/seasons_tab.dart';

SeasonPlayerRow row(String name, double rating, int games,
        {int wins = 0, int thrown = 0, int hit = 0, int withThrows = 0}) =>
    SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: thrown,
      dartsHit: hit,
      gamesWithThrows: withThrows,
    );

Future<void> pump(WidgetTester tester, List<SeasonRecord> seasons) async {
  tester.view.physicalSize = const Size(820, 1180);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SeasonsTab(seasons: seasons))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists seasons newest first with their winner', (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20), row('Bo', 1150, 20)]),
      SeasonRecord(
          number: 2,
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 9, 30),
          rows: [row('Bo', 1280, 20), row('Ada', 1160, 20)]),
    ]);

    expect(find.textContaining('SEASON 2'), findsOneWidget);
    expect(find.textContaining('SEASON 1'), findsOneWidget);
    final s2 = tester.getTopLeft(find.textContaining('SEASON 2')).dy;
    final s1 = tester.getTopLeft(find.textContaining('SEASON 1')).dy;
    expect(s2, lessThan(s1), reason: 'newest first');
  });

  testWidgets('the all-time record is not called season 0', (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 0,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 8, 11),
          rows: [row('Ada', 1276, 71)]),
    ]);

    expect(find.textContaining('ALL-TIME'), findsOneWidget);
    expect(find.textContaining('SEASON 0'), findsNothing);
  });

  testWidgets('unqualified players sit below the table with their count',
      (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20), row('Guest', 1400, 4)]),
    ]);

    expect(find.textContaining('UNQUALIFIED'), findsOneWidget);
    expect(find.textContaining('4/10'), findsOneWidget);
    expect(find.textContaining('GUEST'), findsOneWidget);
  });

  testWidgets('an unknown hit rate renders as a dash, not zero',
      (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20, wins: 10)]),
    ]);

    expect(find.text('0%'), findsNothing,
        reason: 'no throws stored means unknown, not a 0 % hit rate');
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('a known hit rate is shown', (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [
            row('Ada', 1290, 20, wins: 10, thrown: 200, hit: 150, withThrows: 20)
          ]),
    ]);

    expect(find.text('75%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget, reason: '10 wins of 20 games');
  });

  testWidgets('no seasons yet shows an empty state, not a crash',
      (tester) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('NO SEASONS'), findsOneWidget);
  });
}
