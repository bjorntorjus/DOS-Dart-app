import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Stack(children: [child]),
        ),
      );

  group('BullChoiceDialog', () {
    testWidgets(
        'magnitude 3 renders DOUBLE BULL title + +-3 panels; taps fire the right callback only',
        (tester) async {
      var ignited = false;
      var calmed = false;
      await tester.pumpWidget(wrap(BullChoiceDialog(
        magnitude: 3,
        onIgnite: () => ignited = true,
        onCalm: () => calmed = true,
      )));

      expect(find.text('DOUBLE BULL · 50'), findsOneWidget);
      expect(find.text('▲ +3'), findsOneWidget);
      expect(find.text('▼ −3'), findsOneWidget);

      await tester.tap(find.text('▲ +3'));
      await tester.pump();
      expect(ignited, isTrue);
      expect(calmed, isFalse);

      await tester.tap(find.text('▼ −3'));
      await tester.pump();
      expect(calmed, isTrue);
    });

    testWidgets('magnitude 1 (single bull) renders BULL · 25 and +-1 panels',
        (tester) async {
      await tester.pumpWidget(wrap(BullChoiceDialog(
        magnitude: 1,
        onIgnite: () {},
        onCalm: () {},
      )));

      expect(find.text('BULL · 25'), findsOneWidget);
      expect(find.text('▲ +1'), findsOneWidget);
      expect(find.text('▼ −1'), findsOneWidget);
    });
  });

  group('WildcardDialog', () {
    testWidgets('renders icon, title and children', (tester) async {
      await tester.pumpWidget(wrap(WildcardDialog(
        accent: DossedartTokens.green,
        icon: '🃏',
        title: 'JOKER!',
        children: const [Text('HIDDEN NUMBER 14 DETONATES')],
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('🃏'), findsOneWidget);
      expect(find.text('JOKER!'), findsOneWidget);
      expect(find.text('HIDDEN NUMBER 14 DETONATES'), findsOneWidget);
    });

    testWidgets(
        'spin=false: no running AnimationController leak after 2s (no exceptions)',
        (tester) async {
      await tester.pumpWidget(wrap(WildcardDialog(
        accent: DossedartTokens.purple,
        icon: '⬛',
        title: 'ONLY EVENS',
        children: const [],
      )));

      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'spin=true: spinning icon animates and disposes cleanly on unmount',
        (tester) async {
      await tester.pumpWidget(wrap(WildcardDialog(
        accent: DossedartTokens.cyan,
        icon: '⟲',
        title: 'REWIND',
        spin: true,
        children: const [],
      )));

      expect(find.text('⟲'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));

      // Unmount mid-spin — the AnimationController must dispose cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('WildcardOverlay', () {
    testWidgets('onTap fires when the scrim is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(WildcardOverlay(
        tint: DossedartTokens.yellow,
        onTap: () => tapped = true,
        child: const Text('MOMENT'),
      )));

      // Tap a corner well away from the centred child.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
        'onTap null: no GestureDetector is added, so the child keeps its own taps',
        (tester) async {
      var childTapped = false;
      await tester.pumpWidget(wrap(WildcardOverlay(
        tint: DossedartTokens.yellow,
        child: GestureDetector(
          onTap: () => childTapped = true,
          child: const SizedBox(
            width: 100,
            height: 40,
            child: Text('CONTINUE'),
          ),
        ),
      )));

      // Only the child's own GestureDetector should exist — WildcardOverlay
      // must not wrap the scrim in one when onTap is null.
      expect(find.byType(GestureDetector), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(childTapped, isTrue);
    });
  });
}
