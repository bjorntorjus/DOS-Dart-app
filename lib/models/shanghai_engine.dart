enum HitType { single, double_, triple, miss }

class _UndoEntry {
  final int playerIndex;
  final int dartNumberBefore;
  final int currentRoundBefore;
  final int currentPlayerIndexBefore;
  final HitType hitType;
  final int pointsDelta;
  final Set<HitType> currentTurnHitsBefore;
  final bool gameOverBefore;
  final int? winnerIndexBefore;
  final bool isInstantShanghaiBefore;

  _UndoEntry({
    required this.playerIndex,
    required this.dartNumberBefore,
    required this.currentRoundBefore,
    required this.currentPlayerIndexBefore,
    required this.hitType,
    required this.pointsDelta,
    required this.currentTurnHitsBefore,
    required this.gameOverBefore,
    required this.winnerIndexBefore,
    required this.isInstantShanghaiBefore,
  });
}

/// Pure rules engine for Shanghai. No UI, no I/O. Unit-testable.
class ShanghaiGameEngine {
  final int targetEnd;
  final List<int> totalScores;

  int currentRound = 0;
  int currentPlayerIndex = 0;
  int dartNumber = 0;
  Set<HitType> currentTurnHits = {};
  bool gameOver = false;
  int? winnerIndex;
  bool isInstantShanghai = false;
  bool isTie = false;

  final Set<int> _skipped = {};
  final List<_UndoEntry> _undoStack = [];

  ShanghaiGameEngine({required int playerCount, required this.targetEnd})
      : totalScores = List<int>.filled(playerCount, 0, growable: true);

  int get currentTarget => currentRound + 1;
  int get playerCount => totalScores.length;
  bool isSkipped(int i) => _skipped.contains(i);
  int get activePlayerCount => playerCount - _skipped.length;

  int _multiplierFor(HitType type) {
    switch (type) {
      case HitType.single:
        return 1;
      case HitType.double_:
        return 2;
      case HitType.triple:
        return 3;
      case HitType.miss:
        return 0;
    }
  }

  void recordThrow(HitType type) {
    if (gameOver) return;

    final multiplier = _multiplierFor(type);
    final points = multiplier * currentTarget;

    _undoStack.add(_UndoEntry(
      playerIndex: currentPlayerIndex,
      dartNumberBefore: dartNumber,
      currentRoundBefore: currentRound,
      currentPlayerIndexBefore: currentPlayerIndex,
      hitType: type,
      pointsDelta: points,
      currentTurnHitsBefore: Set<HitType>.from(currentTurnHits),
      gameOverBefore: gameOver,
      winnerIndexBefore: winnerIndex,
      isInstantShanghaiBefore: isInstantShanghai,
    ));

    totalScores[currentPlayerIndex] += points;
    if (type != HitType.miss) currentTurnHits.add(type);
    dartNumber++;

    if (dartNumber == 3) {
      final hasS = currentTurnHits.contains(HitType.single);
      final hasD = currentTurnHits.contains(HitType.double_);
      final hasT = currentTurnHits.contains(HitType.triple);
      if (hasS && hasD && hasT) {
        isInstantShanghai = true;
        gameOver = true;
        winnerIndex = currentPlayerIndex;
        return;
      }
      _advanceTurn();
    }
  }

  void _advanceTurn() {
    dartNumber = 0;
    currentTurnHits = {};
    _advanceToNextActive();
  }

  void _advanceToNextActive() {
    if (activePlayerCount == 0) {
      gameOver = true;
      return;
    }
    int safety = 0;
    while (safety <= playerCount + 1) {
      currentPlayerIndex++;
      if (currentPlayerIndex >= playerCount) {
        currentPlayerIndex = 0;
        currentRound++;
        if (currentRound >= targetEnd) {
          _endGameByScore();
          return;
        }
      }
      if (!_skipped.contains(currentPlayerIndex)) return;
      safety++;
    }
  }

  void _endGameByScore() {
    gameOver = true;
    if (totalScores.isEmpty) return;
    int? maxScore;
    for (int i = 0; i < totalScores.length; i++) {
      if (_skipped.contains(i)) continue;
      if (maxScore == null || totalScores[i] > maxScore) maxScore = totalScores[i];
    }
    if (maxScore == null) return;
    final winners = <int>[];
    for (int i = 0; i < totalScores.length; i++) {
      if (_skipped.contains(i)) continue;
      if (totalScores[i] == maxScore) winners.add(i);
    }
    if (winners.length == 1) {
      winnerIndex = winners.first;
    } else {
      winnerIndex = null;
      isTie = true;
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    totalScores[entry.playerIndex] -= entry.pointsDelta;
    currentRound = entry.currentRoundBefore;
    currentPlayerIndex = entry.currentPlayerIndexBefore;
    dartNumber = entry.dartNumberBefore;
    currentTurnHits = entry.currentTurnHitsBefore;
    gameOver = entry.gameOverBefore;
    winnerIndex = entry.winnerIndexBefore;
    isInstantShanghai = entry.isInstantShanghaiBefore;
    isTie = false;
  }

  void addPlayer({int initialScore = 0}) {
    totalScores.add(initialScore);
    _undoStack.clear();
  }

  void removePlayer(int index) {
    if (_skipped.contains(index)) return;
    _skipped.add(index);
    _undoStack.clear();
    if (gameOver) return;
    if (activePlayerCount == 0) {
      gameOver = true;
      return;
    }
    if (currentPlayerIndex == index) {
      dartNumber = 0;
      currentTurnHits = {};
      _advanceToNextActive();
    }
  }

  void clearUndoStack() => _undoStack.clear();
}
