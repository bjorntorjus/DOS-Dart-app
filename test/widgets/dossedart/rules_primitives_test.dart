import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/setup/rules_primitives.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  group('ArcadeChipRow', () {
    testWidgets('renders label and all option labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT RULE',
              value: 'none',
              options: const [
                ('FREE', 'none'),
                ('DBL', 'double'),
                ('MSTR', 'master'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('OUT RULE'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('DBL'), findsOneWidget);
      expect(find.text('MSTR'), findsOneWidget);
    });

    testWidgets('tap on option calls onChanged with that value', (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT',
              value: 'none',
              options: const [('FREE', 'none'), ('DBL', 'double')],
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('DBL'));
      expect(captured, 'double');
    });

    testWidgets('selected chip has yellow background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT',
              value: 'double',
              options: const [('FREE', 'none'), ('DBL', 'double')],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      // Find the container that wraps the "DBL" Text and check its color.
      final dblFinder = find.ancestor(
        of: find.text('DBL'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(dblFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, DossedartTokens.yellow);
    });
  });

  group('ArcadeToggleRow', () {
    testWidgets('renders each toggle label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('NO-BUST', false, DossedartTokens.magenta, (_) {}),
              ('HCAP', true, DossedartTokens.cyan, (_) {}),
            ]),
          ),
        ),
      );
      expect(find.textContaining('NO-BUST'), findsOneWidget);
      expect(find.textContaining('HCAP'), findsOneWidget);
    });

    testWidgets('tap toggles state via callback', (tester) async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('NO-BUST', false, DossedartTokens.magenta, (v) => captured = v),
            ]),
          ),
        ),
      );
      await tester.tap(find.textContaining('NO-BUST'));
      expect(captured, true);
    });

    testWidgets('ON toggle shows filled indicator, OFF shows empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('A', true, DossedartTokens.magenta, (_) {}),
              ('B', false, DossedartTokens.magenta, (_) {}),
            ]),
          ),
        ),
      );
      // "A" is on, indicator is '●'; "B" is off, indicator is '○'.
      expect(find.textContaining('●'), findsOneWidget);
      expect(find.textContaining('○'), findsOneWidget);
    });
  });

  group('ArcadeStepper', () {
    testWidgets('renders label and current value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'ROUNDS',
              value: 9,
              min: 5,
              max: 20,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('ROUNDS'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('+ increments value via onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 9, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('+'));
      expect(captured, 10);
    });

    testWidgets('- decrements value via onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 9, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('-'));
      expect(captured, 8);
    });

    testWidgets('+ at max does not call onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 20, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('+'));
      expect(captured, isNull);
    });

    testWidgets('- at min does not call onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 5, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('-'));
      expect(captured, isNull);
    });
  });
}
