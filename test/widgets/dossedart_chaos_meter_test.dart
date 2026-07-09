import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_chaos_meter.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DossedartChaosMeter', () {
    testWidgets('level 3: level number, /10, BUBBLING label, 15% chance',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(level: 3)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('/10'), findsOneWidget);
      expect(find.text('BUBBLING'), findsOneWidget);
      expect(find.text('events @ 15%'), findsOneWidget);
    });

    testWidgets('level 10: TOTAL CHAOS label + tuned event chance footer',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(level: 10)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('10'), findsOneWidget);
      expect(find.text('TOTAL CHAOS'), findsOneWidget);
      expect(find.text('events @ 80% · 2 JOKERS'), findsOneWidget);
      expect(find.text('EVENTS EVERY TURN'), findsNothing);
    });

    testWidgets('level 0: DORMANT label, 0% chance', (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(level: 0)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('DORMANT'), findsOneWidget);
      expect(find.text('events @ 0%'), findsOneWidget);
    });

    testWidgets('max level pulse respects disableAnimations', (tester) async {
      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const DossedartChaosMeter(level: 9),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Rendered fine, and no pending animation ticks under reduced motion.
      expect(find.text('9'), findsOneWidget);
      expect(find.text('WILD'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposes cleanly when removed from the tree',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(level: 10)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('dossedartAccent', () {
    test('cycles through the five-colour accent list', () {
      expect(dossedartAccent(0), DossedartTokens.cyan);
      expect(dossedartAccent(1), DossedartTokens.magenta);
      expect(dossedartAccent(2), DossedartTokens.green);
      expect(dossedartAccent(3), DossedartTokens.purple);
      expect(dossedartAccent(4), DossedartTokens.orange);
    });

    test('wraps around after the fifth accent', () {
      expect(dossedartAccent(5), DossedartTokens.cyan);
      expect(dossedartAccent(9), DossedartTokens.orange);
    });
  });
}
