/// Pure Around the Clock game logic — no Flutter dependencies.
library;

class ATCConfig {
  final bool reverse;
  final bool includeBull;
  final bool countMultiples;

  const ATCConfig({
    this.reverse = false,
    this.includeBull = false,
    this.countMultiples = false,
  });

  int get maxTarget => includeBull ? 25 : 20;
  int get startTarget => reverse ? (includeBull ? 25 : 20) : 1;
}

class ATCThrowResult {
  final bool isHit;
  final bool playerFinished;
  final int newTarget; // current player's target after this throw
  final bool turnEnded;

  const ATCThrowResult({
    required this.isHit,
    required this.playerFinished,
    required this.newTarget,
    required this.turnEnded,
  });
}

class ATCEngine {
  final ATCConfig config;
  final int playerCount;

  late List<int> currentTargets; // one per player
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  final List<int> finishedPlayers = [];
  final Set<int> playersCompletedThisRound = {};
  final List<int> finishedBeforeRound = [];
  int roundNumber = 0;
  bool gameOver = false;
  int? winnerIndex;

  ATCEngine({required this.config, required this.playerCount}) {
    currentTargets = List.filled(playerCount, config.startTarget);
  }

  // ---------------------------------------------------------------------------
  // Pure target navigation
  // ---------------------------------------------------------------------------

  /// Whether [target] means the player has completed all segments.
  bool isFinished(int target) {
    if (config.reverse) return target < 1;
    return target > config.maxTarget;
  }

  /// Advance [target] one step in the correct direction.
  int advanceTarget(int target) {
    if (config.reverse) {
      if (target == 25) return 20; // Bull → 20
      if (target <= 1) return 0; // finished sentinel
      return target - 1;
    } else {
      if (target == 20 && config.includeBull) return 25; // 20 → Bull
      if (target >= config.maxTarget) return config.maxTarget + 1; // finished
      if (target == 25) return 26; // finished after Bull
      return target + 1;
    }
  }

  /// How many segments remain for a player at [target] to finish.
  int segmentsRemaining(int target) {
    if (isFinished(target)) return 0;
    int count = 0;
    int t = target;
    while (!isFinished(t)) {
      t = advanceTarget(t);
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Round state
  // ---------------------------------------------------------------------------

  bool isRoundComplete() {
    for (int i = 0; i < playerCount; i++) {
      if (finishedBeforeRound.contains(i)) continue;
      if (!playersCompletedThisRound.contains(i)) return false;
    }
    return true;
  }

  /// Can any player who hasn't thrown yet finish in [maxDarts] or fewer?
  bool canAnyRemainingPlayerFinish(int maxDarts) {
    final maxSegments = config.countMultiples ? maxDarts * 3 : maxDarts;
    for (int i = 0; i < playerCount; i++) {
      if (finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue;
      if (playersCompletedThisRound.contains(i)) continue;
      if (segmentsRemaining(currentTargets[i]) <= maxSegments) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Stateful game actions
  // ---------------------------------------------------------------------------

  /// Apply a dart throw for the current player.
  ATCThrowResult applyHit(int segment, int multiplier) {
    assert(!finishedPlayers.contains(currentPlayerIndex),
        'Player $currentPlayerIndex has already finished');

    final target = currentTargets[currentPlayerIndex];
    final isHit = segment == target;
    bool playerFinished = false;

    if (isHit) {
      final steps =
          config.countMultiples ? (multiplier == 0 ? 1 : multiplier) : 1;
      int nextTarget = target;
      for (int s = 0; s < steps; s++) {
        nextTarget = advanceTarget(nextTarget);
        if (isFinished(nextTarget)) break;
      }
      currentTargets[currentPlayerIndex] = nextTarget;

      if (isFinished(nextTarget)) {
        finishedPlayers.add(currentPlayerIndex);
        playerFinished = true;
        playersCompletedThisRound.add(currentPlayerIndex);

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
      }
    }

    dartsInTurn++;
    final turnEnded = playerFinished || dartsInTurn >= 3;
    if (turnEnded) {
      if (!playerFinished) {
        playersCompletedThisRound.add(currentPlayerIndex);
      }
      dartsInTurn = 0;
      if (!playerFinished) _advancePlayer();
    }

    return ATCThrowResult(
      isHit: isHit,
      playerFinished: playerFinished,
      newTarget: currentTargets[currentPlayerIndex],
      turnEnded: turnEnded,
    );
  }

  void _advancePlayer() {
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } while (finishedPlayers.contains(currentPlayerIndex));
  }

  void startNewRound() {
    roundNumber++;
    playersCompletedThisRound.clear();
    finishedBeforeRound
      ..clear()
      ..addAll(finishedPlayers);
  }
}
