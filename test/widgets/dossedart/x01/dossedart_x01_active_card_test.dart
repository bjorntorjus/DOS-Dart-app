import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_active_card.dart';

void main() {
  Widget harness({
    String name = 'MIA',
    int remaining = 170,
    int currentDartIndex = 2,
    String? lastTurn = 'T20 · S20 · S20',
    int? lastTurnSum = 80,
    String? checkoutTip,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DossedartX01ActiveCard(
          playerName: name,
          avatarPath: null,
          accentColor: const Color(0xFFFF00AA),
          remaining: remaining,
          currentDartIndex: currentDartIndex,
          lastTurnLabel: lastTurn,
          lastTurnSum: lastTurnSum,
          checkoutTip: checkoutTip,
        ),
      ),
    );
  }

  testWidgets('renders name, remaining, last turn', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('170'), findsOneWidget);
    expect(find.text('T20 · S20 · S20'), findsOneWidget);
    expect(find.text('= 80'), findsOneWidget);
  });

  testWidgets('hides checkout-tip when null', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.textContaining('▶'), findsNothing);
  });

  testWidgets('shows checkout-tip when provided', (tester) async {
    await tester.pumpWidget(harness(checkoutTip: 'T20 › S16 › D-BULL'));
    expect(find.text('▶ T20 › S16 › D-BULL'), findsOneWidget);
  });

  testWidgets('long name does not overflow (no exception)',
      (tester) async {
    await tester.pumpWidget(harness(name: 'CHRISTOPHER ALEXANDER VON LONGNAME'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short name (≤6 chars) renders at 18px font', (tester) async {
    await tester.pumpWidget(harness(name: 'MIA'));
    final text = tester.widget<Text>(find.text('MIA'));
    expect(text.style!.fontSize, 18);
  });

  testWidgets('medium name (7-10 chars) renders at 15px font',
      (tester) async {
    await tester.pumpWidget(harness(name: 'BJORN T.'));
    final text = tester.widget<Text>(find.text('BJORN T.'));
    expect(text.style!.fontSize, 15);
  });

  testWidgets('long name (11-16 chars) renders at 12px font',
      (tester) async {
    await tester.pumpWidget(harness(name: 'BJORN TORJUS'));
    final text = tester.widget<Text>(find.text('BJORN TORJUS'));
    expect(text.style!.fontSize, 12);
  });

  testWidgets('uses solid surface background (no gradient)', (tester) async {
    await tester.pumpWidget(harness());
    // Outer card is the first Container in the widget tree with a magenta
    // border. Look it up via the BoxDecoration and assert: solid color set,
    // no gradient.
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(DossedartX01ActiveCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final deco = container.decoration as BoxDecoration;
    expect(deco.gradient, isNull,
        reason: 'active card should use a solid bg, not a gradient');
    expect(deco.color, isNotNull,
        reason: 'active card should set a solid background color');
  });
}
