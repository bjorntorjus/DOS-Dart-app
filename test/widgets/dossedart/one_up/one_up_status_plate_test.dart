import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/one_up_status_plate.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/dossedart_one_up_active_card.dart'
    show OneUpCardMode;
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: Column(children: [child])));

  OneUpStatusPlate plate(OneUpCardMode mode,
          {int? target = 118,
          int turnTotal = 71,
          int darts = 2,
          bool survivor = false,
          String? hit}) =>
      OneUpStatusPlate(
          mode: mode,
          target: target,
          turnTotal: turnTotal,
          dartsThrown: darts,
          survivor: survivor,
          hitSuggestion: hit);

  testWidgets('need mode: NEED n MORE + hit suggestion', (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, hit: 'T16 +')));
    expect(find.text('NEED 47 MORE'), findsOneWidget);
    expect(find.text('T16 +'), findsOneWidget);
  });

  testWidgets('need mode without suggestion: darts-left fallback',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, darts: 2)));
    expect(find.text('· 1 DART LEFT'), findsOneWidget);
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, darts: 1)));
    expect(find.text('· 2 DARTS LEFT'), findsOneWidget);
  });

  testWidgets('safe mode: SAFE ✓ with NEW TARGET / ROUND SURVIVED',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.safe, turnTotal: 92)));
    expect(find.text('SAFE ✓'), findsOneWidget);
    expect(find.text('NEW TARGET 92'), findsOneWidget);
    await tester
        .pumpWidget(host(plate(OneUpCardMode.safe, survivor: true)));
    expect(find.text('ROUND SURVIVED'), findsOneWidget);
  });

  testWidgets('cantBeat mode: MAX n LEFT from remaining darts',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.cantBeat, darts: 2)));
    expect(find.text("CAN'T BEAT"), findsOneWidget);
    expect(find.text('· MAX 60 LEFT'), findsOneWidget);
  });

  testWidgets('free mode: variant-specific hint line', (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.free, target: null)));
    expect(find.text('▸ YOUR 3-DART TOTAL SETS THE BAR'), findsOneWidget);
    await tester.pumpWidget(
        host(plate(OneUpCardMode.free, target: null, survivor: true)));
    expect(
        find.text('▸ YOUR 3-DART TOTAL IS THE ROUND TARGET'), findsOneWidget);
  });

  testWidgets('all modes share the same minimum height (rule 2)',
      (tester) async {
    final heights = <double>[];
    for (final m in [
      OneUpCardMode.free,
      OneUpCardMode.normal,
      OneUpCardMode.safe,
      OneUpCardMode.cantBeat,
    ]) {
      await tester
          .pumpWidget(host(plate(m, target: m == OneUpCardMode.free ? null : 118)));
      heights.add(tester.getSize(find.byType(OneUpStatusPlate)).height);
    }
    expect(heights.toSet().length, 1,
        reason: 'plate height must not vary by state: $heights');
  });
}
