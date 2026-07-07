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

/// Snapshot of the full mutable state, taken before a dart is applied so that
/// [CricketEngine.undo] can restore it byte-for-byte. Roster changes clear the
/// undo stack, so a snapshot never outlives an add/remove that would invalidate
/// its list lengths.
class _CricketUndoEntry {
  final List<Map<int, int>> marks;
  final List<int> scores;
  final List<int> finishedPlayers;
  final int currentPlayerIndex;
  final int dartsInTurn;
  final bool gameOver;
  final int? winnerIndex;

  _CricketUndoEntry({
    required this.marks,
    required this.scores,
    required this.finishedPlayers,
    required this.currentPlayerIndex,
    required this.dartsInTurn,
    required this.gameOver,
    required this.winnerIndex,
  });
}

class CricketEngine {
  final List<int> targets;
  final bool isCutthroat;

  late List<Map<int, int>> marks; // marks[playerIndex][target] = markCount (0-3+)
  late List<int> scores;
  final List<int> finishedPlayers = [];
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  bool gameOver = false;
  int? winnerIndex;

  /// Players removed mid-game. Skipped players are always also present in
  /// [finishedPlayers]; they are excluded from rotation and winner logic.
  final Set<int> _skipped = {};
  final List<_CricketUndoEntry> _undoStack = [];

  /// Player count is derived from the roster so [addPlayer] / [removePlayer]
  /// grow it correctly.
  int get playerCount => marks.length;

  CricketEngine({
    required this.targets,
    required this.isCutthroat,
    required int playerCount,
  }) {
    marks =
        List.generate(playerCount, (_) => {for (final t in targets) t: 0});
    scores = List.generate(playerCount, (_) => 0);
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
  // Roster / undo introspection
  // ---------------------------------------------------------------------------

  /// Whether [undo] has anything to roll back. Add/remove player clears the
  /// stack, so undo can never cross a roster change.
  bool get canUndo => _undoStack.isNotEmpty;

  bool isSkipped(int index) => _skipped.contains(index);

  Set<int> get skippedIndices => Set.unmodifiable(_skipped);

  /// Players who are neither finished nor removed.
  int get activePlayerCount {
    int count = 0;
    for (int i = 0; i < playerCount; i++) {
      if (!finishedPlayers.contains(i) && !_skipped.contains(i)) count++;
    }
    return count;
  }

  /// First finisher who was not removed mid-game, else null.
  int? winnerIndexExcludingSkipped() {
    for (final i in finishedPlayers) {
      if (!_skipped.contains(i)) return i;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Winner detection
  // ---------------------------------------------------------------------------

  /// Check if [playerIndex] can finish now and mark them as finished.
  /// Returns true if they just finished. Removed (skipped) players are ignored
  /// in the opponent comparison, matching the screen's `_checkWinner`.
  bool checkFinishForPlayer(int playerIndex) {
    if (finishedPlayers.contains(playerIndex)) return false;
    if (!allClosedByPlayer(playerIndex)) return false;

    for (int j = 0; j < playerCount; j++) {
      if (j == playerIndex ||
          finishedPlayers.contains(j) ||
          _skipped.contains(j)) {
        continue;
      }
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
      winnerIndex = winnerIndexExcludingSkipped() ?? finishedPlayers.first;
      gameOver = true;
    } else {
      winnerIndex = winnerIndexExcludingSkipped() ?? finishedPlayers.first;
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

    // Snapshot the full pre-dart state (deep copy of marks) so undo can restore
    // it exactly. Pushed at the very top, before any mutation.
    _undoStack.add(_CricketUndoEntry(
      marks: List<Map<int, int>>.generate(
          marks.length, (i) => Map.of(marks[i])),
      scores: List.of(scores),
      finishedPlayers: List.of(finishedPlayers),
      currentPlayerIndex: currentPlayerIndex,
      dartsInTurn: dartsInTurn,
      gameOver: gameOver,
      winnerIndex: winnerIndex,
    ));

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

  /// Advance to the next player who is neither finished nor removed. Guards
  /// against wrapping all the way around (every seat finished/removed) instead
  /// of spinning forever — the old do/while hung in that case (audit F7).
  void _advancePlayer() {
    final startIndex = currentPlayerIndex;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
      if (currentPlayerIndex == startIndex) break;
    } while (finishedPlayers.contains(currentPlayerIndex) ||
        _skipped.contains(currentPlayerIndex));
  }

  // ---------------------------------------------------------------------------
  // Undo
  // ---------------------------------------------------------------------------

  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    marks = entry.marks;
    scores = entry.scores;
    finishedPlayers
      ..clear()
      ..addAll(entry.finishedPlayers);
    currentPlayerIndex = entry.currentPlayerIndex;
    dartsInTurn = entry.dartsInTurn;
    gameOver = entry.gameOver;
    winnerIndex = entry.winnerIndex;
  }

  void clearUndoStack() => _undoStack.clear();

  // ---------------------------------------------------------------------------
  // Roster mutation
  // ---------------------------------------------------------------------------

  /// Add a player to the roster and clear the undo stack (undo can never
  /// cross a roster change — snapshots have the old list lengths).
  ///
  /// [initialScore] and [initialMarks] let a mid-game joiner start at the
  /// table's average instead of 0/0 (same pattern as the Shanghai engine's
  /// `addPlayer(initialScore:)`). Marks are clamped to 0-3 per target.
  void addPlayer({int initialScore = 0, Map<int, int>? initialMarks}) {
    marks.add({
      for (final t in targets) t: (initialMarks?[t] ?? 0).clamp(0, 3)
    });
    scores.add(initialScore);
    _undoStack.clear();
  }

  /// Remove [index] mid-game. Mirrors the screen's `_performRemovePlayer`:
  /// mark skipped, ensure present in [finishedPlayers], advance off the seat
  /// when it is current, and end the game when one (or zero) active player
  /// remains (audit F7). Clears the undo stack.
  void removePlayer(int index) {
    if (_skipped.contains(index)) return;
    _skipped.add(index);
    if (!finishedPlayers.contains(index)) finishedPlayers.add(index);
    _undoStack.clear();

    if (index == currentPlayerIndex) {
      dartsInTurn = 0;
      _advancePlayer();
    }

    final remaining = List.generate(playerCount, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    if (remaining.length <= 1) {
      if (remaining.length == 1 && !finishedPlayers.contains(remaining.first)) {
        finishedPlayers.add(remaining.first);
      }
      winnerIndex = winnerIndexExcludingSkipped();
      gameOver = true;
    }
  }
}
