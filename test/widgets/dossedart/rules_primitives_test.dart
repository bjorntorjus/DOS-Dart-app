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
}
