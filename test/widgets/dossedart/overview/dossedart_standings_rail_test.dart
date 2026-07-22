import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/overview/dossedart_standings_rail.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: SizedBox(height: 160, child: Row(children: [child]))));

  List<DossedartRailEntry> entries({bool leader = true}) => [
        DossedartRailEntry(
            name: 'Jonas',
            accent: DossedartTokens.cyan,
            value: '60',
            isLeader: leader),
        DossedartRailEntry(
            name: 'Live',
            accent: DossedartTokens.green,
            value: '141',
            isActive: true),
        DossedartRailEntry(
            name: 'Alexander the boss bitch',
            accent: DossedartTokens.purple,
            value: '264'),
      ];

  test('midTruncate keeps start and end around a single ellipsis', () {
    expect(midTruncate('ALEXANDER THE BOSS BITCH', 16), 'ALEXANDER…BITCH');
    expect(midTruncate('ALEXANDER THE BOSS BITCH', 16).length,
        lessThanOrEqualTo(16));
    expect(midTruncate('KARI', 16), 'KARI'); // short names untouched
  });

  testWidgets('crown renders exactly once, on the unique leader',
      (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(),
        bottomLabel: 'TO WIN',
        bottomValue: '▲ 81')));
    expect(find.text('👑'), findsOneWidget);

    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(leader: false),
        bottomLabel: 'TO WIN',
        bottomValue: 'TIED')));
    expect(find.text('👑'), findsNothing);
  });

  testWidgets('bottom row shows label and value', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(),
        bottomLabel: 'TO WIN',
        bottomValue: '▲ 81')));
    expect(find.text('TO WIN'), findsOneWidget);
    expect(find.text('▲ 81'), findsOneWidget);
  });

  testWidgets('trailing widget replaces the value text', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
      entries: [
        DossedartRailEntry(
            name: 'Mia',
            accent: DossedartTokens.orange,
            trailing: const Text('ROUND OUT', key: Key('tag'))),
      ],
      bottomLabel: 'TARGET',
      bottomValue: '—',
      bottomDim: true,
    )));
    expect(find.byKey(const Key('tag')), findsOneWidget);
    expect(find.text(''), findsNothing); // no empty value Text rendered
  });

  testWidgets('dimmed entry lowers rank/dot/name opacity', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
      entries: [
        DossedartRailEntry(
            name: 'Per', accent: DossedartTokens.green, value: '3', dimmed: true),
      ],
      bottomLabel: 'TARGET',
      bottomValue: 'BY TOR',
    )));
    final nameText = tester.widget<Text>(find.text('PER'));
    expect((nameText.style?.color?.a ?? 1.0), lessThan(0.5),
        reason: 'dimmed row renders the name at low alpha');
  });
}
