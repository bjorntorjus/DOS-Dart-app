/// Standard double-out checkout table for scores 2-170.
/// Each entry shows the optimal way to finish with the last dart being a double.
const Map<int, String> checkoutTable = {
  170: 'T20 T20 Bull',
  167: 'T20 T19 Bull',
  164: 'T20 T18 Bull',
  161: 'T20 T17 Bull',
  160: 'T20 T20 D20',
  158: 'T20 T20 D19',
  157: 'T20 T19 D20',
  156: 'T20 T20 D18',
  155: 'T20 T19 D19',
  154: 'T20 T18 D20',
  153: 'T20 T19 D18',
  152: 'T20 T20 D16',
  151: 'T20 T17 D20',
  150: 'T20 T18 D18',
  149: 'T20 T19 D16',
  148: 'T20 T16 D20',
  147: 'T20 T17 D18',
  146: 'T20 T18 D16',
  145: 'T20 T15 D20',
  144: 'T20 T20 D12',
  143: 'T20 T17 D16',
  142: 'T20 T14 D20',
  141: 'T20 T19 D12',
  140: 'T20 T20 D10',
  139: 'T20 T13 D20',
  138: 'T20 T18 D12',
  137: 'T20 T19 D10',
  136: 'T20 T20 D8',
  135: 'T20 T17 D12',
  134: 'T20 T14 D16',
  133: 'T20 T19 D8',
  132: 'T20 T16 D12',
  131: 'T20 T13 D16',
  130: 'T20 T18 D8',
  129: 'T19 T16 D12',
  128: 'T18 T14 D16',
  127: 'T20 T17 D8',
  126: 'T19 T19 D6',
  125: 'T20 T19 D4',
  124: 'T20 T16 D8',
  123: 'T19 T16 D9',
  122: 'T18 T18 D7',
  121: 'T20 T11 D14',
  120: 'T20 S20 D20',
  119: 'T19 T12 D13',
  118: 'T20 S18 D20',
  117: 'T20 S17 D20',
  116: 'T20 S16 D20',
  115: 'T20 S15 D20',
  114: 'T20 S14 D20',
  113: 'T20 S13 D20',
  112: 'T20 T12 D8',
  111: 'T20 S11 D20',
  110: 'T20 S10 D20',
  109: 'T20 S9 D20',
  108: 'T20 S8 D20',
  107: 'T19 S10 D20',
  106: 'T20 S6 D20',
  105: 'T20 S5 D20',
  104: 'T18 S10 D20',
  103: 'T19 S6 D20',
  102: 'T20 S10 D16',
  101: 'T17 S10 D20',
  100: 'T20 D20',
  99: 'T19 S10 D16',
  98: 'T20 D19',
  97: 'T19 D20',
  96: 'T20 D18',
  95: 'T19 D19',
  94: 'T18 D20',
  93: 'T19 D18',
  92: 'T20 D16',
  91: 'T17 D20',
  90: 'T18 D18',
  89: 'T19 D16',
  88: 'T16 D20',
  87: 'T17 D18',
  86: 'T18 D16',
  85: 'T15 D20',
  84: 'T20 D12',
  83: 'T17 D16',
  82: 'T14 D20',
  81: 'T19 D12',
  80: 'T20 D10',
  79: 'T13 D20',
  78: 'T18 D12',
  77: 'T19 D10',
  76: 'T20 D8',
  75: 'T17 D12',
  74: 'T14 D16',
  73: 'T19 D8',
  72: 'T16 D12',
  71: 'T13 D16',
  70: 'T18 D8',
  69: 'T19 D6',
  68: 'T20 D4',
  67: 'T17 D8',
  66: 'T10 D18',
  65: 'T19 D4',
  64: 'T16 D8',
  63: 'T13 D12',
  62: 'T10 D16',
  61: 'T15 D8',
  60: 'S20 D20',
  59: 'S19 D20',
  58: 'S18 D20',
  57: 'S17 D20',
  56: 'S16 D20',
  55: 'S15 D20',
  54: 'S14 D20',
  53: 'S13 D20',
  52: 'S12 D20',
  51: 'S11 D20',
  50: 'Bull',
  49: 'S9 D20',
  48: 'S8 D20',
  47: 'S7 D20',
  46: 'S6 D20',
  45: 'S13 D16',
  44: 'S4 D20',
  43: 'S3 D20',
  42: 'S10 D16',
  41: 'S9 D16',
  40: 'D20',
  38: 'D19',
  36: 'D18',
  34: 'D17',
  32: 'D16',
  30: 'D15',
  28: 'D14',
  26: 'D13',
  24: 'D12',
  22: 'D11',
  20: 'D10',
  18: 'D9',
  16: 'D8',
  14: 'D7',
  12: 'D6',
  10: 'D5',
  8: 'D4',
  6: 'D3',
  4: 'D2',
  2: 'D1',
  // Odd numbers 3-39 that need setup (single + double)
  39: 'S7 D16',
  37: 'S5 D16',
  35: 'S3 D16',
  33: 'S1 D16',
  31: 'S15 D8',
  29: 'S13 D8',
  27: 'S11 D8',
  25: 'S9 D8',
  23: 'S7 D8',
  21: 'S5 D8',
  19: 'S3 D8',
  17: 'S1 D8',
  15: 'S7 D4',
  13: 'S5 D4',
  11: 'S3 D4',
  9: 'S1 D4',
  7: 'S3 D2',
  5: 'S1 D2',
  3: 'S1 D1',
};

