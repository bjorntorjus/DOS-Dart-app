/// Pure Cricket game logic — no Flutter dependencies.
library;

class CricketHitResult {
  final int scored; // points scored this dart (0 for cutthroat / no overflow)
  final bool closedTarget; // did this dart close the target for current player?
  final bool turnEnded;
  final bool playerFinished;

  const CricketHitResult({
    required this.scored,
    required this.closedTarget,
    required this.turnEnded,
    required this.playerFinished,
  });
}

class CricketEngine {
  final List<int> targets;
  final bool isCutthroat;
  final int playerCount;

  late List<Map<int, int>> marks; // marks[playerIndex][target] = markCount (0-3+)
  late List<int> scores;
  final List<int> finishedPlayers = [];
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  bool gameOver = false;
  int? winnerIndex;

  CricketEngine({
    required this.targets,
    required this.isCutthroat,
    required this.playerCount,
  }) {
    marks =
        List.generate(playerCount, (_) => {for (final t in targets) t: 0});
    scores = List.filled(playerCount, 0);
  }

  // ---------------------------------------------------------------------------
  // Pure helpers
  // ---------------------------------------------------------------------------

  bool isClosed(int target, int playerIndex) =>
      (marks[playerIndex][target] ?? 0) >= 3;

  bool isClosedByAll(int target) =>
      List.generate(playerCount, (i) => i).every((i) => isClosed(target, i));

  bool allClosedByPlayer(int playerIndex) =>
      targets.every((t) => isClosed(t, playerIndex));

  /// How many marks overflow beyond the 3 needed to close [target] given
  /// [currentMarks] already on it and [multiplier] marks being added.
  static int computeOverflow(int currentMarks, int multiplier) {
    if (multiplier <= 0) return 0;
    final needed = (3 - currentMarks).clamp(0, multiplier);
    return multiplier - needed;
  }

  // ---------------------------------------------------------------------------
  // Winner detection
  // ---------------------------------------------------------------------------

  /// Check if [playerIndex] can finish now and mark them as finished.
  /// Returns true if they just finished.
  bool checkFinishForPlayer(int playerIndex) {
    if (finishedPlayers.contains(playerIndex)) return false;
    if (!allClosedByPlayer(playerIndex)) return false;

    for (int j = 0; j < playerCount; j++) {
      if (j == playerIndex || finishedPlayers.contains(j)) continue;
      if (isCutthroat) {
        // Cutthroat: player with lowest score wins — must have ≤ all opponents
        if (scores[j] < scores[playerIndex]) return false;
      } else {
        // Standard: must have ≥ all opponents
        if (scores[j] > scores[playerIndex]) return false;
      }
    }

    finishedPlayers.add(playerIndex);
    final active = List.generate(playerCount, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    if (active.length <= 1) {
      if (active.length == 1) finishedPlayers.add(active.first);
      winnerIndex = finishedPlayers.first;
      gameOver = true;
    } else {
      winnerIndex = finishedPlayers.first;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Stateful game actions
  // ---------------------------------------------------------------------------

  /// Apply a hit (segment + multiplier) for the current player.
  CricketHitResult applyHit(int segment, int multiplier) {
    assert(!finishedPlayers.contains(currentPlayerIndex),
        'Player $currentPlayerIndex has already finished');

    int scored = 0;
    bool closedTarget = false;

    if (segment > 0 && targets.contains(segment)) {
      final currentMarks = marks[currentPlayerIndex][segment] ?? 0;
      final newMarks = currentMarks + multiplier;
      marks[currentPlayerIndex][segment] = newMarks;

      if (currentMarks < 3 && newMarks >= 3) closedTarget = true;

      final overflow = computeOverflow(currentMarks, multiplier);
      if (overflow > 0 && !isClosedByAll(segment)) {
        final pts = segment * overflow;
        if (isCutthroat) {
          for (int j = 0; j < playerCount; j++) {
            if (j != currentPlayerIndex &&
                !isClosed(segment, j) &&
                !finishedPlayers.contains(j)) {
              scores[j] += pts;
            }
          }
        } else {
          scores[currentPlayerIndex] += pts;
          scored = pts;
        }
      }
    }

    dartsInTurn++;
    final justFinished = checkFinishForPlayer(currentPlayerIndex);

    final turnEnded = justFinished || dartsInTurn >= 3;
    if (turnEnded) {
      dartsInTurn = 0;
      if (!justFinished) _advancePlayer();
    }

    return CricketHitResult(
      scored: scored,
      closedTarget: closedTarget,
      turnEnded: turnEnded,
      playerFinished: justFinished,
    );
  }

  void _advancePlayer() {
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } while (finishedPlayers.contains(currentPlayerIndex));
  }
}
