import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

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
}
