import 'dart:math';

enum OneUpVariant { beatTheLast, survivor }

class OneUpDartResult {
  final int points;
  final bool turnEnded;
  final bool lostLife;
  final bool eliminated;
  final bool playerWon;
  final int? roundWonBy; // seat that just won the round (survivor only)
  const OneUpDartResult({
    required this.points,
    required this.turnEnded,
    required this.lostLife,
    required this.eliminated,
    required this.playerWon,
    this.roundWonBy,
  });
}

class _OneUpUndoEntry {
  final List<int> livesLeft;
  final List<int> eliminationOrder;
  final List<int> order;
  final int orderPos;
  final int starterCursor;
  final int roundNumber;
  final int dartsInTurn;
  final int turnPoints;
  final int? target;
  final int targetSetBy;
  final bool gameOver;
  final int? winnerIndex;
  final Set<int> outOfRound;
  final List<int> livesLost;
  final List<int> targetsSet;
  final List<int> highestTurn;
  final List<int> turnsSurvived;
  final List<int> lastDartSaves;
  final List<int> elimsDealt;
  final List<int> roundsWon;

  _OneUpUndoEntry(OneUpEngine e)
      : livesLeft = List.of(e.livesLeft),
        eliminationOrder = List.of(e.eliminationOrder),
        order = List.of(e._order),
        orderPos = e._orderPos,
        starterCursor = e._starterCursor,
        roundNumber = e.roundNumber,
        dartsInTurn = e.dartsInTurn,
        turnPoints = e.turnPoints,
        target = e.target,
        targetSetBy = e.targetSetBy,
        gameOver = e.gameOver,
        winnerIndex = e.winnerIndex,
        outOfRound = Set.of(e._outOfRound),
        livesLost = List.of(e.livesLost),
        targetsSet = List.of(e.targetsSet),
        highestTurn = List.of(e.highestTurn),
        turnsSurvived = List.of(e.turnsSurvived),
        lastDartSaves = List.of(e.lastDartSaves),
        elimsDealt = List.of(e.elimsDealt),
        roundsWon = List.of(e.roundsWon);
}

/// 1UP: match or beat the target or lose a life. Last player standing wins.
/// Tie = success (turnTotal >= target is safe). A turn is always 3 darts.
///
/// BEAT THE LAST: one continuous target through the whole game.
/// SURVIVOR: round-based last-man-standing — the rotation loops among the
/// in-round players until one remains (the round winner); a fail costs a life
/// and ejects the player from the rest of the round.
class OneUpEngine {
  OneUpEngine({
    required int playerCount,
    required this.startingLives,
    this.variant = OneUpVariant.beatTheLast,
    this.randomOrder = false,
    Random? rng,
  })  : _rng = rng ?? Random(),
        livesLeft = List<int>.filled(playerCount, startingLives, growable: true),
        livesLost = List<int>.filled(playerCount, 0, growable: true),
        targetsSet = List<int>.filled(playerCount, 0, growable: true),
        highestTurn = List<int>.filled(playerCount, 0, growable: true),
        turnsSurvived = List<int>.filled(playerCount, 0, growable: true),
        lastDartSaves = List<int>.filled(playerCount, 0, growable: true),
        elimsDealt = List<int>.filled(playerCount, 0, growable: true),
        roundsWon = List<int>.filled(playerCount, 0, growable: true) {
    _order = _buildRoundOrder();
  }

  final int startingLives;
  final OneUpVariant variant;
  final bool randomOrder;
  final Random _rng;

  final List<int> livesLeft;
  final List<int> eliminationOrder = [];
  final Set<int> _skipped = {};
  final Set<int> _outOfRound = {}; // SURVIVOR: seats out of the current round
  late List<int> _order; // turn sequence for the current round
  int _orderPos = 0;
  int _starterCursor = 0; // SURVIVOR round-robin starter (randomOrder off)
  int roundNumber = 1;
  int dartsInTurn = 0;
  int turnPoints = 0;
  int? target; // null = free throw
  int targetSetBy = -1;
  bool gameOver = false;
  int? winnerIndex;

  final List<int> livesLost;
  final List<int> targetsSet;
  final List<int> highestTurn;
  final List<int> turnsSurvived;
  final List<int> lastDartSaves;
  final List<int> elimsDealt;
  final List<int> roundsWon; // SURVIVOR: rounds won per seat

  final List<_OneUpUndoEntry> _undoStack = [];

