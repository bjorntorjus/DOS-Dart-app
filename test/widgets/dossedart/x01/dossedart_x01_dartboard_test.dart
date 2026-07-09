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
  });
}
