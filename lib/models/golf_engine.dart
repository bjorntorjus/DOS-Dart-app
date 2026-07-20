/// Golf term for a hole's stroke score (1-6).
String golfTerm(int strokes) => const {
      1: 'ACE',
      2: 'BIRDIE',
      3: 'PAR',
      4: 'BOGEY',
      5: 'DOUBLE BOGEY',
      6: 'TRIPLE BOGEY',
    }[strokes]!;

class GolfDartResult {
  final bool wasHit; // multiplier > 0
  final bool holeEnded; // hit landed or 3rd miss
  final int? holeStrokes; // 1-6, set when holeEnded
  final bool suddenDeathStarted; // regulation just ended tied for 1st
  final bool playoffContinued; // playoff hole resolved but still tied → next target
  final bool gameOver;

  const GolfDartResult({
    required this.wasHit,
    required this.holeEnded,
    required this.holeStrokes,
    required this.suddenDeathStarted,
    required this.playoffContinued,
    required this.gameOver,
  });
}

class _GolfUndoEntry {
  final int currentHole;
  final int currentPlayerIndex;
  final int missesThisHole;
  final List<List<int?>> scorecards;
  final bool gameOver;
  final int? winnerIndex;
  final bool wonBySuddenDeath;
  final bool inSuddenDeath;
  final int playoffHole;
  final List<int> playoffParticipants;
  final List<int?> playoffStrokes;
  final List<int> aces;
  final List<int> bogeys;
  final List<int> firstDartHits;
  final List<int> dartsThrown;
  final List<int?> bestHole;
  final Set<int> skipped;

  _GolfUndoEntry(GolfEngine e)
      : currentHole = e.currentHole,
        currentPlayerIndex = e.currentPlayerIndex,
        missesThisHole = e.missesThisHole,
        scorecards = [for (final row in e.scorecards) List<int?>.of(row)],
        gameOver = e.gameOver,
        winnerIndex = e.winnerIndex,
        wonBySuddenDeath = e.wonBySuddenDeath,
        inSuddenDeath = e.inSuddenDeath,
        playoffHole = e.playoffHole,
        playoffParticipants = List.of(e.playoffParticipants),
        playoffStrokes = List.of(e.playoffStrokes),
        aces = List.of(e.aces),
        bogeys = List.of(e.bogeys),
        firstDartHits = List.of(e.firstDartHits),
        dartsThrown = List.of(e.dartsThrown),
        bestHole = List.of(e.bestHole),
        skipped = Set.of(e._skipped);
}

/// Golf: each hole is one number, hole ends on the first hit. Strokes = the
/// hit's value (T=1, D=2, S=3) plus one per miss before it; three misses in a
/// row costs 6 (TRIPLE BOGEY). Lowest total after all holes wins.
///
/// Rotation mirrors Shanghai: every player finishes the current hole before
/// anyone starts the next one; wrapping past the last seat advances the hole.
/// Sudden death (tied regulation) and roster changes (addPlayer/removePlayer)
/// are implemented in later tasks — the fields/methods below exist so the
/// API compiles, but this engine only plays out regulation.
class GolfEngine {
  GolfEngine({required int playerCount, required this.holes})
      : scorecards = List.generate(
          playerCount,
          (_) => List<int?>.filled(holes, null, growable: true),
          growable: true,
        ),
        aces = List<int>.filled(playerCount, 0, growable: true),
        bogeys = List<int>.filled(playerCount, 0, growable: true),
        firstDartHits = List<int>.filled(playerCount, 0, growable: true),
        dartsThrown = List<int>.filled(playerCount, 0, growable: true),
        bestHole = List<int?>.filled(playerCount, null, growable: true),
        playoffStrokes = List<int?>.filled(playerCount, null, growable: true);

  final int holes; // 9 | 18

  // regulation state
  int currentHole = 0; // 0-based
  int currentPlayerIndex = 0;
  int missesThisHole = 0; // current thrower's misses this hole (0-2)
  final List<List<int?>> scorecards; // [seat][hole], null = not played
  bool gameOver = false;
  int? winnerIndex;
  bool wonBySuddenDeath = false;

  // sudden death (Task 2)
  bool inSuddenDeath = false;
  int playoffHole = 0; // 0-based playoff round
  int get playoffTarget => const [19, 20, 25][playoffHole % 3]; // 25 = Bull
  final List<int> playoffParticipants = []; // seats still tied, seat order
  final List<int?> playoffStrokes; // length playerCount, null = not thrown

  final Set<int> _skipped = {};
  final List<_GolfUndoEntry> _undoStack = [];

  // per-seat stats (index-stable, grow on addPlayer)
  final List<int> aces;
  final List<int> bogeys; // strokes >= 4
  final List<int> firstDartHits;
  final List<int> dartsThrown;
  final List<int?> bestHole; // lowest hole score, null until first hole done

  // queries
  int get playerCount => scorecards.length;
  int get activePlayerCount => playerCount - _skipped.length;
  int get holeNumber => currentHole + 1;
  int get targetNumber => inSuddenDeath ? playoffTarget : holeNumber;
  bool get canUndo => _undoStack.isNotEmpty;
  bool isSkipped(int i) => _skipped.contains(i);
  Set<int> get skippedIndices => Set.unmodifiable(_skipped);

  /// Regulation strokes so far (playoff excluded).
  int total(int seat) =>
      scorecards[seat].fold(0, (sum, s) => sum + (s ?? 0));

  int holesCompleted(int seat) =>
      scorecards[seat].where((s) => s != null).length;

  int vsPar(int seat) => total(seat) - 3 * holesCompleted(seat);

