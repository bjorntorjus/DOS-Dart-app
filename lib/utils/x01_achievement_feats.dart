import '../models/dart_throw.dart';

/// Single-game X01 achievement feats reconstructed from a player's throws.
/// Pure + testable — the game screen feeds it `throwHistory` at game-end and
/// fires the matching achievement events. This is the template the other modes
/// copy: derive per-turn / per-finish feats from the recorded throws.
class X01Feats {
  const X01Feats({
    required this.hit180,
    required this.bullFinish,
    required this.maxTreblesInTurn,
    required this.maxBullsInTurn,
  });

  final bool hit180; // a 3-dart turn totalling 180
  final bool bullFinish; // a dart that closed the leg landed on the bull
  final int maxTreblesInTurn; // most trebles in any single turn
  final int maxBullsInTurn; // most bulls in any single turn

  static X01Feats analyze(Iterable<DartThrow> playerThrows) {
    final byTurn = <int, List<DartThrow>>{};
    for (final t in playerThrows) {
      (byTurn[t.turnId] ??= []).add(t);
    }
    var hit180 = false;
    var maxTre = 0;
    var maxBull = 0;
    for (final turn in byTurn.values) {
      // A busted turn scores nothing — its darts grant no feats.
      if (turn.any((t) => t.isBust)) continue;
      final total = turn.fold<int>(0, (s, t) => s + t.points);
      if (total == 180) hit180 = true;
      final tre = turn.where((t) => t.multiplier == 3).length;
      final bull = turn.where((t) => t.segment == 25).length;
      if (tre > maxTre) maxTre = tre;
      if (bull > maxBull) maxBull = bull;
    }
    // A finishing dart brings the score to exactly 0 → scoreBefore == points.
    final bullFinish = playerThrows
        .any((t) => t.segment == 25 && t.scoreBefore == t.points && !t.isBust);
    return X01Feats(
      hit180: hit180,
      bullFinish: bullFinish,
      maxTreblesInTurn: maxTre,
      maxBullsInTurn: maxBull,
    );
  }
}
