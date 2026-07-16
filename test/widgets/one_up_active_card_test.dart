import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)));

DossedartOneUpActiveCard _card({
  OneUpCardMode mode = OneUpCardMode.normal,
  int? target = 87,
  int turnTotal = 42,
  bool lastLife = false,
  bool isRoundFree = false,
  String variantChip = 'BEAT THE LAST',
}) =>
    DossedartOneUpActiveCard(
      playerName: 'Jonas', accentColor: DossedartTokens.cyan,
      lives: 3, maxLives: 3, target: target, turnTotal: turnTotal,
      currentDartIndex: 1, cardMode: mode, lastLife: lastLife,
      variantChip: variantChip, isRoundFree: isRoundFree,
      opponents: const [
        OneUpOpponentEntry(name: 'Kari', accent: DossedartTokens.magenta,
            lives: 2, maxLives: 3, eliminated: false),
        OneUpOpponentEntry(name: 'Per', accent: DossedartTokens.green,
            lives: 0, maxLives: 3, eliminated: true),
      ],
    );

void main() {
  testWidgets('normal state shows BEAT target and NEED line (no +1)', (t) async {
    await t.pumpWidget(_wrap(_card()));
    expect(find.text('BEAT'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.textContaining('NEED 45 MORE'), findsOneWidget); // 87−42, tie counts
  });

  testWidgets('free state shows SET THE TARGET', (t) async {
    await t.pumpWidget(_wrap(_card(mode: OneUpCardMode.free, target: null)));
    expect(find.textContaining('SET THE'), findsOneWidget);
    expect(find.textContaining('FREE THROW'), findsOneWidget);
  });

  testWidgets('BEST round free state uses round wording', (t) async {
    await t.pumpWidget(_wrap(_card(
        mode: OneUpCardMode.free, target: null, isRoundFree: true,
        variantChip: 'SURVIVOR · R3')));
    expect(find.textContaining('NEW ROUND'), findsOneWidget);
    expect(find.textContaining('ROUND TARGET'), findsOneWidget);
  });

  testWidgets('safe state (tie included)', (t) async {
    await t.pumpWidget(_wrap(_card(mode: OneUpCardMode.safe, turnTotal: 87)));
    expect(find.textContaining('SAFE'), findsOneWidget);
    expect(find.textContaining('NEW TARGET ·'), findsOneWidget); // primary block
    expect(find.textContaining('PAD THE NEW TARGET'), findsOneWidget); // status line
  });

  testWidgets('cant-beat state', (t) async {
    await t.pumpWidget(_wrap(_card(
        mode: OneUpCardMode.cantBeat, target: 170, turnTotal: 10)));
    expect(find.textContaining("CAN'T BEAT"), findsOneWidget);
    expect(find.textContaining('LIFE AT RISK'), findsOneWidget);
  });

  testWidgets('last life shows FAIL = ELIMINATED (not MISS)', (t) async {
    await t.pumpWidget(_wrap(_card(lastLife: true)));
    expect(find.textContaining('LAST'), findsWidgets);
    expect(find.textContaining('FAIL = ELIMINATED'), findsOneWidget);
    expect(find.textContaining('MISS = ELIMINATED'), findsNothing);
  });

  testWidgets('eliminated opponent shows OUT', (t) async {
    await t.pumpWidget(_wrap(_card()));
    expect(find.text('OUT'), findsOneWidget);
  });
}
