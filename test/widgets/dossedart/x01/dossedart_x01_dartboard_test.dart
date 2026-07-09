import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

// Sample radius (fraction of board radius) inside the outer-single band,
// which spans (kTripleR, kOuterSingleR] = (0.58, 0.82].
const double _outerSingleSampleR = 0.7;

void main() {
  group('hit-test', () {
    // Board has radius 100 in unit space; centre at (0,0).
    // Angles: 0° = top (12 o'clock), clockwise positive.

    test('centre tap → dBull', () {
      expect(zoneForPolar(0, 0), const DartZone.dBull());
    });

    test('inside bull ring (r=0.10) → bull', () {
      expect(zoneForPolar(0.10, 0), const DartZone.bull());
    });

    test('inner single at top (r=0.30, angle 0) → single 20', () {
      expect(zoneForPolar(0.30, 0), const DartZone.single(20));
    });

    test('triple ring at top (r=0.52, angle 0) → triple 20', () {
      expect(zoneForPolar(0.52, 0), const DartZone.triple(20));
    });

    test('outer single at top (r=0.70, angle 0) → single 20', () {
      expect(zoneForPolar(0.70, 0), const DartZone.single(20));
    });

    test('double ring at top (r=0.90, angle 0) → double 20', () {
      expect(zoneForPolar(0.90, 0), const DartZone.double_(20));
    });

    test('label band (r=0.98) → miss', () {
      expect(zoneForPolar(0.98, 0), const DartZone.miss());
    });

    test('outside the board (r=1.1) → miss', () {
      expect(zoneForPolar(1.1, 0), const DartZone.miss());
    });

    test('right side (angle 90°) → segment 6', () {
      // Per standard ordering, segment 90° clockwise from top is 6.
      expect(zoneForPolar(0.30, 90), const DartZone.single(6));
    });

    test('bottom (angle 180°) → segment 3', () {
      expect(zoneForPolar(0.30, 180), const DartZone.single(3));
    });
  });

  testWidgets('GestureDetector fires onTap with computed zone',
      (tester) async {
    DartZone? lastZone;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: DossedartX01Dartboard(
              onTap: (z) => lastZone = z,
            ),
          ),
        ),
      ),
    ));
    // Tap dead-centre: dBull.
    await tester.tapAt(tester.getCenter(find.byType(DossedartX01Dartboard)));
    expect(lastZone, const DartZone.dBull());
  });

  group('WILDCARD dim predicate', () {
    testWidgets('renders with no isDim (default null) — unchanged behaviour',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: DossedartX01Dartboard(onTap: (_) {}),
            ),
          ),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with an isDim predicate — no exceptions',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: DossedartX01Dartboard(
                onTap: (_) {},
                isDim: (n, _) => n.isOdd,
              ),
            ),
          ),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'hit-testing is unaffected by dimming — dimmed and non-dimmed '
        'segments both tap through correctly', (tester) async {
      DartZone? lastZone;
      const boardSize = 320.0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: DossedartX01Dartboard(
                onTap: (z) => lastZone = z,
                // 20 is even (not dimmed), 1 is odd (dimmed) — both must
                // still resolve to their zone; dimming is purely visual.
                isDim: (n, _) => n.isOdd,
              ),
            ),
          ),
        ),
      ));

      final centre = tester.getCenter(find.byType(DossedartX01Dartboard));
      final boardRadius = boardSize / 2;

      // Segment 20's outer-single band: angle 0 (straight up), r ~0.7.
      final seg20Offset =
          centre + Offset(0, -boardRadius * _outerSingleSampleR);
      await tester.tapAt(seg20Offset);
      expect(lastZone, const DartZone.single(20));

      // Segment 1 is the next wedge clockwise from 20 (18° clockwise),
      // sampled in its outer-single band too.
      final angleRad = (18 * math.pi / 180) - (math.pi / 2);
      final seg1Offset = centre +
          Offset(
            math.cos(angleRad) * boardRadius * _outerSingleSampleR,
            math.sin(angleRad) * boardRadius * _outerSingleSampleR,
          );
      await tester.tapAt(seg1Offset);
      expect(lastZone, const DartZone.single(1));
    });

    testWidgets(
        'per-ring rendering smoke: EVENS predicate — '
        '(s, m) => (s * m).isOdd renders without exception',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: DossedartX01Dartboard(
                onTap: (_) {},
                isDim: (s, m) => (s * m).isOdd,
              ),
            ),
          ),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'per-ring rendering smoke: DIV3 predicate — '
        '(s, m) => (s * m) % 3 != 0 renders without exception',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: DossedartX01Dartboard(
                onTap: (_) {},
                isDim: (s, m) => (s * m) % 3 != 0,
              ),
            ),
          ),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'hit-testing unaffected by partial dim: segment 5 double/single '
        'with EVENS predicate — taps resolve to correct zones',
        (tester) async {
      DartZone? lastZone;
      const boardSize = 320.0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: DossedartX01Dartboard(
                onTap: (z) => lastZone = z,
                // EVENS: (5*2).isOdd=false (double lit), (5*1).isOdd=true (single dim)
                isDim: (s, m) => (s * m).isOdd,
              ),
            ),
          ),
        ),
      ));

      final centre = tester.getCenter(find.byType(DossedartX01Dartboard));
      final boardRadius = boardSize / 2;

      // Segment 5 is at index 19 (last segment); angle = 18 * 19 = 342°
      // Tap in segment 5's double band (r between kOuterSingleR=0.82, kDoubleR=0.95)
      const doubleR = 0.88;
      final angleRad5 = (18 * 19 * math.pi / 180) - (math.pi / 2);
      final seg5DoubleOffset = centre +
          Offset(
            math.cos(angleRad5) * boardRadius * doubleR,
            math.sin(angleRad5) * boardRadius * doubleR,
          );
      await tester.tapAt(seg5DoubleOffset);
      expect(lastZone, const DartZone.double_(5));

      // Tap in segment 5's outer-single band (r between kTripleR=0.58, kOuterSingleR=0.82)
      const singleR = 0.70;
      final seg5SingleOffset = centre +
          Offset(
            math.cos(angleRad5) * boardRadius * singleR,
            math.sin(angleRad5) * boardRadius * singleR,
          );
      await tester.tapAt(seg5SingleOffset);
      expect(lastZone, const DartZone.single(5));
    });

    testWidgets(
        'predicate-contract: EVENS band mapping — '
        'segment 5 (odd) dims singles/triples, segment 8 (even) dims nothing',
        (tester) async {
      // EVENS predicate: (s * m).isOdd
      // Segment 5: 5*1=5(odd)→true, 5*3=15(odd)→true, 5*2=10(even)→false
      // Segment 8: 8*1=8(even)→false, 8*3=24(even)→false, 8*2=16(even)→false
      bool evensDim(int segment, int multiplier) => (segment * multiplier).isOdd;

      // Document the band states:
      expect(evensDim(5, 1), true);  // single (m=1) dims
      expect(evensDim(5, 3), true);  // triple (m=3) dims
      expect(evensDim(5, 2), false); // double (m=2) lit
      expect(evensDim(8, 1), false); // segment 8 all lit
      expect(evensDim(8, 3), false);
      expect(evensDim(8, 2), false);
    });
  });
}