  int get playerCount => livesLeft.length;
  int get currentPlayerIndex => _order[_orderPos];
  bool get canUndo => _undoStack.isNotEmpty;
  bool isSkipped(int i) => _skipped.contains(i);
  Set<int> get skippedIndices => Set.unmodifiable(_skipped);
  bool isEliminated(int i) => livesLeft[i] <= 0;
  bool isAlive(int i) => !isSkipped(i) && !isEliminated(i);
  List<int> get aliveIndices =>
      [for (var i = 0; i < playerCount; i++) if (isAlive(i)) i];
  int get activePlayerCount => aliveIndices.length;
  List<int> get roundOrder => List.unmodifiable(_order);

  // SURVIVOR: a seat is in-round iff it is in the current order, alive, and
  // not knocked out of the round. A mid-game addPlayer (not yet in `_order`)
  // is therefore NOT in-round and cannot block round completion.
  bool isOutOfRound(int i) => _outOfRound.contains(i);
  Set<int> get outOfRoundIndices => Set.unmodifiable(_outOfRound);
  bool _inRound(int i) =>
      _order.contains(i) && isAlive(i) && !_outOfRound.contains(i);
  List<int> get _inRoundIndices =>
      [for (final s in _order) if (isAlive(s) && !_outOfRound.contains(s)) s];

  bool get isFreeThrow => target == null;
  int get needed => target == null ? 0 : max(0, target! - turnPoints);
  bool get canStillBeat =>
      target == null || (target! - turnPoints) <= 60 * (3 - dartsInTurn);
  bool get hasBeatenTarget => target != null && turnPoints >= target!;

  OneUpDartResult applyDart(int segment, int multiplier) {
    if (gameOver) {
      return const OneUpDartResult(
          points: 0, turnEnded: false, lostLife: false,
          eliminated: false, playerWon: false);
    }
    _undoStack.add(_OneUpUndoEntry(this));
    final points = segment * multiplier;
    final wasBelow = target != null && turnPoints < target!;
    turnPoints += points;
    dartsInTurn++;
    if (dartsInTurn < 3) {
      return OneUpDartResult(
          points: points, turnEnded: false, lostLife: false,
          eliminated: false, playerWon: false);
    }
    return _endTurn(points, wasBelow);
  }

  OneUpDartResult _endTurn(int lastDartPoints, bool wasBelowBeforeLastDart) {
    final me = currentPlayerIndex;
    final total = turnPoints;
    final targetBefore = target;
    var lost = false, elim = false, won = false;

    if (total > highestTurn[me]) highestTurn[me] = total;

    if (targetBefore == null) {
      // free throw sets the bar (game start in LAST, round start in SURVIVOR)
      target = total;
      targetSetBy = me;
      targetsSet[me]++;
      turnsSurvived[me]++;
    } else if (total >= targetBefore) {
      // success — tie leaves the number (and owner in SURVIVOR) unchanged
      if (variant == OneUpVariant.beatTheLast) {
        target = total;
        targetSetBy = me;
        if (total > targetBefore) targetsSet[me]++;
      } else if (total > targetBefore) {
        target = total;
        targetSetBy = me;
        targetsSet[me]++;
      }
      turnsSurvived[me]++;
      if (wasBelowBeforeLastDart) lastDartSaves[me]++;
    } else {
      lost = true;
      // capture the owner BEFORE the fail re-assigns it (LAST variant)
      final ownerBefore = targetSetBy;
      livesLost[me]++;
      livesLeft[me] = livesLeft[me] - 1;
      if (variant == OneUpVariant.beatTheLast) {
        // the lower total still becomes the target (self-correcting)
        target = total;
        targetSetBy = me;
      } else {
        // SURVIVOR: the failer's total is discarded (target unchanged) and
        // they are out of the rest of the round.
        _outOfRound.add(me);
      }
      if (livesLeft[me] <= 0) {
        elim = true;
        eliminationOrder.add(me);
        if (ownerBefore >= 0 && ownerBefore != me) {
          elimsDealt[ownerBefore]++;
        }
        final alive = aliveIndices;
        if (alive.length <= 1) {
          gameOver = true;
          winnerIndex = alive.isEmpty ? null : alive.first;
          won = true;
        }
      }
    }

    int? roundWonBy;
    if (variant == OneUpVariant.survivor) {
      if (gameOver) {
        // gameOver wins over round bookkeeping, but the survivor also
        // survived the round → still credit the round win.
        turnPoints = 0;
        dartsInTurn = 0;
        if (winnerIndex != null) roundsWon[winnerIndex!]++;
      } else {
        final inRound = _inRoundIndices;
        if (inRound.length == 1) {
          roundWonBy = inRound.first;
          roundsWon[roundWonBy]++;
          _startNewRound();
        } else {
          _advance();
        }
      }
    } else {
      _advance();
    }

    return OneUpDartResult(
        points: lastDartPoints, turnEnded: true, lostLife: lost,
        eliminated: elim, playerWon: won, roundWonBy: roundWonBy);
  }

