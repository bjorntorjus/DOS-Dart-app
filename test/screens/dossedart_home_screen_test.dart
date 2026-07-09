import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_home_screen.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Widget tests for the DOSSEDART home's "OR PICK A LEVEL" 3×3 grid: 5 live
/// modes, two fresh tiles (Gotcha + WILDCARD, both with a NEW ribbon), and 2
/// hardcoded coming-soon placeholders (1UP / Golf).
void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders all 9 grid tiles with their emoji and labels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();

    // One tile per emoji -> exactly 9 tiles in the grid.
    const emojis = ['🎯', '🕐', '🔪', '✂️', '🐉', '💀', '❤️', '⛳', '🃏'];
    for (final e in emojis) {
      expect(find.text(e), findsOneWidget, reason: 'tile emoji "$e" missing');
    }

    expect(find.text('GOTCHA'), findsOneWidget);
    expect(find.text('WILDCARD'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2),
        reason: 'NEW ribbon on both Gotcha and WILDCARD');
    expect(find.text('1UP'), findsOneWidget);
    expect(find.text('GOLF'), findsOneWidget);
    expect(find.text('MORE SOON'), findsNothing);
    expect(find.text('✨'), findsNothing);
  });

  testWidgets('the fresh tiles fill their grid cell like their live siblings',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();

    // Regression (QA 2026-07-08): the NEW-ribbon Stack used StackFit.loose,
    // which loosened the Expanded cell's tight width so the tile Container
    // shrink-wrapped to its text (~1/3 of the intended width).
    Size tileSize(String emoji) {
      final container = find
          .ancestor(
            of: find.text(emoji),
            matching: find.byType(Container),
          )
          .first;
      return tester.getSize(container);
    }

    final shanghai = tileSize('🐉'); // live sibling in the same row
    final gotcha = tileSize('💀');
    final wildcard = tileSize('🃏');
    expect(gotcha.width, moreOrLessEquals(shanghai.width, epsilon: 1.0),
        reason: 'Gotcha tile must be as wide as its live siblings');
    expect(wildcard.width, moreOrLessEquals(shanghai.width, epsilon: 1.0),
        reason: 'WILDCARD tile must be as wide as its live siblings');
  });

  testWidgets(
      'fresh tiles use standard live chrome (phosphor border), not cyan',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();

    // QA decision 2026-07-09: the NEW ribbon is the only differentiator —
    // the tile Container itself must match the live phosphor chrome.
    for (final e in ['💀', '🃏']) {
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(e),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, DossedartTokens.phosphor,
          reason: 'fresh tile "$e" must use the standard phosphor border');
      expect(decoration.color, DossedartTokens.surface,
          reason: 'fresh tile "$e" must use the standard surface fill');
    }
  });

  testWidgets('coming-soon tiles are not tappable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();

    for (final e in ['❤️', '⛳']) {
      final tile = find.text(e);
      expect(tile, findsOneWidget);
      expect(
        find.ancestor(of: tile, matching: find.byType(InkWell)),
        findsNothing,
        reason: 'coming-soon tile "$e" must not have a tap handler',
      );
      expect(
        find.ancestor(of: tile, matching: find.byType(GestureDetector)),
        findsNothing,
        reason: 'coming-soon tile "$e" must not have a tap handler',
      );
    }
  });

  testWidgets('live and new tiles are tappable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();

    for (final e in ['🎯', '🕐', '🔪', '✂️', '🐉', '💀', '🃏']) {
      final tile = find.text(e);
      expect(tile, findsOneWidget);
      expect(
        find.ancestor(of: tile, matching: find.byType(InkWell)),
        findsWidgets,
        reason: 'tile "$e" must be tappable',
      );
    }
  });
}