  /// 1-based placements, tie-shared; skipped seats score 0.
  List<int> placements() {
    final active = [
      for (var i = 0; i < playerCount; i++) if (!_skipped.contains(i)) i,
    ];
    final sorted = List.of(active)
      ..sort((a, b) => total(a).compareTo(total(b)));
    final result = List<int>.filled(playerCount, 0);
    var place = 1;
    for (var rank = 0; rank < sorted.length; rank++) {
      if (rank > 0 && total(sorted[rank]) != total(sorted[rank - 1])) {
        place = rank + 1;
      }
      result[sorted[rank]] = place;
    }
    return result;
  }

  // mutations

  /// 0 = miss, 1 = S, 2 = D, 3 = T.
  GolfDartResult applyDart(int multiplier) {
    if (gameOver) {
      return const GolfDartResult(
        wasHit: false,
        holeEnded: false,
        holeStrokes: null,
        suddenDeathStarted: false,
        playoffContinued: false,
        gameOver: true,
      );
    }

    _undoStack.add(_GolfUndoEntry(this));

    final seat = currentPlayerIndex;
    dartsThrown[seat]++;
    final wasHit = multiplier > 0;

    if (wasHit) {
      final strokes = (4 - multiplier) + missesThisHole;
      if (missesThisHole == 0) firstDartHits[seat]++;
      _finishHole(seat, strokes);
      _advanceToNextActive();
      return GolfDartResult(
        wasHit: true,
        holeEnded: true,
        holeStrokes: strokes,
        suddenDeathStarted: false,
        playoffContinued: false,
        gameOver: gameOver,
      );
    }

    missesThisHole++;
    if (missesThisHole >= 3) {
      const strokes = 6;
      _finishHole(seat, strokes);
      _advanceToNextActive();
      return GolfDartResult(
        wasHit: false,
        holeEnded: true,
        holeStrokes: strokes,
        suddenDeathStarted: false,
        playoffContinued: false,
        gameOver: gameOver,
      );
    }

    return const GolfDartResult(
      wasHit: false,
      holeEnded: false,
      holeStrokes: null,
      suddenDeathStarted: false,
      playoffContinued: false,
      gameOver: false,
    );
  }

  void _finishHole(int seat, int strokes) {
    scorecards[seat][currentHole] = strokes;
    if (strokes == 1) aces[seat]++;
    if (strokes >= 4) bogeys[seat]++;
    if (bestHole[seat] == null || strokes < bestHole[seat]!) {
      bestHole[seat] = strokes;
    }
  }

  /// Resets misses and moves to the next non-skipped seat; wrapping past the
  /// last seat advances the hole, and finishing the last hole ends the game.
  void _advanceToNextActive() {
    missesThisHole = 0;
    if (activePlayerCount == 0) {
      gameOver = true;
      return;
    }
    var safety = 0;
    while (safety <= playerCount + 1) {
      currentPlayerIndex++;
      if (currentPlayerIndex >= playerCount) {
        currentPlayerIndex = 0;
        currentHole++;
        if (currentHole >= holes) {
          _evaluateRegulationEnd();
          return;
        }
      }
      if (!_skipped.contains(currentPlayerIndex)) return;
      safety++;
    }
  }

  void _evaluateRegulationEnd() {
    final active = [
      for (var i = 0; i < playerCount; i++) if (!_skipped.contains(i)) i,
    ];
    var minTotal = total(active.first);
    for (final i in active) {
      final t = total(i);
      if (t < minTotal) minTotal = t;
    }
    final leaders = [for (final i in active) if (total(i) == minTotal) i];
    assert(leaders.length == 1, 'Tied regulation end — sudden death is Task 2');
    gameOver = true;
    winnerIndex = leaders.first;
    wonBySuddenDeath = false;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final s = _undoStack.removeLast();
    currentHole = s.currentHole;
    currentPlayerIndex = s.currentPlayerIndex;
    missesThisHole = s.missesThisHole;
    for (var i = 0; i < scorecards.length; i++) {
      scorecards[i] = List<int?>.of(s.scorecards[i]);
    }
    gameOver = s.gameOver;
    winnerIndex = s.winnerIndex;
    wonBySuddenDeath = s.wonBySuddenDeath;
    inSuddenDeath = s.inSuddenDeath;
    playoffHole = s.playoffHole;
    playoffParticipants
      ..clear()
      ..addAll(s.playoffParticipants);
    for (var i = 0; i < playoffStrokes.length; i++) {
      playoffStrokes[i] = s.playoffStrokes[i];
    }
    for (var i = 0; i < aces.length; i++) {
      aces[i] = s.aces[i];
      bogeys[i] = s.bogeys[i];
      firstDartHits[i] = s.firstDartHits[i];
      dartsThrown[i] = s.dartsThrown[i];
      bestHole[i] = s.bestHole[i];
    }
    _skipped
      ..clear()
      ..addAll(s.skipped);
  }

  void clearUndoStack() => _undoStack.clear();

  /// New seat joins with empty stats and an empty scorecard row. Full
  /// mid-game join handling (rotation, sudden-death interaction) is Task 3.
  void addPlayer() {
    scorecards.add(List<int?>.filled(holes, null, growable: true));
    aces.add(0);
    bogeys.add(0);
    firstDartHits.add(0);
    dartsThrown.add(0);
    bestHole.add(null);
    playoffStrokes.add(null);
    _undoStack.clear();
  }

  /// Marks seat [index] skipped. Full placement/rotation/sudden-death
  /// interaction for a removed seat is Task 3.
  void removePlayer(int index) {
    _skipped.add(index);
    _undoStack.clear();
  }
}