  void _advance() {
    turnPoints = 0;
    dartsInTurn = 0;
    if (gameOver) return;
    if (variant == OneUpVariant.survivor) {
      // Loop to the next in-round seat, wrapping. No roundNumber increment;
      // round-end is handled in _endTurn / removePlayer.
      var next = (_orderPos + 1) % _order.length;
      var guard = 0;
      while (!_inRound(_order[next]) && guard < _order.length) {
        next = (next + 1) % _order.length;
        guard++;
      }
      _orderPos = next;
      return;
    }
    var next = _orderPos + 1;
    while (next < _order.length && !isAlive(_order[next])) {
      next++;
    }
    if (next >= _order.length) {
      roundNumber++;
      _order = _buildRoundOrder();
      _orderPos = 0;
    } else {
      _orderPos = next;
    }
  }

  /// SURVIVOR: start the next round — clear out-of-round, reset the target,
  /// rotate the starter (or reshuffle) and rebuild the order.
  void _startNewRound() {
    turnPoints = 0;
    dartsInTurn = 0;
    roundNumber++;
    _outOfRound.clear();
    target = null;
    targetSetBy = -1;
    if (!randomOrder && _order.isNotEmpty) {
      _starterCursor = (_order.first + 1) % playerCount;
    }
    _order = _buildRoundOrder();
    _orderPos = 0;
  }

  List<int> _buildRoundOrder() {
    final alive = aliveIndices;
    if (alive.isEmpty) return [0]; // unreachable in play; keeps getters safe
    if (randomOrder) {
      alive.shuffle(_rng);
      return alive;
    }
    if (variant == OneUpVariant.survivor) {
      var i = alive.indexWhere((s) => s >= _starterCursor);
      if (i == -1) i = 0;
      return [...alive.sublist(i), ...alive.sublist(0, i)];
    }
    return alive;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final s = _undoStack.removeLast();
    for (var i = 0; i < playerCount; i++) {
      livesLeft[i] = s.livesLeft[i];
      livesLost[i] = s.livesLost[i];
      targetsSet[i] = s.targetsSet[i];
      highestTurn[i] = s.highestTurn[i];
      turnsSurvived[i] = s.turnsSurvived[i];
      lastDartSaves[i] = s.lastDartSaves[i];
      elimsDealt[i] = s.elimsDealt[i];
      roundsWon[i] = s.roundsWon[i];
    }
    eliminationOrder
      ..clear()
      ..addAll(s.eliminationOrder);
    _outOfRound
      ..clear()
      ..addAll(s.outOfRound);
    _order = List.of(s.order);
    _orderPos = s.orderPos;
    _starterCursor = s.starterCursor;
    roundNumber = s.roundNumber;
    dartsInTurn = s.dartsInTurn;
    turnPoints = s.turnPoints;
    target = s.target;
    targetSetBy = s.targetSetBy;
    gameOver = s.gameOver;
    winnerIndex = s.winnerIndex;
  }

  void clearUndoStack() => _undoStack.clear();

  /// New player joins the rotation from the NEXT round with full lives.
  void addPlayer() {
    _undoStack.clear();
    livesLeft.add(startingLives);
    livesLost.add(0);
    targetsSet.add(0);
    highestTurn.add(0);
    turnsSurvived.add(0);
    lastDartSaves.add(0);
    elimsDealt.add(0);
    roundsWon.add(0);
    // _order is rebuilt at the next round boundary and picks them up.
  }

  /// Removes a seat from play. Their last completed throw may still be the
  /// standing target (it is just a number). If they were mid-turn, the
  /// in-progress darts are discarded. Survivor wins when one remains.
  void removePlayer(int index) {
    if (gameOver || _skipped.contains(index)) return;
    _undoStack.clear();
    final wasCurrent = index == currentPlayerIndex;
    _skipped.add(index);
    final alive = aliveIndices;
    if (alive.length <= 1) {
      turnPoints = 0;
      dartsInTurn = 0;
      gameOver = true;
      winnerIndex = alive.isEmpty ? null : alive.first;
      return;
    }
    if (variant == OneUpVariant.survivor) {
      // A removed current thrower's in-progress turn is discarded.
      if (wasCurrent) {
        turnPoints = 0;
        dartsInTurn = 0;
      }
      final inRound = _inRoundIndices;
      if (inRound.length == 1) {
        roundsWon[inRound.first]++;
        _startNewRound();
      } else if (wasCurrent) {
        _advance();
      }
      return;
    }
    if (wasCurrent) {
      _advance(); // resets turnPoints/dartsInTurn and moves off the seat
    }
  }
}
