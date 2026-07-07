import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/checkout_table.dart';

/// F20 (audit 2026-07-06): 257 lines of checkout data had no test that
/// suggestions are legal, sum correctly, and end on a double.
int _dartPoints(String label, {required bool isLast}) {
  if (label == 'Bull') {
    // 'Bull' is overloaded: as the FINAL dart of a double-out combo it is
    // the double bull (50); table entries never use it as a 25 setup dart
    // except where the sum proves otherwise — resolve by trying 50 first
    // in the caller. Here we just signal with a negative marker.
    throw StateError('Bull handled by caller');
  }
  final kind = label[0];
  final n = int.parse(label.substring(1));
  if (n < 1 || n > 20) fail('illegal segment in "$label"');
  switch (kind) {
    case 'S':
      return n;
    case 'D':
      return 2 * n;
    case 'T':
      return 3 * n;
    default:
      fail('illegal dart label "$label"');
  }
}

/// Returns every possible total for a combo, accounting for Bull = 25 or 50.
List<int> _possibleTotals(List<String> darts) {
  var totals = <int>[0];
  for (final d in darts) {
    final opts = d == 'Bull' ? [25, 50] : [_dartPoints(d, isLast: false)];
    totals = [for (final t in totals) for (final o in opts) t + o];
  }
  return totals;
}

void main() {
  test('every entry is legal, sums to its key, and ends on a double', () {
    expect(checkoutTable, isNotEmpty);
    checkoutTable.forEach((score, combo) {
      final darts = combo.split(' ');
      expect(darts.length, inInclusiveRange(1, 3),
          reason: '$score: "$combo" has ${darts.length} darts');
      // Last dart must be a double: D<n> or Bull-as-50.
      final last = darts.last;
      expect(last == 'Bull' || last.startsWith('D'), isTrue,
          reason: '$score: "$combo" does not end on a double');
      // Sum: at least one Bull-resolution must hit the key, and the
      // resolution must use Bull=50 for the final dart.
      final totals = _possibleTotals(darts);
      expect(totals, contains(score),
          reason: '$score: "$combo" cannot sum to $score');
      if (last == 'Bull') {
        final headTotals = _possibleTotals(darts.sublist(0, darts.length - 1));
        expect(headTotals, contains(score - 50),
            reason: '$score: "$combo" must finish on the DOUBLE bull (50)');
      }
    });
  });

  test('bogey numbers are absent by design', () {
    for (final bogey in [159, 162, 163, 165, 166, 168, 169]) {
      expect(checkoutTable.containsKey(bogey), isFalse,
          reason: '$bogey is a classic impossible double-out');
    }
    expect(checkoutTable.containsKey(170), isTrue);
    expect(checkoutTable.containsKey(2), isTrue);
  });

  group('straightOutCheckout', () {
    test('null out of range', () {
      expect(straightOutCheckout(0), isNull);
      expect(straightOutCheckout(-5), isNull);
      expect(straightOutCheckout(181), isNull);
    });
    // These 9 totals cannot be reached by ANY combination of up to 3 darts
    // (each dart's value is drawn from {1..20, 25, 50, even doubles <=40,
    // multiples-of-3 triples <=60} — a set with gaps). This is a stricter,
    // different list than the classic double-out "bogey numbers"
    // (159/162/163/165/166/168/169): e.g. 159 = T20 T20 T13 is a perfectly
    // valid *straight* 3-dart total, it just can't finish on a double.
    // Verified exhaustively: straightOutCheckout returns null for exactly
    // these 9 scores in 1..180, and non-null for every other one.
    const unreachableIn3Darts = {163, 166, 169, 172, 173, 175, 176, 178, 179};

    test('suggestions sum to the score for 1..180 (except the 9 scores '
        'unreachable by any 3-dart combination)', () {
      for (var score = 1; score <= 180; score++) {
        final combo = straightOutCheckout(score);
        if (unreachableIn3Darts.contains(score)) {
          expect(combo, isNull,
              reason: '$score should be unreachable by 3 darts, got "$combo"');
          continue;
        }
        expect(combo, isNotNull, reason: 'no straight-out for $score');
        expect(_possibleTotals(combo!.split(' ')), contains(score),
            reason: '$score: "$combo" does not sum');
      }
    });
  });
}
