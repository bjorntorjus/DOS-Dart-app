import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_common.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_hero.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_input_cells.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_leaderboard.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_scorecard.dart';
import 'package:dart_scoring/widgets/dossedart/golf/golf_status_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GolfInputCells', () {
    testWidgets('renders S/D/T cells with terms for a normal hole', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfInputCells(targetNumber: 7, onHit: (m) => tapped = m),
          ),
        ),
      );
      expect(find.text('S7'), findsOneWidget);
      expect(find.text('D7'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('ACE'), findsOneWidget);
      await tester.tap(find.text('T7'));
      expect(tapped, 3);
    });

    testWidgets('names the console and states the live target — one line', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GolfInputCells(targetNumber: 7, onHit: (_) {})),
        ),
      );
      expect(find.text('▼ TAP TO SCORE'), findsOneWidget);
      expect(find.textContaining('THROW AT 7'), findsOneWidget);
    });

    testWidgets('shows the copy-delta miss caption (rules v2: miss = +1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GolfInputCells(targetNumber: 7, onHit: (_) {})),
        ),
      );
      expect(find.text('✗ MISS = +1 STROKE'), findsOneWidget);
    });

    testWidgets(
      'renders two cells for a Bull playoff — 25/50 labels, no triple',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GolfInputCells(targetNumber: 25, onHit: (_) {}),
            ),
          ),
        );
        expect(find.text('25'), findsOneWidget);
        expect(find.text('50'), findsOneWidget);
        expect(find.text('T25'), findsNothing);
        expect(find.text('BULL'), findsNothing); // cell label dropped in v2
        expect(find.text('PAR'), findsOneWidget);
        expect(find.text('BIRDIE'), findsOneWidget);
        expect(
          find.textContaining('THROW AT BULL'),
          findsOneWidget,
        ); // header still names the aim generically
      },
    );
  });

  group('GolfHero v3 (244px hero, chips + status plate)', () {
    const heroWidth = 820.0;

    Future<void> pumpHero(WidgetTester tester, Widget hero) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: heroWidth, child: hero),
          ),
        ),
      );
    }

    testWidgets('pins to 244px tall — tee-off', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'BJØRNAR',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 7,
          playoff: false,
          dartLabels: [],
          plateMode: GolfPlateMode.teeOff,
        ),
      );
      expect(tester.getSize(find.byType(GolfHero)).height, 244);
    });

    testWidgets('pins to 244px tall — mid-hole', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 9,
          playoff: false,
          dartLabels: ['✗', '✗'],
          plateMode: GolfPlateMode.mid,
          lie: 2,
        ),
      );
      expect(tester.getSize(find.byType(GolfHero)).height, 244);
    });

    testWidgets('pins to 244px tall — hole-result window', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'BJØRNAR',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 7,
          playoff: false,
          dartLabels: ['✗', '✗', 'S7'],
          plateMode: GolfPlateMode.result,
          lie: 4,
          nextPlayerName: 'KARI',
        ),
      );
      expect(tester.getSize(find.byType(GolfHero)).height, 244);
    });

    testWidgets('pins to 244px tall — a wash', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'BJØRNAR',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 7,
          playoff: false,
          dartLabels: ['✗', '✗', '✗'],
          plateMode: GolfPlateMode.result,
          lie: 6,
          wash: true,
          nextPlayerName: 'KARI',
        ),
      );
      expect(tester.getSize(find.byType(GolfHero)).height, 244);
    });

    testWidgets('pins to 244px tall — playoff Bull aim', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 25,
          playoff: true,
          dartLabels: [],
          plateMode: GolfPlateMode.teeOff,
        ),
      );
      expect(tester.getSize(find.byType(GolfHero)).height, 244);
      expect(find.text('PLAYOFF'), findsOneWidget);
      expect(find.text('BULL'), findsOneWidget);
      expect(find.text('25'), findsNothing);
    });

    testWidgets('shows DART 1/3 with zero darts thrown', (tester) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 7,
          playoff: false,
          dartLabels: [],
          plateMode: GolfPlateMode.teeOff,
        ),
      );
      expect(find.text('DART 1/3'), findsOneWidget);
    });

    testWidgets('renders per-dart chip labels and unthrown placeholders', (
      tester,
    ) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 9,
          playoff: false,
          dartLabels: ['S9'],
          plateMode: GolfPlateMode.mid,
          lie: 1,
        ),
      );
      expect(find.text('S9'), findsOneWidget);
      expect(find.text('·'), findsNWidgets(2));
    });

    testWidgets('the TOTAL block and NOW THROWING/HOLE RESULT badge are gone', (
      tester,
    ) async {
      await pumpHero(
        tester,
        const GolfHero(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          targetNumber: 7,
          playoff: false,
          dartLabels: [],
          plateMode: GolfPlateMode.teeOff,
        ),
      );
      expect(find.text('TOTAL'), findsNothing);
      expect(find.textContaining('NOW THROWING'), findsNothing);
      expect(find.textContaining('HOLE RESULT'), findsNothing);
    });
  });

  group('GolfStatusPlate', () {
    testWidgets('tee-off states the copy-delta prompt', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(mode: GolfPlateMode.teeOff, dartLabels: []),
          ),
        ),
      );
      expect(find.text('▸ TEE OFF · LAST DART COUNTS'), findsOneWidget);
    });

    testWidgets('mid-hole with a lie shows LYING n, the term and darts left', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(
              mode: GolfPlateMode.mid,
              dartLabels: const ['✗', '✗'],
              lie: 2,
            ),
          ),
        ),
      );
      expect(find.text('LYING 2'), findsOneWidget);
      expect(find.text('BIRDIE'), findsOneWidget);
      expect(find.text('1 DART LEFT'), findsOneWidget);
    });

    testWidgets('mid-hole with no lie yet shows NO SCORE and darts left', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(
              mode: GolfPlateMode.mid,
              dartLabels: const ['✗'],
            ),
          ),
        ),
      );
      expect(find.text('NO SCORE'), findsOneWidget);
      expect(find.text('2 DARTS LEFT'), findsOneWidget);
      // The term is only accurate once the hole has actually finished.
      expect(find.text('BIRDIE'), findsNothing);
      expect(find.text('PAR'), findsNothing);
    });

    testWidgets('result shows the term, LYING n and NEXT', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(
              mode: GolfPlateMode.result,
              dartLabels: const ['✗', '✗', 'S7'],
              lie: 4,
              nextPlayerName: 'KARI',
            ),
          ),
        ),
      );
      expect(find.text('LYING 4'), findsOneWidget);
      expect(find.text('BOGEY'), findsOneWidget);
      expect(find.textContaining('NEXT'), findsOneWidget);
      expect(find.textContaining('KARI'), findsOneWidget);
    });

    testWidgets('result appends WASH when the hole washed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(
              mode: GolfPlateMode.result,
              dartLabels: const ['✗', '✗', '✗'],
              lie: 6,
              wash: true,
              nextPlayerName: 'KARI',
            ),
          ),
        ),
      );
      expect(find.textContaining(' · WASH'), findsOneWidget);
    });

    testWidgets('result omits WASH when the hole was not washed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(
              mode: GolfPlateMode.result,
              dartLabels: const ['✗', '✗', 'S7'],
              lie: 4,
              nextPlayerName: 'KARI',
            ),
          ),
        ),
      );
      expect(find.textContaining(' · WASH'), findsNothing);
    });

    testWidgets('three chips always render, even before any darts', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GolfStatusPlate(mode: GolfPlateMode.teeOff, dartLabels: []),
          ),
        ),
      );
      expect(find.byType(GolfDartChip), findsNWidgets(3));
      expect(find.text('·'), findsNWidgets(3));
    });
  });

  group('GolfDartChip', () {
    testWidgets('renders a thrown label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GolfDartChip(label: 'T7')),
        ),
      );
      expect(find.text('T7'), findsOneWidget);
    });

    testWidgets('renders the unthrown placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GolfDartChip(label: null))),
      );
      expect(find.text('·'), findsOneWidget);
    });
  });

  group('GolfLeaderboard', () {
    // Totals run in reverse of insertion order (P0 highest, Pn-1 lowest) so
    // the ascending-total sort actually has to reorder the rows — a pass
    // would be a false positive if entries happened to already be sorted.
    List<GolfLeaderboardEntry> buildEntries(int n) => [
      for (var i = 0; i < n; i++)
        GolfLeaderboardEntry(
          name: 'P$i',
          accent: Colors.cyan,
          total: 100 - i,
          vsPar: -i,
          isActive: false,
          holeStroke: 3,
        ),
    ];

    Future<void> pumpBoard(WidgetTester tester, {required int n}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfLeaderboard(
              entries: buildEntries(n),
              holeNumber: 10,
              playoff: false,
            ),
          ),
        ),
      );
    }

    testWidgets('pins height to header + n rows for n <= 5', (tester) async {
      for (final n in [2, 4, 5]) {
        await pumpBoard(tester, n: n);
        final size = tester.getSize(find.byKey(const Key('golfLeaderboardBoard')));
        expect(size.height, 34 + 56.0 * n + 2, reason: 'n=$n');
      }
    });

    testWidgets('caps height at 5 rows worth once there are 6+ entries', (
      tester,
    ) async {
      await pumpBoard(tester, n: 6);
      final size = tester.getSize(find.byKey(const Key('golfLeaderboardBoard')));
      expect(size.height, 34 + 56.0 * 5 + 2);
    });

    testWidgets('shows LOWEST WINS hint at 5 or fewer entries', (
      tester,
    ) async {
      await pumpBoard(tester, n: 5);
      expect(find.text('LOWEST WINS'), findsOneWidget);
      expect(find.textContaining('SCROLL'), findsNothing);
    });

    testWidgets('shows the player-count scroll hint at 6+ entries', (
      tester,
    ) async {
      await pumpBoard(tester, n: 6);
      expect(find.text('▼ 6 PLAYERS · SCROLL'), findsOneWidget);
      expect(find.text('LOWEST WINS'), findsNothing);
    });

    testWidgets('the THROWING/TO PLAY status column is gone', (
      tester,
    ) async {
      await pumpBoard(tester, n: 2);
      expect(find.text('▶ THROWING'), findsNothing);
      expect(find.textContaining('TO PLAY'), findsNothing);
    });

    testWidgets('scrolling the 6-entry board reveals the 6th, highest-total name', (
      tester,
    ) async {
      await pumpBoard(tester, n: 6);
      // P0 has the highest total (100), so after the ascending sort it's
      // the last (6th) row — cut off by the fixed 5-row window initially.
      expect(find.text('P0'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('sorts by total ascending and marks the leader row + this-hole chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfLeaderboard(
              entries: const [
                GolfLeaderboardEntry(
                  name: 'A',
                  accent: Colors.cyan,
                  total: 30,
                  vsPar: 6,
                  isActive: false,
                  holeStroke: 3,
                ),
                GolfLeaderboardEntry(
                  name: 'B',
                  accent: Colors.pink,
                  total: 24,
                  vsPar: 0,
                  isActive: true,
                ),
              ],
              holeNumber: 10,
              playoff: false,
            ),
          ),
        ),
      );
      expect(find.text('LEADERBOARD'), findsOneWidget);
      // B has the lower total, so it leads and renders above A.
      expect(
        tester.getTopLeft(find.text('B')).dy,
        lessThan(tester.getTopLeft(find.text('A')).dy),
      );
      expect(find.text('3'), findsOneWidget); // A's this-hole stroke chip
      expect(find.text('·'), findsOneWidget); // B (active) hasn't played it
    });

    testWidgets('playoff header reads TIED LEADERS', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfLeaderboard(
              entries: const [
                GolfLeaderboardEntry(
                  name: 'A',
                  accent: Colors.cyan,
                  total: 54,
                  vsPar: 0,
                  isActive: true,
                ),
              ],
              holeNumber: 19,
              playoff: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('TIED LEADERS'), findsOneWidget);
    });

    testWidgets(
      'total and vs-par clamp instead of overflowing on wide values',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 375,
                child: GolfLeaderboard(
                  entries: const [
                    GolfLeaderboardEntry(
                      name: 'BJØRNAR',
                      accent: Colors.pink,
                      total: 108,
                      vsPar: 27,
                      isActive: false,
                    ),
                  ],
                  holeNumber: 18,
                  playoff: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('108'), findsOneWidget);
        expect(find.text('+27'), findsOneWidget);
      },
    );
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
    testWidgets('colours played holes and highlights the current one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfScorecardStrip(
              strokes: [1, 4, null, null, null, null, null, null, null],
              currentHole: 2,
              onExpand: () {},
            ),
          ),
        ),
      );
      expect(find.text('1'), findsWidgets); // hole numbers render
      // played cells get term colour, unplayed are empty — assert by key:
      expect(find.byKey(const ValueKey('golf-hole-0-played')), findsOneWidget);
      expect(find.byKey(const ValueKey('golf-hole-2-current')), findsOneWidget);
    });

    testWidgets('windows to 7 holes centred on the current hole', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfScorecardStrip(
              strokes: List<int?>.filled(18, null),
              currentHole: 10, // hole 11 (1-based)
              onExpand: () {},
            ),
          ),
        ),
      );
      expect(find.text('YOUR CARD · HOLES 8–14'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('golf-hole-10-current')),
        findsOneWidget,
      );
      // Hole index 6 (hole 7) is outside the 8-14 window — not rendered.
      expect(find.byKey(const ValueKey('golf-hole-6-empty')), findsNothing);
    });

    testWidgets('clamps the window at the front edge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfScorecardStrip(
              strokes: List<int?>.filled(18, null),
              currentHole: 1, // hole 2 — too close to the front to centre
              onExpand: () {},
            ),
          ),
        ),
      );
      expect(find.text('YOUR CARD · HOLES 1–7'), findsOneWidget);
    });

    testWidgets('clamps the window at the back edge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfScorecardStrip(
              strokes: List<int?>.filled(18, null),
              currentHole: 16, // hole 17 — too close to the back to centre
              onExpand: () {},
            ),
          ),
        ),
      );
      expect(find.text('YOUR CARD · HOLES 12–18'), findsOneWidget);
    });

    testWidgets('the SCORECARD affordance triggers onExpand', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GolfScorecardStrip(
              strokes: List<int?>.filled(9, null),
              currentHole: 0,
              onExpand: () => expanded = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('SCORECARD ▸'));
      expect(expanded, isTrue);
    });
  });

  testWidgets('score sheet shows par row, totals and legend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGolfScoreSheet(
                context,
                names: ['A', 'B'],
                scorecards: [
                  [1, 3, null],
                  [6, 3, null],
                ],
                totals: [4, 9],
                vsPars: [-2, 3],
                skippedSeats: {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PAR'), findsNWidgets(2)); // grid par row + legend label
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('ACE'), findsOneWidget); // legend
  });
}
