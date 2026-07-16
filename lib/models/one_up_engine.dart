import 'dart:math';

enum OneUpVariant { beatTheLast, beatTheBest }

class OneUpDartResult {
  final int points;
  final bool turnEnded;
  final bool lostLife;
  final bool eliminated;
  final bool playerWon;
  const OneUpDartResult({
    required this.points,
    required this.turnEnded,
    required this.lostLife,
    required this.eliminated,
    required this.playerWon,
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
  final List<int> livesLost;
  final List<int> targetsSet;
  final List<int> highestTurn;
  final List<int> turnsSurvived;
  final List<int> lastDartSaves;
  final List<int> elimsDealt;

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
        livesLost = List.of(e.livesLost),
        targetsSet = List.of(e.targetsSet),
        highestTurn = List.of(e.highestTurn),
        turnsSurvived = List.of(e.turnsSurvived),
        lastDartSaves = List.of(e.lastDartSaves),
        elimsDealt = List.of(e.elimsDealt);
}

/// 1UP: match or beat the target or lose a life. Last player standing wins.
/// Tie = success (turnTotal >= target is safe). A turn is always 3 darts.
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
        elimsDealt = List<int>.filled(playerCount, 0, growable: true) {
    _order = _buildRoundOrder();
  }

  final int startingLives;
  final OneUpVariant variant;
  final bool randomOrder;
  final Random _rng;

  final List<int> livesLeft;
  final List<int> eliminationOrder = [];
  final Set<int> _skipped = {};
  late List<int> _order; // turn sequence for the current round
  int _orderPos = 0;
  int _starterCursor = 0; // BEAT THE BEST round-robin starter (randomOrder off)
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
      // free throw sets the bar (game start in LAST, round start in BEST)
      target = total;
      targetSetBy = me;
      targetsSet[me]++;
      turnsSurvived[me]++;
    } else if (total >= targetBefore) {
      // success — tie leaves the number (and owner in BEST) unchanged
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

    _advance();
    return OneUpDartResult(
        points: lastDartPoints, turnEnded: true, lostLife: lost,
        eliminated: elim, playerWon: won);
  }

  void _advance() {
    turnPoints = 0;
    dartsInTurn = 0;
    if (gameOver) return;
    var next = _orderPos + 1;
    while (next < _order.length && !isAlive(_order[next])) {
      next++;
    }
    if (next >= _order.length) {
      roundNumber++;
      if (variant == OneUpVariant.beatTheBest) {
        target = null;
        targetSetBy = -1;
        if (!randomOrder && _order.isNotEmpty) {
          _starterCursor = (_order.first + 1) % playerCount;
        }
      }
      _order = _buildRoundOrder();
      _orderPos = 0;
    } else {
      _orderPos = next;
    }
  }

  List<int> _buildRoundOrder() {
    final alive = aliveIndices;
    if (alive.isEmpty) return [0]; // unreachable in play; keeps getters safe
    if (randomOrder) {
      alive.shuffle(_rng);
      return alive;
    }
    if (variant == OneUpVariant.beatTheBest) {
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
    }
    eliminationOrder
      ..clear()
      ..addAll(s.eliminationOrder);
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

  // addPlayer / removePlayer implemented in Task 4.
}
