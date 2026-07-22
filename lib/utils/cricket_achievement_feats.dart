import '../models/dart_throw.dart';

/// Max real marks scored by [playerIndex] in a single turn, replayed from the
/// FULL chronological [allThrows] (every player) so closure state is known at
/// each dart: a hit on a target closed by ALL players (dead) scores 0 marks.
/// History-derived → automatically undo-safe.
int cricketMaxMarksInTurn(
  List<DartThrow> allThrows,
  Set<int> targets,
  int playerIndex,
  int playerCount,
) {
  final marks = List.generate(playerCount, (_) => <int, int>{});
  final marksByTurn = <int, int>{};
  for (final t in allThrows) {
    if (!targets.contains(t.segment)) continue;
    if (t.playerIndex >= playerCount) continue;
    final dead = List.generate(
            playerCount, (p) => (marks[p][t.segment] ?? 0) >= 3)
        .every((closed) => closed);
    final gained = dead ? 0 : t.multiplier;
    marks[t.playerIndex][t.segment] =
        (marks[t.playerIndex][t.segment] ?? 0) + t.multiplier;
    if (t.playerIndex == playerIndex && gained > 0) {
      marksByTurn[t.turnId] = (marksByTurn[t.turnId] ?? 0) + gained;
    }
  }
  return marksByTurn.values.fold(0, (m, v) => v > m ? v : m);
}
