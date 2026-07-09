/// Pure Gotcha game logic — no Flutter dependencies.
///
/// Race from 0 to an exact [target]. Landing your running total exactly on a
/// living opponent's total resets them to 0 (GOTCHA). Overshooting the target
/// busts: the thrower reverts to their score at the start of the turn, but
/// kills already resolved this turn stand (spec §2).
library;

class GotchaDartResult {
  final int points;
  final List<int> killed;
  final bool isBust;
  final bool turnEnded;
  final bool playerWon;
  const GotchaDartResult({
    required this.points,
    required this.killed,
    required this.isBust,
    required this.turnEnded,
    required this.playerWon,
  });
}

/// Snapshot of the full mutable state, taken before a dart is applied so that
/// [GotchaEngine.undo] can restore it byte-for-byte — including opponents'
/// totals killed by the dart and all per-player counters. Roster changes clear
/// the undo stack (same contract as CricketEngine).
class _GotchaUndoEntry {
  final List<int> totals;
  final List<int> killsMade;
  final List<int> timesKilled;
  final List<int> busts;
  final int currentPlayerIndex;
  final int dartsInTurn;
  final int turnStartScore;
  final bool gameOver;
  final int? winnerIndex;
  final int round;
  final List<({int round, int attacker, int victim})> killLog;
  _GotchaUndoEntry({
    required this.totals,
    required this.killsMade,
    required this.timesKilled,
    required this.busts,
    required this.currentPlayerIndex,
    required this.dartsInTurn,
    required this.turnStartScore,
    required this.gameOver,
    required this.winnerIndex,
    required this.round,
    required this.killLog,
  });
}

class GotchaEngine {
  final int target;

  /// Setup option: kills reset the victim to 0 (v1 behavior) instead of the
  /// default halving.
  final bool hardcore;

  late List<int> totals;
  late List<int> killsMade;
  late List<int> timesKilled;
  late List<int> busts;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;

  /// The current player's total when their turn began — bust reverts to this.
  int turnStartScore = 0;
  bool gameOver = false;
  int? winnerIndex;

  /// 0-based rotation counter, incremented whenever the seat rotation wraps
  /// back around (mirrors the screen's `_roundNumber`). Snapshot-restored.
  int round = 0;

  /// Event-sourced kill history — one entry per victim per kill, in
  /// chronological order. Snapshot-copied (undo removes trailing entries);
  /// NOT cleared on roster changes (history stands even after a player
  /// leaves).
  final List<({int round, int attacker, int victim})> killLog = [];

  final Set<int> _skipped = {};
  final List<_GotchaUndoEntry> _undoStack = [];

  int get playerCount => totals.length;

