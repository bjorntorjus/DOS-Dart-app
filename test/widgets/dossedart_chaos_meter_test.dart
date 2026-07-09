import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_chaos_meter.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DossedartChaosMeter', () {
    testWidgets('level 3, round 2/10: compact strip shows CHAOS, level/10 '
        'and ROUND once — no heat cells, no events-% footer', (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(
        level: 3,
        round: 2,
        rounds: 10,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHAOS'), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('ROUND 2/10'), findsOneWidget);
      expect(find.textContaining('events @'), findsNothing);
      expect(find.text('BUBBLING'), findsNothing);
    });

    testWidgets('level 0, round 1/10: renders the dormant strip',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(
        level: 0,
        round: 1,
        rounds: 10,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('CHAOS'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);
      expect(find.text('ROUND 1/10'), findsOneWidget);
    });

    testWidgets('level 10 renders and pulses (danger glow ticking)',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(
        level: 10,
        round: 9,
        rounds: 10,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('ROUND 9/10'), findsOneWidget);
      // Max level runs a repeating pulse — a pending transient callback
      // means the AnimationController is actually ticking.
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('max level pulse respects disableAnimations', (tester) async {
      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const DossedartChaosMeter(level: 9, round: 5, rounds: 10),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Rendered fine, and no pending animation ticks under reduced motion.
      expect(find.text('9/10'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('disposes cleanly when removed from the tree',
        (tester) async {
      await tester.pumpWidget(wrap(const DossedartChaosMeter(
        level: 10,
        round: 3,
        rounds: 10,
      )));
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
