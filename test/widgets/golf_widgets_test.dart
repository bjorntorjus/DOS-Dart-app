import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_input_cells.dart';
import 'package:dart_scoring/widgets/dossedart/golf/dossedart_golf_active_card.dart';
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
}
