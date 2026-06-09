import '../models/dart_throw.dart';

/// Marks a single dart is worth in Cricket: the multiplier on an open target
/// (single/double/treble = 1/2/3), single/double bull = 1/2, else 0.
int cricketMarksForDart(DartThrow t, Set<int> targets) =>
    targets.contains(t.segment) ? t.multiplier : 0;

/// The most marks landed in any single turn (grouped by turnId). 9 marks ⇒
/// three trebles in one turn (THE NINE).
int cricketMaxMarksInTurn(Iterable<DartThrow> playerThrows, Set<int> targets) {
  final byTurn = <int, int>{};
  for (final t in playerThrows) {
    byTurn[t.turnId] = (byTurn[t.turnId] ?? 0) + cricketMarksForDart(t, targets);
  }
  var max = 0;
  for (final m in byTurn.values) {
    if (m > max) max = m;
  }
  return max;
}
