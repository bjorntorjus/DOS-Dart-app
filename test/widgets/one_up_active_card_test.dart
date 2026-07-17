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

  testWidgets('survivor round free state uses round wording', (t) async {
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

  testWidgets('round-out opponent shows ROUND OUT, no skull, distinct from OUT',
      (t) async {
    await t.pumpWidget(_wrap(DossedartOneUpActiveCard(
      playerName: 'Jonas', accentColor: DossedartTokens.cyan,
      lives: 3, maxLives: 3, target: 87, turnTotal: 42,
      currentDartIndex: 1, cardMode: OneUpCardMode.normal, lastLife: false,
      variantChip: 'SURVIVOR · R3', isRoundFree: false,
      opponents: const [
        OneUpOpponentEntry(name: 'Kari', accent: DossedartTokens.magenta,
            lives: 2, maxLives: 3, eliminated: false, outOfRound: true),
        OneUpOpponentEntry(name: 'Per', accent: DossedartTokens.green,
            lives: 0, maxLives: 3, eliminated: true),
      ],
    )));
    expect(find.text('ROUND OUT'), findsOneWidget);
    expect(find.text('💀'), findsOneWidget); // only Per (eliminated)
    expect(find.text('OUT'), findsOneWidget); // only Per's label
  });

  testWidgets('card stays inside the compact height budget', (t) async {
    // Tablet-QA 2026-07-17: the card crowded the dartboard and clipped the
    // top "20" segment. Pins the compressed layout — the normal state (BEAT
    // + status line + opponents strip) measured 331px before the fix; the
    // ~20% compression must keep it at or under 265px at tablet width so
    // the bottom-anchored board keeps its full square.
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 800, child: _card())))));
    final height = t.getSize(find.byType(DossedartOneUpActiveCard)).height;
    expect(height, lessThanOrEqualTo(265));
  });

  testWidgets('eliminated wins over outOfRound when both flags are set',
      (t) async {
    // The engine sets BOTH flags on every survivor elimination (the fail
    // joins _outOfRound before the lives check) — this pins the precedence.
    await t.pumpWidget(_wrap(DossedartOneUpActiveCard(
      playerName: 'Jonas', accentColor: DossedartTokens.cyan,
      lives: 3, maxLives: 3, target: 87, turnTotal: 42,
      currentDartIndex: 1, cardMode: OneUpCardMode.normal, lastLife: false,
      variantChip: 'SURVIVOR · R3', isRoundFree: false,
      opponents: const [
        OneUpOpponentEntry(name: 'Per', accent: DossedartTokens.green,
            lives: 0, maxLives: 3, eliminated: true, outOfRound: true),
      ],
    )));
    expect(find.text('💀'), findsOneWidget);
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('ROUND OUT'), findsNothing);
  });
}