/// Straight-out (no special finish required) checkout suggestions.
/// Prefers singles over doubles when the value is the same (S20 > D10).
/// Only includes scores up to 180 (max 3-dart finish).
String? straightOutCheckout(int score) {
  if (score <= 0 || score > 180) return null;

  // 1-dart finishes: prefer single > bull > double > triple
  // Singles 1-20
  if (score >= 1 && score <= 20) return 'S$score';
  // Bull
  if (score == 25) return 'Bull';
  // Double bull
  if (score == 50) return 'Bull';
  // Doubles 2-40 (even only, but singles already cover 1-20)
  if (score >= 22 && score <= 40 && score % 2 == 0) return 'D${score ~/ 2}';
  // Triples
  if (score >= 21 && score <= 60 && score % 3 == 0 && score ~/ 3 <= 20) {
    // But prefer S + S or other combos? No — for 1 dart, triple is fine
    // However 21 = S21 doesn't exist. Check if single works first.
    return 'T${score ~/ 3}';
  }

  // 2-dart finishes
  // Try T20 + remainder
  for (final first in _straightOutDarts()) {
    final remainder = score - first.points;
    if (remainder <= 0) continue;
    final second = _bestSingleDart(remainder);
    if (second != null) {
      return '${first.label} ${second.label}';
    }
  }

  // 3-dart finishes
  for (final first in _straightOutDarts()) {
    final afterFirst = score - first.points;
    if (afterFirst <= 0) continue;
    for (final second in _straightOutDarts()) {
      final remainder = afterFirst - second.points;
      if (remainder <= 0) continue;
      final third = _bestSingleDart(remainder);
      if (third != null) {
        return '${first.label} ${second.label} ${third.label}';
      }
    }
  }

  return null;
}

class _DartOption {
  final String label;
  final int points;
  _DartOption(this.label, this.points);
}

/// Returns a single dart that exactly hits the given score, preferring simpler darts.
_DartOption? _bestSingleDart(int score) {
  if (score <= 0 || score > 60) return null;
  // Prefer: single > bull/d-bull > double > triple
  if (score >= 1 && score <= 20) return _DartOption('S$score', score);
  if (score == 25) return _DartOption('Bull', 25);
  if (score == 50) return _DartOption('Bull', 50);
  if (score % 2 == 0 && score ~/ 2 <= 20) return _DartOption('D${score ~/ 2}', score);
  if (score % 3 == 0 && score ~/ 3 <= 20) return _DartOption('T${score ~/ 3}', score);
  return null;
}

/// Ordered list of darts to try, highest value first, preferring simpler multipliers.
List<_DartOption> _straightOutDarts() {
  final darts = <_DartOption>[];
  // Triples 20 down to 1 (60-3)
  for (int i = 20; i >= 1; i--) {
    darts.add(_DartOption('T$i', i * 3));
  }
  // D-Bull
  darts.add(_DartOption('Bull', 50));
  // Doubles 20 down to 1 (40-2)
  for (int i = 20; i >= 1; i--) {
    darts.add(_DartOption('D$i', i * 2));
  }
  // Bull
  darts.add(_DartOption('Bull', 25));
  // Singles 20 down to 1
  for (int i = 20; i >= 1; i--) {
    darts.add(_DartOption('S$i', i));
  }
  return darts;
}
