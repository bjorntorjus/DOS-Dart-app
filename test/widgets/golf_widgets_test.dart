import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_input_cells.dart';
import 'package:dart_scoring/widgets/dossedart/golf/dossedart_golf_active_card.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_scorecard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('input renders S/D/T cells with terms for a normal hole',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: GolfInputCells(targetNumber: 7, onHit: (m) => tapped = m)),
    ));
    expect(find.text('S7'), findsOneWidget);
    expect(find.text('D7'), findsOneWidget);
    expect(find.text('T7'), findsOneWidget);
    expect(find.text('ACE'), findsOneWidget);
    await tester.tap(find.text('T7'));
    expect(tapped, 3);
  });

  testWidgets('input renders two cells for Bull — no triple', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GolfInputCells(targetNumber: 25, onHit: (_) {})),
    ));
    expect(find.text('BULL'), findsOneWidget);
    expect(find.text('D-BULL'), findsOneWidget);
    expect(find.text('T25'), findsNothing);
    expect(find.text('PAR'), findsOneWidget);
    expect(find.text('BIRDIE'), findsOneWidget);
    expect(find.textContaining('MISS'), findsOneWidget);
  });

  testWidgets('active card shows status line, vs par and hole result term',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartGolfActiveCard(
          playerName: 'BJØRNAR', avatarPath: null, accentColor: Colors.cyan,
          holeLabel: 'HOLE 7 · PAR 3', dartsThrown: 2, total: 24, vsPar: 3,
          phase: GolfCardPhase.holeDoneBad, statusLine: 'BOGEY — 4 STROKES',
          holeStrokes: 4,
          opponents: const [
            GolfOpponentEntry(
                name: 'KARI',
                total: 20,
                vsPar: -1,
                doneThisHole: true,
                accent: Colors.pink),
          ],
        ),
      ),
    ));
    expect(find.text('BOGEY — 4 STROKES'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('KARI'), findsOneWidget);
  });

  testWidgets(
      'opponent tile totals clamp instead of overflowing on wide values',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 375,
          child: DossedartGolfActiveCard(
            playerName: 'A', avatarPath: null, accentColor: Colors.cyan,
            holeLabel: 'HOLE 9 · PAR 3', dartsThrown: 0, total: 50, vsPar: 5,
            phase: GolfCardPhase.teeOff, statusLine: 'TEE OFF',
            opponents: const [
              GolfOpponentEntry(
                  name: 'BJØRNAR',
                  total: 108,
                  vsPar: 27,
                  doneThisHole: false,
                  accent: Colors.pink),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('108'), findsOneWidget);
    expect(find.text('+27'), findsOneWidget);
  });

  group('vsParLabel', () {
    test('formats even, over and under par', () {
      expect(vsParLabel(0), 'E');
      expect(vsParLabel(2), '+2');
      expect(vsParLabel(-1), '-1');
    });
  });

  group('golfTermColor', () {
    test('maps stroke counts to the expected DossedartTokens colours', () {
      expect(golfTermColor(1), DossedartTokens.cyan);
      expect(golfTermColor(2), DossedartTokens.green);
      expect(golfTermColor(3), DossedartTokens.phosphor);
      expect(golfTermColor(4), DossedartTokens.orange);
      expect(golfTermColor(5), DossedartTokens.red);
      expect(golfTermColor(6), DossedartTokens.red);
    });
  });

  testWidgets('scorecard strip colours played holes and highlights current',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GolfScorecardStrip(
          strokes: [1, 4, null, null, null, null, null, null, null],
          currentHole: 2,
          onExpand: () {},
        ),
      ),
    ));
    expect(find.text('1'), findsWidgets); // hole numbers render
    // played cells get term colour, unplayed are empty — assert by key:
    expect(find.byKey(const ValueKey('golf-hole-0-played')), findsOneWidget);
    expect(find.byKey(const ValueKey('golf-hole-2-current')), findsOneWidget);
  });

  testWidgets('score sheet shows par row, totals and legend', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showGolfScoreSheet(context,
            names: ['A', 'B'],
            scorecards: [
              [1, 3, null], [6, 3, null],
            ],
            totals: [4, 9], vsPars: [-2, 3], skippedSeats: {}),
        child: const Text('open'),
      ),
    ))));
    await tester.tap(find.text('open'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PAR'), findsNWidgets(2)); // grid par row + legend label
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('ACE'), findsOneWidget); // legend
  });
}
