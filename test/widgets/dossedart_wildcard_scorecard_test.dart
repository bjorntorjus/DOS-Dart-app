import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  void useTabletSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  const openDirective = WcDirective(
    icon: '▶',
    color: DossedartTokens.cyan,
    head: 'OPEN THROW · SCORE MAX',
    sub: 'No restriction this turn — pile on points',
  );

  testWidgets(
      'open-throw state: head, DART 2/3 with one thrown dart, LEADER, crown + dropdown',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(DossedartWildcardScorecard(
      playerName: 'Jonas',
      handle: 'JON',
      accent: DossedartTokens.cyan,
      round: 2,
      rounds: 8,
      dartLabels: const ['20', null, null],
      turnPoints: 60,
      gameTotal: 140,
      rank: 1,
      toLead: 0,
      directive: openDirective,
      standings: const [
        WcStandingEntry(
          name: 'Jonas',
          accent: DossedartTokens.cyan,
          total: 140,
          isActive: true,
        ),
        WcStandingEntry(
          name: 'Kari',
          accent: DossedartTokens.magenta,
          total: 90,
          isActive: false,
        ),
      ],
      modifierActive: false,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('OPEN THROW · SCORE MAX'), findsOneWidget);
    expect(find.text('DART 2/3'), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // thrown dart label
    expect(find.textContaining('LEADER'), findsOneWidget);
    expect(find.text('👑'), findsOneWidget);
    expect(find.text('▽'), findsOneWidget);
  });

  testWidgets('modifier state: purple-themed card + head text + miss slot',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(DossedartWildcardScorecard(
      playerName: 'Jonas',
      handle: 'JON',
      accent: DossedartTokens.cyan,
      round: 3,
      rounds: 8,
      dartLabels: const ['—', null, null],
      turnPoints: 0,
      gameTotal: 140,
      rank: 2,
      toLead: 15,
      directive: const WcDirective(
        icon: '🎲',
        color: DossedartTokens.purple,
        head: 'ONLY EVENS',
        sub: 'Odd numbers do not count this turn',
      ),
      standings: const [
        WcStandingEntry(
          name: 'Kari',
          accent: DossedartTokens.magenta,
          total: 155,
          isActive: false,
        ),
        WcStandingEntry(
          name: 'Jonas',
          accent: DossedartTokens.cyan,
          total: 140,
          isActive: true,
        ),
      ],
      modifierActive: true,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ONLY EVENS'), findsOneWidget);
    expect(find.text('—'), findsOneWidget); // miss slot

    final purpleBorderFound = tester.widgetList<Container>(find.byType(Container)).any(
      (c) {
        final decoration = c.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return border.top.color == DossedartTokens.purple;
      },
    );
    expect(purpleBorderFound, isTrue);
  });

  testWidgets('flags: +50 STEAL (good/green) and -50 ROBBED (bad/red) render',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(DossedartWildcardScorecard(
      playerName: 'Jonas',
      handle: 'JON',
      accent: DossedartTokens.cyan,
      round: 4,
      rounds: 8,
      dartLabels: const [null, null, null],
      turnPoints: 0,
      gameTotal: 140,
      rank: 1,
      toLead: 0,
      directive: openDirective,
      standings: const [
        WcStandingEntry(
          name: 'Jonas',
          accent: DossedartTokens.cyan,
          total: 140,
          isActive: true,
          flagText: '+50 STEAL',
          flagGood: true,
        ),
        WcStandingEntry(
          name: 'Kari',
          accent: DossedartTokens.magenta,
          total: 90,
          isActive: false,
          flagText: '-50 ROBBED',
          flagGood: false,
        ),
      ],
      modifierActive: false,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    final goodText = tester.widget<Text>(find.text('+50 STEAL'));
    expect(goodText.style?.color, DossedartTokens.green);

    final badText = tester.widget<Text>(find.text('-50 ROBBED'));
    expect(badText.style?.color, DossedartTokens.red);

    // Flags replace the crown/dropdown markers entirely.
    expect(find.text('👑'), findsNothing);
    expect(find.text('▽'), findsNothing);
  });
}
