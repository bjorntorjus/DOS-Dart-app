/// Pure X01 game logic — no Flutter dependencies.
library;

enum X01ThrowResult { hit, turnEnd, bust, checkout }

class PendingCheckout {
  final int playerIndex;
  final int dartsUsedInTurn;
  final int checkoutScore;

  const PendingCheckout({
    required this.playerIndex,
    required this.dartsUsedInTurn,
    required this.checkoutScore,
  });
}

class X01Engine {
  final String masterOut; // 'none', 'double', 'master'
  final int playerCount;

  late List<int> scores;
  late int _scoreAtStartOfTurn;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  final List<int> finishedPlayers = [];
  final Set<int> playersCompletedThisRound = {};
  final List<int> finishedBeforeRound = [];
  final List<PendingCheckout> pendingCheckouts = [];
  int roundNumber = 0;
  bool gameOver = false;
  int? winnerIndex;

  X01Engine({required this.masterOut, required List<int> initialScores})
      : playerCount = initialScores.length {
    scores = List.from(initialScores);
    _scoreAtStartOfTurn = scores[0];
  }

  // ---------------------------------------------------------------------------
  // Pure / static helpers
  // ---------------------------------------------------------------------------

  /// Whether a throw results in a bust.
  static bool computeIsBust(
      int currentScore, int segment, int multiplier, String masterOut) {
    final points = segment * multiplier;
    final newScore = currentScore - points;

    if (newScore < 0) return true;

    if (masterOut != 'none') {
      if (newScore == 0) {
        final validOut =
            masterOut == 'double' ? multiplier == 2 : multiplier >= 2;
        if (!validOut) return true;
      }
      // Score 1 can never be checked out with double/master out.
      if (newScore == 1) return true;
    }
    return false;
  }

  /// Maximum score checkable in [darts] throws for a given out-rule.
  static int computeMaxCheckoutForDarts(int darts, String masterOut) {
    if (masterOut == 'double') {
      const maxes = [0, 50, 110, 170];
      return darts >= 1 && darts <= 3 ? maxes[darts] : 170;
    } else {
      const maxes = [0, 60, 120, 180];
      return darts >= 1 && darts <= 3 ? maxes[darts] : 180;
    }
  }

  /// Compare two pending checkouts for placement ordering.
  /// Returns negative if [a] should be ranked higher (wins).
  /// Rule 1: fewer darts wins. Rule 2: higher checkout score wins. Rule 3: tie.
  static int compareCheckouts(PendingCheckout a, PendingCheckout b) {
    if (a.dartsUsedInTurn != b.dartsUsedInTurn) {
      return a.dartsUsedInTurn.compareTo(b.dartsUsedInTurn);
    }
    if (a.checkoutScore != b.checkoutScore) {
      return b.checkoutScore.compareTo(a.checkoutScore);
    }
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Instance helpers (use engine state)
  // ---------------------------------------------------------------------------

  bool isBust(int currentScore, int segment, int multiplier) =>
      computeIsBust(currentScore, segment, multiplier, masterOut);

  int maxCheckoutForDarts(int darts) =>
      computeMaxCheckoutForDarts(darts, masterOut);

  /// Whether the current round is complete.
  /// Critical fix: also skips players in [finishedPlayers] (not just
  /// [finishedBeforeRound]) so mid-game removes / same-round checkouts
  /// don't block round completion.
  bool isRoundComplete() {
    for (int i = 0; i < playerCount; i++) {
      if (finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue;
      if (!playersCompletedThisRound.contains(i)) return false;
    }
    return true;
  }

  /// Can any player who hasn't thrown yet this round theoretically check out
  /// in [maxDarts] or fewer darts?
  bool canAnyRemainingPlayerCheckout(int maxDarts) {
    final maxScore = maxCheckoutForDarts(maxDarts);
    for (int i = 0; i < playerCount; i++) {
      if (finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue;
      if (playersCompletedThisRound.contains(i)) continue;
      if (scores[i] <= maxScore && scores[i] > 0) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Stateful game actions
  // ---------------------------------------------------------------------------

  /// Apply a dart throw for the current player. Returns the result type.
  X01ThrowResult applyThrow(int segment, int multiplier) {
    assert(!finishedPlayers.contains(currentPlayerIndex),
        'Player $currentPlayerIndex has already finished');

    final currentScore = scores[currentPlayerIndex];

    if (isBust(currentScore, segment, multiplier)) {
      scores[currentPlayerIndex] = _scoreAtStartOfTurn;
      playersCompletedThisRound.add(currentPlayerIndex);
      dartsInTurn = 0;
      _advancePlayer();
      return X01ThrowResult.bust;
    }

    final points = segment * multiplier;
    final newScore = currentScore - points;

    if (newScore == 0) {
      scores[currentPlayerIndex] = 0;
      finishedPlayers.add(currentPlayerIndex);
      pendingCheckouts.add(PendingCheckout(
        playerIndex: currentPlayerIndex,
        dartsUsedInTurn: dartsInTurn + 1,
        checkoutScore: _scoreAtStartOfTurn,
      ));
      playersCompletedThisRound.add(currentPlayerIndex);
      dartsInTurn = 0;
      return X01ThrowResult.checkout;
    }

    scores[currentPlayerIndex] = newScore;
    dartsInTurn++;
    if (dartsInTurn >= 3) {
      playersCompletedThisRound.add(currentPlayerIndex);
      dartsInTurn = 0;
      _advancePlayer();
      return X01ThrowResult.turnEnd;
    }
    return X01ThrowResult.hit;
  }

  /// Advance to the next active player.
  void _advancePlayer() {
    final start = currentPlayerIndex;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
      if (currentPlayerIndex == start) break;
    } while (finishedPlayers.contains(currentPlayerIndex));
    _scoreAtStartOfTurn = scores[currentPlayerIndex];
  }

  /// Begin a new round (after resolving pending checkouts).
  void startNewRound() {
    roundNumber++;
    playersCompletedThisRound.clear();
    finishedBeforeRound
      ..clear()
      ..addAll(finishedPlayers);
    pendingCheckouts.clear();
  }

  /// Sort pending checkouts by tiebreaker rules and return them.
  List<PendingCheckout> resolveCheckouts() {
    return List<PendingCheckout>.from(pendingCheckouts)
      ..sort(compareCheckouts);
  }
}
