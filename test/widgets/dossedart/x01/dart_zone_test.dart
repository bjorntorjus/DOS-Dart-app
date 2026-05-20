import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart';

void main() {
  group('DartZone.toSegmentMultiplier', () {
    test('single 20 → (20, 1)', () {
      expect(const DartZone.single(20).toSegmentMultiplier(), (20, 1));
    });
    test('double 16 → (16, 2)', () {
      expect(const DartZone.double_(16).toSegmentMultiplier(), (16, 2));
    });
    test('triple 19 → (19, 3)', () {
      expect(const DartZone.triple(19).toSegmentMultiplier(), (19, 3));
    });
    test('bull → (25, 1)', () {
      expect(const DartZone.bull().toSegmentMultiplier(), (25, 1));
    });
    test('dBull → (25, 2)', () {
      expect(const DartZone.dBull().toSegmentMultiplier(), (25, 2));
    });
    test('miss → (0, 1)', () {
      expect(const DartZone.miss().toSegmentMultiplier(), (0, 1));
    });
  });
}
