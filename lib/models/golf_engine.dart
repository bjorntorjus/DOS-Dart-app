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
///
/// A tie for 1st after the final hole sends the tied leaders into sudden
/// death: playoff holes on 19 → 20 → Bull(25) → cycling, same 3-dart/
/// first-hit rules, strokes recorded in [playoffStrokes] only (never
/// [total]/the scorecard). A unique lowest playoff stroke wins; ties carry
/// on to the next target. Roster changes (addPlayer/removePlayer) are
/// implemented in a later task — the stubs below exist so the API compiles.
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

  // sudden death (tied leaders play on: 19 → 20 → Bull → cycling)
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

  /// 1-based placements, tie-shared by total; skipped seats score 0. When
  /// the game was decided by sudden death, the winner is forced to 1st and
  /// the losing co-leaders (same total as the winner) share 2nd — sudden
  /// death only resolves who takes 1st, not the rest of the field.
  List<int> placements() {
    final act = [for (var i = 0; i < playerCount; i++) if (!isSkipped(i)) i];
    final out = List<int>.filled(playerCount, 0);
    for (final i in act) {
      out[i] = 1 + act.where((j) => total(j) < total(i)).length;
    }
    if (wonBySuddenDeath && winnerIndex != null) {
      for (final i in act) {
        if (i != winnerIndex && total(i) == total(winnerIndex!)) out[i] = 2;
      }
      out[winnerIndex!] = 1;
    }
    return out;
  }

  // mutations

  /// 0 = miss, 1 = S, 2 = D, 3 = T. Bull (target 25, sudden death only) has
  /// no triple — the input layer must offer S/D only, and this is the
  /// backstop.
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
    assert(
      !(targetNumber == 25 && multiplier > 2),
      'Bull has no triple',
    );

    _undoStack.add(_GolfUndoEntry(this));

    if (inSuddenDeath) return _applyPlayoffDart(multiplier);

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
        suddenDeathStarted: inSuddenDeath,
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
        suddenDeathStarted: inSuddenDeath,
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

  /// Plays one dart of a playoff hole for the current participant. Playoff
  /// strokes are recorded in [playoffStrokes] only — regulation scorecards
  /// and [total] are never touched here.
  GolfDartResult _applyPlayoffDart(int multiplier) {
    final seat = currentPlayerIndex;
    final wasHit = multiplier > 0;

    if (wasHit) {
      final strokes = (4 - multiplier) + missesThisHole;
      playoffStrokes[seat] = strokes;
      return _advancePlayoffTurn(wasHit: true, strokes: strokes);
    }

    missesThisHole++;
    if (missesThisHole >= 3) {
      const strokes = 6;
      playoffStrokes[seat] = strokes;
      return _advancePlayoffTurn(wasHit: false, strokes: strokes);
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

  /// Moves to the next participant in seat order, or evaluates the playoff
  /// hole once the last participant has thrown.
  GolfDartResult _advancePlayoffTurn({
    required bool wasHit,
    required int strokes,
  }) {
    missesThisHole = 0;
    final idx = playoffParticipants.indexOf(currentPlayerIndex);
    if (idx == playoffParticipants.length - 1) {
      return _evaluatePlayoffHole(wasHit: wasHit, strokes: strokes);
    }
    currentPlayerIndex = playoffParticipants[idx + 1];
    return GolfDartResult(
      wasHit: wasHit,
      holeEnded: true,
      holeStrokes: strokes,
      suddenDeathStarted: false,
      playoffContinued: false,
      gameOver: false,
    );
  }

  /// Every participant has thrown this playoff hole. A unique lowest stroke
  /// wins outright; otherwise the tied-lowest carry on to the next target.
  GolfDartResult _evaluatePlayoffHole({
    required bool wasHit,
    required int strokes,
  }) {
    var minStroke = playoffStrokes[playoffParticipants.first]!;
    for (final p in playoffParticipants) {
      final s = playoffStrokes[p]!;
      if (s < minStroke) minStroke = s;
    }
    final lowest = [
      for (final p in playoffParticipants) if (playoffStrokes[p] == minStroke) p,
    ];

    if (lowest.length == 1) {
      gameOver = true;
      winnerIndex = lowest.first;
      wonBySuddenDeath = true;
      return GolfDartResult(
        wasHit: wasHit,
        holeEnded: true,
        holeStrokes: strokes,
        suddenDeathStarted: false,
        playoffContinued: false,
        gameOver: true,
      );
    }

    playoffParticipants
      ..clear()
      ..addAll(lowest);
    playoffHole++;
    for (var i = 0; i < playoffStrokes.length; i++) {
      playoffStrokes[i] = null;
    }
    currentPlayerIndex = playoffParticipants.first;
    missesThisHole = 0;
    return GolfDartResult(
      wasHit: wasHit,
      holeEnded: true,
      holeStrokes: strokes,
      suddenDeathStarted: false,
      playoffContinued: true,
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
    if (leaders.length == 1) {
      gameOver = true;
      winnerIndex = leaders.first;
      wonBySuddenDeath = false;
      return;
    }

    // Tied for 1st: only the leaders play on, starting on 19.
    inSuddenDeath = true;
    playoffHole = 0;
    playoffParticipants
      ..clear()
      ..addAll(leaders);
    for (var i = 0; i < playoffStrokes.length; i++) {
      playoffStrokes[i] = null;
    }
    currentPlayerIndex = leaders.first;
    missesThisHole = 0;
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