  GotchaEngine(
      {required this.target, required int playerCount, this.hardcore = false}) {
    totals = List.filled(playerCount, 0, growable: true);
    killsMade = List.filled(playerCount, 0, growable: true);
    timesKilled = List.filled(playerCount, 0, growable: true);
    busts = List.filled(playerCount, 0, growable: true);
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool isSkipped(int index) => _skipped.contains(index);
  Set<int> get skippedIndices => Set.unmodifiable(_skipped);

  int get activePlayerCount {
    int count = 0;
    for (int i = 0; i < playerCount; i++) {
      if (!_skipped.contains(i)) count++;
    }
    return count;
  }

  /// Simplest single-dart notation for [value], or null when no single dart
  /// scores it. Preference: single > 25/BULL > double > triple (spec §3.2).
  static String? singleDartLabel(int value) {
    if (value >= 1 && value <= 20) return 'S$value';
    if (value == 25) return '25';
    if (value == 50) return 'BULL';
    if (value >= 2 && value <= 40 && value.isEven) return 'D${value ~/ 2}';
    if (value >= 3 && value <= 60 && value % 3 == 0) return 'T${value ~/ 3}';
    return null;
  }

  /// Kill tips for the current player: one (dartLabel, opponentIndex) per
  /// living opponent reachable with exactly one dart. Dead (0) opponents and
  /// opponents at or below the thrower are excluded (spec §3.2).
  List<(String, int)> killTips() {
    if (gameOver) return const [];
    final out = <(String, int)>[];
    for (int j = 0; j < playerCount; j++) {
      if (j == currentPlayerIndex || _skipped.contains(j)) continue;
      if (totals[j] <= 0) continue;
      final diff = totals[j] - totals[currentPlayerIndex];
      if (diff <= 0) continue;
      final label = singleDartLabel(diff);
      if (label != null) out.add((label, j));
    }
    return out;
  }

  /// Apply one dart for the current player.
  GotchaDartResult applyDart(int segment, int multiplier) {
    assert(!gameOver, 'applyDart called after game over');

    _undoStack.add(_GotchaUndoEntry(
      totals: List.of(totals),
      killsMade: List.of(killsMade),
      timesKilled: List.of(timesKilled),
      busts: List.of(busts),
      currentPlayerIndex: currentPlayerIndex,
      dartsInTurn: dartsInTurn,
      turnStartScore: turnStartScore,
      gameOver: gameOver,
      winnerIndex: winnerIndex,
      round: round,
      killLog: List.of(killLog),
    ));

    final points = segment * multiplier;
    final newTotal = totals[currentPlayerIndex] + points;
    var isBust = false;
    var playerWon = false;
    final killed = <int>[];

    if (newTotal > target) {
      // Bust: revert to the turn baseline. A bust dart can never kill —
      // newTotal > target > every living opponent's total (spec §7).
      isBust = true;
      totals[currentPlayerIndex] = turnStartScore;
      busts[currentPlayerIndex]++;
    } else {
      totals[currentPlayerIndex] = newTotal;
      if (points > 0) {
        // Kill check — scoring darts only: a 0-point miss leaves the total
        // where it was and does not "land on" anything (documented decision).
        for (int j = 0; j < playerCount; j++) {
          if (j == currentPlayerIndex || _skipped.contains(j)) continue;
          if (totals[j] == newTotal && totals[j] > 0) {
            // Default: HALVING (integer floor — 1 halves to 0, so halving
            // can finish a player). Hardcore setup option keeps the v1
            // reset-to-0.
            totals[j] = hardcore ? 0 : totals[j] ~/ 2;
            timesKilled[j]++;
            killed.add(j);
            killLog.add((round: round, attacker: currentPlayerIndex, victim: j));
          }
        }
        killsMade[currentPlayerIndex] += killed.length;
      }
      if (newTotal == target) {
        playerWon = true;
        gameOver = true;
        winnerIndex = currentPlayerIndex;
      }
    }

    dartsInTurn++;
    final turnEnded = isBust || playerWon || dartsInTurn >= 3;
    if (turnEnded && !gameOver) {
      final previousIndex = currentPlayerIndex;
      dartsInTurn = 0;
      _advancePlayer();
      if (currentPlayerIndex <= previousIndex) round++;
      turnStartScore = totals[currentPlayerIndex];
    }

    return GotchaDartResult(
      points: points,
      killed: killed,
      isBust: isBust,
      turnEnded: turnEnded,
      playerWon: playerWon,
    );
  }

  /// Advance to the next non-removed player. Guards against wrapping forever
  /// when every other seat is removed (same F7 guard as CricketEngine).
  void _advancePlayer() {
    final startIndex = currentPlayerIndex;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
      if (currentPlayerIndex == startIndex) break;
    } while (_skipped.contains(currentPlayerIndex));
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    totals = entry.totals;
    killsMade = entry.killsMade;
    timesKilled = entry.timesKilled;
    busts = entry.busts;
    currentPlayerIndex = entry.currentPlayerIndex;
    dartsInTurn = entry.dartsInTurn;
    turnStartScore = entry.turnStartScore;
    gameOver = entry.gameOver;
    winnerIndex = entry.winnerIndex;
    round = entry.round;
    killLog
      ..clear()
      ..addAll(entry.killLog);
  }

  void clearUndoStack() => _undoStack.clear();

  /// Add a mid-game joiner (at the table average, like Shanghai) and clear the
  /// undo stack — snapshots have the old list lengths.
  void addPlayer({int initialScore = 0}) {
    totals.add(initialScore.clamp(0, target - 1));
    killsMade.add(0);
    timesKilled.add(0);
    busts.add(0);
    _undoStack.clear();
  }

  /// Remove [index] mid-game: mark skipped, advance off the seat when current,
  /// end the game when ≤1 active player remains (survivor wins). Clears undo.
  void removePlayer(int index) {
    if (_skipped.contains(index)) return;
    _skipped.add(index);
    _undoStack.clear();

    if (index == currentPlayerIndex && !gameOver) {
      dartsInTurn = 0;
      _advancePlayer();
      // Note: round counter is NOT wrap-incremented here. Roster-changed games
      // skip achievement derivation entirely (early-return in stats), so
      // killLog round drift is unreachable. Revisit if that gate ever loosens.
      turnStartScore = totals[currentPlayerIndex];
    }

    final remaining = List.generate(playerCount, (i) => i)
        .where((i) => !_skipped.contains(i))
        .toList();
    if (remaining.length <= 1) {
      winnerIndex = remaining.isEmpty ? null : remaining.first;
      gameOver = true;
    }
  }
}
