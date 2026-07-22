import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/gotcha/dossedart_gotcha_active_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  // The card is taller than the default 800x600 test surface once the
  // climb bar and both helper bars are always rendered — use a
  // tablet-portrait surface like the rest of the DOSSEDART cockpit tests.
  void useTabletSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('default state: both helpers dim with empty texts',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(const DossedartGotchaActiveCard(
      playerName: 'Jonas',
      avatarPath: null,
      accentColor: DossedartTokens.cyan,
      total: 60,
      target: 301,
      currentDartIndex: 1,
      lastTurnLabel: 'S20 · S20 · S20',
      lastTurnSum: 60,
      checkoutRoute: null,
      kills: [],
      opponents: [
        GotchaOpponentTick(initial: 'K', total: 78, danger: false),
        GotchaOpponentTick(initial: 'M', total: 0, danger: false),
      ],
    )));
    expect(find.text('NO ROUTE · > 3 DARTS'), findsOneWidget);
    expect(find.text('NONE WITHIN 1 DART'), findsOneWidget);
    expect(find.textContaining('TO GO'), findsOneWidget);
    expect(find.text('60'), findsWidgets); // big score
  });

  testWidgets('active helpers: route text, WIN ▶, kill chips',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(const DossedartGotchaActiveCard(
      playerName: 'Jonas',
      avatarPath: null,
      accentColor: DossedartTokens.cyan,
      total: 261,
      target: 301,
      currentDartIndex: 2,
      lastTurnLabel: 'T19 · S20 · D14',
      lastTurnSum: 105,
      checkoutRoute: 'D20',
      kills: [GotchaKillChip(dart: 'S12', name: 'KARI')],
      opponents: [GotchaOpponentTick(initial: 'K', total: 273, danger: true)],
    )));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('D20'), findsOneWidget);
    expect(find.text('WIN ▶'), findsOneWidget);
    expect(find.text('S12'), findsOneWidget);
    expect(find.text('→ KARI'), findsOneWidget);
    expect(find.text('NO ROUTE · > 3 DARTS'), findsNothing);
  });

  testWidgets(
      'climb bar tick shows skull for danger opponent, initial otherwise',
      (tester) async {
    useTabletSurface(tester);
    await tester.pumpWidget(wrap(const DossedartGotchaActiveCard(
      playerName: 'Jonas',
      avatarPath: null,
      accentColor: DossedartTokens.cyan,
      total: 150,
      target: 301,
      currentDartIndex: 0,
      lastTurnLabel: null,
      lastTurnSum: null,
      checkoutRoute: null,
      kills: [],
      opponents: [
        GotchaOpponentTick(initial: 'K', total: 90, danger: true),
        GotchaOpponentTick(initial: 'Mia', total: 40, danger: false),
      ],
    )));
    await tester.pump(const Duration(milliseconds: 100));
    // The KILL helper's tag icon is also a '💀' glyph (VT323 is not its
    // font), so scope the search to the climb-bar tick label specifically.
    Finder tickLabel(String data) => find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == data &&
              widget.style?.fontFamily == 'VT323' &&
              widget.style?.fontSize == 12,
        );
    expect(tickLabel('💀'), findsOneWidget);
    expect(tickLabel('M'), findsOneWidget);
    expect(tickLabel('K'), findsNothing);
  });
}
