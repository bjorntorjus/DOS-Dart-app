import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_common.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_hero.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_input_cells.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_leaderboard.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_scorecard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GolfInputCells', () {
    testWidgets('renders S/D/T cells with terms for a normal hole',
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

    testWidgets('names the console and states the live target — one line',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GolfInputCells(targetNumber: 7, onHit: (_) {})),
      ));
      expect(find.text('▼ TAP TO SCORE'), findsOneWidget);
      expect(find.textContaining('THROW AT 7'), findsOneWidget);
    });

    testWidgets('shows the copy-delta miss caption (rules v2: miss = +1)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GolfInputCells(targetNumber: 7, onHit: (_) {})),
      ));
      expect(find.text('✗ MISS = +1 STROKE'), findsOneWidget);
    });

    testWidgets(
        'renders two cells for a Bull playoff — 25/50 labels, no triple',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GolfInputCells(targetNumber: 25, onHit: (_) {})),
      ));
      expect(find.text('25'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('T25'), findsNothing);
      expect(find.text('BULL'), findsNothing); // cell label dropped in v2
      expect(find.text('PAR'), findsOneWidget);
      expect(find.text('BIRDIE'), findsOneWidget);
      expect(find.textContaining('THROW AT BULL'),
          findsOneWidget); // header still names the aim generically
    });
  });

  group('GolfHero', () {
    testWidgets('tee-off shows the copy-delta status line and the aim number',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfHero(
            playerName: 'BJØRNAR',
            avatarPath: null,
            accentColor: Colors.cyan,
            targetNumber: 7,
            playoff: false,
            dartsThrown: 0,
            total: 0,
            vsPar: 0,
          ),
        ),
      ));
      expect(find.text('HOLE'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('PAR 3'), findsOneWidget);
      expect(find.text('▸ TEE OFF · 3 DARTS'), findsOneWidget);
      expect(find.text('▶ NOW THROWING'), findsOneWidget);
    });

    testWidgets('mid-hole shows LYING n and darts-left, no term chip',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfHero(
            playerName: 'A',
            avatarPath: null,
            accentColor: Colors.cyan,
            targetNumber: 9,
            playoff: false,
            dartsThrown: 2,
            total: 0,
            vsPar: 0,
          ),
        ),
      ));
      expect(find.text('LYING 2'), findsOneWidget);
      expect(find.text('1 DART LEFT'), findsOneWidget);
      // No hole-done term (BIRDIE/PAR/...) is shown mid-hole — the term is
      // only accurate once the hole has actually finished.
      expect(find.text('BIRDIE'), findsNothing);
      expect(find.text('PAR'), findsNothing);
    });

    testWidgets(
        'hole-result window shows the term, LYING n and NEXT — badge switches',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfHero(
            playerName: 'BJØRNAR',
            avatarPath: null,
            accentColor: Colors.cyan,
            targetNumber: 7,
            playoff: false,
            dartsThrown: 2,
            total: 24,
            vsPar: 3,
            holeStrokes: 4, // BOGEY
            nextPlayerName: 'KARI',
          ),
        ),
      ));
      expect(find.text('LYING 4'), findsOneWidget);
      expect(find.text('BOGEY'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.textContaining('NEXT'), findsOneWidget);
      expect(find.textContaining('KARI'), findsOneWidget);
      expect(find.text('▣ HOLE RESULT'), findsOneWidget);
    });

    testWidgets('playoff Bull aim shows BULL and the PLAYOFF label',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfHero(
            playerName: 'A',
            avatarPath: null,
            accentColor: Colors.cyan,
            targetNumber: 25,
            playoff: true,
            dartsThrown: 0,
            total: 54,
            vsPar: 0,
          ),
        ),
      ));
      expect(find.text('PLAYOFF'), findsOneWidget);
      expect(find.text('BULL'), findsOneWidget);
      expect(find.text('25'), findsNothing);
    });
  });

  group('GolfLeaderboard', () {
    testWidgets('sorts by total, marks the leader and the active row',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfLeaderboard(
            entries: const [
              GolfLeaderboardEntry(
                  name: 'A', accent: Colors.cyan, total: 30, vsPar: 6, isActive: false, holeStroke: 3),
              GolfLeaderboardEntry(
                  name: 'B', accent: Colors.pink, total: 24, vsPar: 0, isActive: true),
            ],
            holeNumber: 10,
            playoff: false,
          ),
        ),
      ));
      expect(find.text('LEADERBOARD'), findsOneWidget);
      expect(find.text('▶ THROWING'), findsOneWidget); // B, the active seat
      expect(find.text('H10'), findsOneWidget); // A already played hole 10
      expect(find.text('3'), findsOneWidget); // A's stroke chip
      expect(find.text('· TO PLAY'), findsNothing);
    });

    testWidgets('shows TO PLAY for a seat that has not thrown this hole',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfLeaderboard(
            entries: const [
              GolfLeaderboardEntry(
                  name: 'A', accent: Colors.cyan, total: 10, vsPar: 1, isActive: false),
            ],
            holeNumber: 4,
            playoff: false,
          ),
        ),
      ));
      expect(find.text('· TO PLAY'), findsOneWidget);
    });

    testWidgets('playoff header reads TIED LEADERS', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfLeaderboard(
            entries: const [
              GolfLeaderboardEntry(
                  name: 'A', accent: Colors.cyan, total: 54, vsPar: 0, isActive: true),
            ],
            holeNumber: 19,
            playoff: true,
          ),
        ),
      ));
      expect(find.textContaining('TIED LEADERS'), findsOneWidget);
    });

    testWidgets('total and vs-par clamp instead of overflowing on wide values',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 375,
            child: GolfLeaderboard(
              entries: const [
                GolfLeaderboardEntry(
                    name: 'BJØRNAR', accent: Colors.pink, total: 108, vsPar: 27, isActive: false),
              ],
              holeNumber: 18,
              playoff: false,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('108'), findsOneWidget);
      expect(find.text('+27'), findsOneWidget);
    });
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

  group('vsParColor', () {
    test('under par green, over par orange, even phosphor', () {
      expect(vsParColor(-1), DossedartTokens.green);
      expect(vsParColor(1), DossedartTokens.orange);
      expect(vsParColor(0), DossedartTokens.phosphor);
    });
  });

  group('GolfScorecardStrip', () {
    testWidgets('colours played holes and highlights the current one',
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

    testWidgets('windows to 7 holes centred on the current hole',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfScorecardStrip(
            strokes: List<int?>.filled(18, null),
            currentHole: 10, // hole 11 (1-based)
            onExpand: () {},
          ),
        ),
      ));
      expect(find.text('YOUR CARD · HOLES 8–14'), findsOneWidget);
      expect(find.byKey(const ValueKey('golf-hole-10-current')), findsOneWidget);
      // Hole index 6 (hole 7) is outside the 8-14 window — not rendered.
      expect(find.byKey(const ValueKey('golf-hole-6-empty')), findsNothing);
    });

    testWidgets('clamps the window at the front edge', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfScorecardStrip(
            strokes: List<int?>.filled(18, null),
            currentHole: 1, // hole 2 — too close to the front to centre
            onExpand: () {},
          ),
        ),
      ));
      expect(find.text('YOUR CARD · HOLES 1–7'), findsOneWidget);
    });

    testWidgets('clamps the window at the back edge', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfScorecardStrip(
            strokes: List<int?>.filled(18, null),
            currentHole: 16, // hole 17 — too close to the back to centre
            onExpand: () {},
          ),
        ),
      ));
      expect(find.text('YOUR CARD · HOLES 12–18'), findsOneWidget);
    });

    testWidgets('the SCORECARD affordance triggers onExpand', (tester) async {
      var expanded = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GolfScorecardStrip(
            strokes: List<int?>.filled(9, null),
            currentHole: 0,
            onExpand: () => expanded = true,
          ),
        ),
      ));
      await tester.tap(find.text('SCORECARD ▸'));
      expect(expanded, isTrue);
    });
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
