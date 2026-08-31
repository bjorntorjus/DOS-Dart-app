import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/utils/join_seed.dart';

void main() {
  group('worstSeat', () {
    test('higher is better: worst seat holds the lowest value', () {
      expect(worstSeat([40, 12, 25], [0, 1, 2], higherIsBetter: true), 1);
    });

    test('lower is better: worst seat holds the highest value', () {
      expect(worstSeat([40, 12, 25], [0, 1, 2], higherIsBetter: false), 0);
    });

    test('inactive seats are ignored even when they hold the worst value', () {
      // Seat 1 is worst overall but not active; seat 2 is the worst active.
      expect(worstSeat([40, 12, 25], [0, 2], higherIsBetter: true), 2);
    });

    test('ties resolve to the latest seat', () {
      expect(worstSeat([12, 12, 40], [0, 1, 2], higherIsBetter: true), 1);
    });

    test('returns null when no seat is active', () {
      expect(worstSeat([40, 12], const <int>[], higherIsBetter: true), isNull);
    });
  });

  group('withSeatTiebreak', () {
    test('falls back to seat order when the wrapped comparator is equal', () {
      final cmp = withSeatTiebreak((a, b) => 0);
      expect(cmp(1, 3), lessThan(0));
      expect(cmp(3, 1), greaterThan(0));
      expect(cmp(2, 2), 0);
    });

    test('does not override a decisive wrapped comparator', () {
      final cmp = withSeatTiebreak((a, b) => b.compareTo(a));
      expect(cmp(1, 3), greaterThan(0));
    });

    test('makes tied ordering stable across repeated sorts', () {
      // Dart's List.sort is not stable, so an all-equal comparator can permute
      // the list. The seat tiebreak pins it.
      final cmp = withSeatTiebreak((a, b) => 0);
      for (var i = 0; i < 20; i++) {
        final seats = [4, 1, 3, 0, 2]..sort(cmp);
        expect(seats, [0, 1, 2, 3, 4]);
      }
    });
  });
}
