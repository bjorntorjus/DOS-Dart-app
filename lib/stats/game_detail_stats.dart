import '../models/dart_throw.dart';

/// Per-player grid stats for the KAMPDETALJER comparison, derived from a
/// player's throws. Non-X01 modes fall back to their stored counters.
class GridStats {
  final double avg3; // 3-dart average (mean turn total)
  final int bestTurn;
  final int n180;
  final int n140; // turns in [140, 179]
  final int doublesHit;
  final int darts;

  const GridStats({
    required this.avg3,
    required this.bestTurn,
    required this.n180,
    required this.n140,
    required this.doublesHit,
    required this.darts,
  });
}

/// Computes X01 grid stats from [throws]. Turn-based metrics (avg/best/180/140)
/// group by [DartThrow.turnId] and skip busted turns; [darts] and [doublesHit]
/// count every dart thrown.
GridStats x01GridStats(List<DartThrow> throws, {required int playerIndex}) {
  final mine = throws.where((t) => t.playerIndex == playerIndex).toList();

  final byTurn = <int, List<DartThrow>>{};
  for (final t in mine) {
    (byTurn[t.turnId] ??= []).add(t);
  }

  var bestTurn = 0, n180 = 0, n140 = 0, turnCount = 0, totalTurnPoints = 0;
  for (final turn in byTurn.values) {
    if (turn.any((t) => t.isBust)) continue; // busted turn scores nothing
    final sum = turn.fold<int>(0, (s, t) => s + t.points);
    turnCount++;
    totalTurnPoints += sum;
    if (sum > bestTurn) bestTurn = sum;
    if (sum == 180) {
      n180++;
    } else if (sum >= 140) {
      n140++;
    }
  }

  final doublesHit =
      mine.where((t) => t.segment > 0 && t.multiplier == 2).length;

  return GridStats(
    avg3: turnCount > 0 ? totalTurnPoints / turnCount : 0.0,
    bestTurn: bestTurn,
    n180: n180,
    n140: n140,
    doublesHit: doublesHit,
    darts: mine.length,
  );
}
