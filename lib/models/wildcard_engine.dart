/// Pure WILDCARD game logic — no Flutter dependencies.
///
/// A chaos points race: 3-dart turns bank into a running total (floor 0),
/// fed by a 0-10 chaos meter that climbs on triples and drops on true misses.
/// Bull hits (single or double) hand the thrower a meter-direction choice
/// instead of an automatic delta — see [applyDart]/[resolveBullChoice].
///
/// Turn-modifiers (spec §4), restriction dimming, the scoring transforms they
/// apply, THE WINDOW, and freeze are wired here (Task 3). Jokers, cursed
/// numbers, and instant events (spec §5) remain data-only stubs — their
/// fields ([jokers], [cursedNumber], `debugForceEvent`) exist so the
/// screen/tests can compile against the final shape, but stay null/empty
/// until Task 4 wires the rolls in.
library;

import 'dart:math' as math;

import 'wildcard_events.dart';

class WildcardDartResult {
  /// Effective points credited THIS dart (after modifier/curse/freeze; may
  /// be negative pre-floor, e.g. a BULL'S CURSE bull).
  final int points;

  /// Applied (post-clamp) meter movement from this dart. Zero for bull darts
  /// — their meter change is deferred to [WildcardEngine.resolveBullChoice].
  final int meterDelta;

  /// Revealed joker number, or null. Always null until Task 4.
  final int? jokerHit;

  /// Instant event fired by the joker. Always null until Task 4.
  final WcInstantEventDef? instantEvent;

  /// True when the dart hit bull (single or double) — the screen must call
  /// [WildcardEngine.resolveBullChoice] with `±bullChoiceMagnitude` before
  /// the next dart can be applied.
  final bool needsBullChoice;

  /// 1 (single bull) or 3 (double bull) when [needsBullChoice], else 0.
  final int bullChoiceMagnitude;

  final bool turnEnded;
  final bool roundEnded;
  final bool gameOver;

  const WildcardDartResult({
    required this.points,
    required this.meterDelta,
    required this.jokerHit,
    required this.instantEvent,
    required this.needsBullChoice,
    required this.bullChoiceMagnitude,
    required this.turnEnded,
    required this.roundEnded,
    required this.gameOver,
  });
}

/// Snapshot of every mutable field, taken before a dart is applied so that
/// [WildcardEngine.undo] can restore it byte-for-byte. A bull dart's
/// [WildcardEngine.resolveBullChoice] reuses the entry pushed by the
/// triggering [WildcardEngine.applyDart] call (no second push) so one undo
/// removes the dart AND the meter choice together.
///
/// The RNG is deliberately NOT snapshotted — rewinding game state does not
/// rewind the random stream (same documented trade-off future roll-driven
/// tasks inherit).
class _WcUndoEntry {
  final List<int> totals;
  final int turnPoints;
  final List<String> turnDartLabels;
  final int dartsInTurn;
  final int currentPlayerIndex;
  final int round;
  final List<int> roundStartTotals;
  final int chaos;
  final int chaosPeak;
  final List<int> highestTurn;
  final List<int> jokersHitCount;
  final List<int> windowPrizes;
  final List<int> pointsStolen;
  final WcModifierDef? activeModifier;
  final ({int lo, int hi})? window;
  final bool windowVoided;
  final Set<int> jokers;
  final int? cursedNumber;
  final int? frozenPlayer;
  final int? pendingBullChoice;
  final bool gameOver;
  final int? winnerIndex;

  _WcUndoEntry({
    required this.totals,
    required this.turnPoints,
    required this.turnDartLabels,
    required this.dartsInTurn,
    required this.currentPlayerIndex,
    required this.round,
    required this.roundStartTotals,
    required this.chaos,
    required this.chaosPeak,
    required this.highestTurn,
    required this.jokersHitCount,
    required this.windowPrizes,
    required this.pointsStolen,
    required this.activeModifier,
    required this.window,
    required this.windowVoided,
    required this.jokers,
    required this.cursedNumber,
    required this.frozenPlayer,
    required this.pendingBullChoice,
    required this.gameOver,
    required this.winnerIndex,
  });
}

class WildcardEngine {
  final int rounds;

  /// 0-10, clamped. Triples push it up, true misses pull it down; bull hits
  /// hand the direction to the thrower via [resolveBullChoice].
  int chaos;

  /// 1-based.
  int round = 1;

  int currentPlayerIndex = 0;
  int dartsInTurn = 0;

  late List<int> totals;

  /// Display values for the 3 dart slots this turn ('T19'/'20'/'DBL'/'25'/
  /// '—' for a true miss); reset to all-miss at the start of each turn.
  late List<String> turnDartLabels;

  /// Running effective turn total (pre-banking); banked into [totals] with
  /// a floor of 0 when the turn ends.
  int turnPoints = 0;

  /// Totals as of the start of the current round (stats/UI helper).
  late List<int> roundStartTotals;

  /// Null = open throw. Rolled at the start of each turn (constructor for
  /// the very first turn, [_rollTurnModifier] on every subsequent bank).
  WcModifierDef? activeModifier;

  /// Non-null only while `activeModifier?.id == 'theWindow'`.
  ({int lo, int hi})? window;

  /// True once a true miss has landed during a THE WINDOW turn — forces the
  /// turn to bank 0 at banking time regardless of the eventual total (locked
  /// interpretation #8). Reset for each new turn in [_rollTurnModifier].
  bool _windowVoided = false;

  /// Hidden joker numbers (test-visible). Stays empty this task.
  Set<int> jokers = {};

  /// Stays null this task.
  int? cursedNumber;

  /// Scores 0 on their next turn: every dart banks 0 points, but meter/bull
  /// effects still fire and the thrower rolls no [activeModifier] (locked
  /// interpretation #16). Dissolves once that turn banks, or if the frozen
  /// player is removed mid-game.
  int? frozenPlayer;

  /// Max chaos level reached (stats).
  int chaosPeak;

  /// Best single banked turn per player (tiebreak + stats).
  late List<int> highestTurn;

  late List<int> jokersHitCount;
  late List<int> windowPrizes;
  late List<int> pointsStolen;

  bool gameOver = false;
  int? winnerIndex;

  /// Outstanding bull magnitude (1 or 3) awaiting [resolveBullChoice], or
  /// null. The same undo entry pushed by the triggering [applyDart] call
  /// covers both the dart and the eventual choice.
  int? pendingBullChoice;

  final math.Random _rng;

  String? _forcedModifierId;
  // ignore: unused_field
  String? _forcedEventId;

  final Set<int> _skipped = {};
  final List<_WcUndoEntry> _undoStack = [];

  WildcardEngine({
    required int playerCount,
    required this.rounds,
    required int startingChaos,
    required math.Random rng,
  })  : chaos = startingChaos.clamp(0, 10),
        chaosPeak = startingChaos.clamp(0, 10),
        _rng = rng {
    totals = List.filled(playerCount, 0, growable: true);
    roundStartTotals = List.of(totals);
    highestTurn = List.filled(playerCount, 0, growable: true);
    jokersHitCount = List.filled(playerCount, 0, growable: true);
    windowPrizes = List.filled(playerCount, 0, growable: true);
    pointsStolen = List.filled(playerCount, 0, growable: true);
    turnDartLabels = List.filled(3, '—');
    _rollTurnModifier(); // the game's very first turn also rolls (locked #16)
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool isSkipped(int index) => _skipped.contains(index);
  int get activePlayerCount => totals.length - _skipped.length;

  /// Returns true for segments that do NOT score under the active modifier;
  /// null while no modifier restricts scoring (open throw or THE WINDOW —
  /// dimming never applies during a window, spec §4).
  bool Function(int segment)? get dimPredicate {
    if (window != null) return null;
    return activeModifier?.dims;
  }

  /// Ranked player indices: totals desc, tiebreak [highestTurn] desc, then
  /// seat index; excludes skipped players.
  List<int> ranking() {
    final active = [
      for (int i = 0; i < totals.length; i++)
        if (!isSkipped(i)) i
    ];
    active.sort((a, b) {
      if (totals[b] != totals[a]) return totals[b].compareTo(totals[a]);
      if (highestTurn[b] != highestTurn[a]) {
        return highestTurn[b].compareTo(highestTurn[a]);
      }
      return a.compareTo(b);
    });
    return active;
  }

  String _labelFor(int segment, int multiplier) {
    if (segment == 0) return '—';
    if (multiplier == 3) return 'T$segment';
    if (multiplier == 2) return 'DBL';
    if (segment == 25) return '25';
    return '$segment';
  }

  /// Applies [delta] to [chaos] with clamping and peak tracking. Returns the
  /// actually-applied (post-clamp) movement.
  int _applyMeterChange(int delta) {
    final before = chaos;
    chaos = (chaos + delta).clamp(0, 10);
    if (chaos > chaosPeak) chaosPeak = chaos;
    return chaos - before;
  }

  /// Apply one dart for the current player. [segment] 0 = TRUE miss
  /// (button/off-board). Bull (segment 25) never advances the turn on its
  /// own — see [resolveBullChoice].
  WildcardDartResult applyDart(int segment, int multiplier) {
    assert(!gameOver, 'applyDart called after game over');
    assert(pendingBullChoice == null,
        'resolveBullChoice must be called before the next dart');

    _pushUndo();

    final mod = activeModifier;
    final frozenTurn = frozenPlayer == currentPlayerIndex;
    final rawPoints = segment * multiplier;

    // Per-dart scoring transform, per the locked interpretations (§4):
    // freeze zeroes everything; bull always scores (FORTUNE/CURSE replace
    // its points with a flat ±100; DOUBLE TROUBLE's ×3 still applies to a
    // double bull); restriction dims zero a non-bull dart on a dimmed
    // segment; DOUBLE TROUBLE otherwise turns doubles into ×3 and triples
    // into 0; everything else scores normally. GOLDEN DART then triples
    // whatever the 3rd dart came out to.
    int points;
    if (frozenTurn) {
      points = 0;
    } else if (segment == 25) {
      if (mod?.id == 'bullsFortune') {
        points = 100;
      } else if (mod?.id == 'bullsCurse') {
        points = -100;
      } else if (mod?.id == 'doubleTrouble' && multiplier == 2) {
        points = segment * 3; // D-Bull under DOUBLE TROUBLE: 75
      } else {
        points = rawPoints; // 25 (single) or 50 (double), unaffected
      }
    } else if (segment != 0 && mod?.dims != null && mod!.dims!(segment)) {
      points = 0; // dimmed restriction hit — alive, but scores nothing
    } else if (mod?.id == 'doubleTrouble' && multiplier == 2) {
      points = segment * 3;
    } else if (mod?.id == 'doubleTrouble' && multiplier == 3) {
      points = 0;
    } else {
      points = rawPoints;
    }

    if (!frozenTurn && mod?.id == 'goldenDart' && dartsInTurn == 2) {
      points *= 3;
    }

    turnPoints += points;
    turnDartLabels[dartsInTurn] = _labelFor(segment, multiplier);

    var meterDelta = 0;
    var needsBullChoice = false;
    var bullChoiceMagnitude = 0;

    // Meter reactions follow the DART thrown, not the points it scored — a
    // dimmed triple (or a DOUBLE TROUBLE triple) still moves the meter +1.
    if (segment == 25) {
      needsBullChoice = true;
      bullChoiceMagnitude = multiplier == 2 ? 3 : 1;
      pendingBullChoice = bullChoiceMagnitude;
    } else if (multiplier == 3) {
      meterDelta = _applyMeterChange(1);
    } else if (segment == 0) {
      meterDelta = _applyMeterChange(-1);
      if (mod?.id == 'theWindow') _windowVoided = true;
    }

    dartsInTurn++;

    var turnEnded = false;
    var roundEnded = false;
    if (!needsBullChoice && dartsInTurn >= 3) {
      turnEnded = true;
      final roundBefore = round;
      _bankTurnAndAdvance();
      roundEnded = round != roundBefore;
    }

    return WildcardDartResult(
      points: points,
      meterDelta: meterDelta,
      jokerHit: null,
      instantEvent: null,
      needsBullChoice: needsBullChoice,
      bullChoiceMagnitude: bullChoiceMagnitude,
      turnEnded: turnEnded,
      roundEnded: roundEnded,
      gameOver: gameOver,
    );
  }

  /// Resolves a pending bull choice with [signedDelta] (±1 for single bull,
  /// ±3 for double bull — must match the magnitude reported on the
  /// triggering [WildcardDartResult]). Applies the meter change to the SAME
  /// undo entry as the dart (no new push) and, if the bull was the turn's
  /// 3rd dart, now runs the deferred bank/rotate.
  void resolveBullChoice(int signedDelta) {
    final magnitude = pendingBullChoice;
    assert(magnitude != null, 'no pending bull choice to resolve');
    assert(signedDelta.abs() == magnitude,
        'signedDelta magnitude must match the pending bull choice');

    _applyMeterChange(signedDelta);
    pendingBullChoice = null;

    if (dartsInTurn >= 3) {
      _bankTurnAndAdvance();
    }
  }

  /// Turns the raw dart-by-dart [turnPoints] into what actually gets banked,
  /// applying the whole-turn transforms (locked interpretations #4, #7, #8):
  /// THE WINDOW replaces the sum with a flat 100/0 (or 0 if voided by a true
  /// miss); EVERYTHING ×2 doubles it; HOLY TRINITY adds +100 on an exact 26.
  /// Any other/no modifier banks [turnPoints] unchanged.
  int _computeBankedAmount() {
    final mod = activeModifier;
    if (mod == null) return turnPoints;
    switch (mod.id) {
      case 'theWindow':
        if (_windowVoided) return 0;
        final w = window!;
        if (turnPoints >= w.lo && turnPoints <= w.hi) {
          windowPrizes[currentPlayerIndex]++;
          return 100;
        }
        return 0;
      case 'everythingX2':
        return turnPoints * 2;
      case 'holyTrinity':
        return turnPoints == 26 ? turnPoints + 100 : turnPoints;
      default:
        return turnPoints;
    }
  }

  void _bankTurnAndAdvance() {
    final bankedAmount = _computeBankedAmount();
    totals[currentPlayerIndex] =
        math.max(0, totals[currentPlayerIndex] + bankedAmount);
    if (bankedAmount > highestTurn[currentPlayerIndex]) {
      highestTurn[currentPlayerIndex] = bankedAmount;
    }
    if (frozenPlayer == currentPlayerIndex) frozenPlayer = null;
    turnPoints = 0;
    dartsInTurn = 0;
    turnDartLabels = List.filled(3, '—');
    _advancePlayer();
    if (!gameOver) _rollTurnModifier();
  }

  /// Rolls (or clears) [activeModifier] for the player about to throw
  /// (`currentPlayerIndex`): called once from the constructor for the game's
  /// very first turn, and again from [_bankTurnAndAdvance] for every
  /// subsequent turn. Chance is [wcModifierChancePct] at the current [chaos];
  /// the definition is drawn uniformly from [wcModifiers] filtered to
  /// [wcSeverityPool]. `theWindow` also rolls fresh [window] bounds.
  /// [debugForceModifier] overrides the chance roll outright (consumed once).
  /// A frozen thrower gets no roll at all — [activeModifier] stays null and
  /// a pending forced id is left queued for the next roll that actually
  /// happens (locked interpretation #16).
  void _rollTurnModifier() {
    activeModifier = null;
    window = null;
    _windowVoided = false;

    if (frozenPlayer == currentPlayerIndex) return;

    WcModifierDef? chosen;
    final forcedId = _forcedModifierId;
    if (forcedId != null) {
      chosen = wcModifiers.firstWhere((m) => m.id == forcedId);
      _forcedModifierId = null;
    } else {
      final chancePct = wcModifierChancePct(chaos);
      if (chancePct > 0 && _rng.nextInt(100) < chancePct) {
        final pool = wcSeverityPool(chaos);
        final eligible = [
          for (final m in wcModifiers)
            if (pool.contains(m.severity)) m
        ];
        if (eligible.isNotEmpty) {
          chosen = eligible[_rng.nextInt(eligible.length)];
        }
      }
    }

    activeModifier = chosen;
    if (chosen?.id == 'theWindow') {
      window = wcRollWindow(_rng, chaos);
    }
  }

  /// Advance to the next non-skipped player. Wrapping past the last seat
  /// bumps [round] and re-captures [roundStartTotals]; completing the final
  /// round ends the game via [ranking]. Guards against spinning forever
  /// when every other seat is removed (same F7 guard as CricketEngine).
  void _advancePlayer() {
    final startIndex = currentPlayerIndex;
    do {
      currentPlayerIndex++;
      if (currentPlayerIndex >= totals.length) {
        currentPlayerIndex = 0;
        round++;
        if (round > rounds) {
          gameOver = true;
          final ranked = ranking();
          winnerIndex = ranked.isEmpty ? null : ranked.first;
          return;
        }
        roundStartTotals = List.of(totals);
      }
      if (currentPlayerIndex == startIndex) break;
    } while (isSkipped(currentPlayerIndex));
  }

  void _pushUndo() {
    _undoStack.add(_WcUndoEntry(
      totals: List.of(totals),
      turnPoints: turnPoints,
      turnDartLabels: List.of(turnDartLabels),
      dartsInTurn: dartsInTurn,
      currentPlayerIndex: currentPlayerIndex,
      round: round,
      roundStartTotals: List.of(roundStartTotals),
      chaos: chaos,
      chaosPeak: chaosPeak,
      highestTurn: List.of(highestTurn),
      jokersHitCount: List.of(jokersHitCount),
      windowPrizes: List.of(windowPrizes),
      pointsStolen: List.of(pointsStolen),
      activeModifier: activeModifier,
      window: window,
      windowVoided: _windowVoided,
      jokers: Set.of(jokers),
      cursedNumber: cursedNumber,
      frozenPlayer: frozenPlayer,
      pendingBullChoice: pendingBullChoice,
      gameOver: gameOver,
      winnerIndex: winnerIndex,
    ));
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final e = _undoStack.removeLast();
    totals = e.totals;
    turnPoints = e.turnPoints;
    turnDartLabels = e.turnDartLabels;
    dartsInTurn = e.dartsInTurn;
    currentPlayerIndex = e.currentPlayerIndex;
    round = e.round;
    roundStartTotals = e.roundStartTotals;
    chaos = e.chaos;
    chaosPeak = e.chaosPeak;
    highestTurn = e.highestTurn;
    jokersHitCount = e.jokersHitCount;
    windowPrizes = e.windowPrizes;
    pointsStolen = e.pointsStolen;
    activeModifier = e.activeModifier;
    window = e.window;
    _windowVoided = e.windowVoided;
    jokers = e.jokers;
    cursedNumber = e.cursedNumber;
    frozenPlayer = e.frozenPlayer;
    pendingBullChoice = e.pendingBullChoice;
    gameOver = e.gameOver;
    winnerIndex = e.winnerIndex;
  }

  void clearUndoStack() => _undoStack.clear();

  /// Add a mid-game joiner. Per spec §7.2 WILDCARD joiners always start at 0
  /// (no table-average like Shanghai/Cricket) — [initialScore] exists only
  /// for API symmetry and defaults to 0. Clears the undo stack — snapshots
  /// have the old list lengths.
  void addPlayer({int initialScore = 0}) {
    totals.add(initialScore);
    roundStartTotals.add(initialScore);
    highestTurn.add(0);
    jokersHitCount.add(0);
    windowPrizes.add(0);
    pointsStolen.add(0);
    _undoStack.clear();
  }

  /// Remove [index] mid-game: mark skipped, advance off the seat (and
  /// discard the in-flight turn) when current, dissolve [frozenPlayer] if
  /// it was the removed seat, and end the game when ≤1 active player
  /// remains (survivor wins). Clears the undo stack.
  void removePlayer(int index) {
    if (isSkipped(index)) return;
    _skipped.add(index);
    _undoStack.clear();

    if (frozenPlayer == index) frozenPlayer = null;

    if (index == currentPlayerIndex && !gameOver) {
      dartsInTurn = 0;
      turnPoints = 0;
      turnDartLabels = List.filled(3, '—');
      pendingBullChoice = null;
      _advancePlayer();
    }

    if (!gameOver) {
      final remaining = [
        for (int i = 0; i < totals.length; i++)
          if (!isSkipped(i)) i
      ];
      if (remaining.length <= 1) {
        winnerIndex = remaining.isEmpty ? null : remaining.first;
        gameOver = true;
      }
    }
  }

  /// Dev/QA override: force the next turn-modifier roll to [id] (spec §8),
  /// bypassing the chance/severity-pool roll entirely. Consumed once by the
  /// next [_rollTurnModifier] call that actually executes (a frozen thrower
  /// does not consume it — see [frozenPlayer]).
  void debugForceModifier(String id) => _forcedModifierId = id;

  /// Dev/QA override: force the next joker event (spec §8). No-op this task
  /// — jokers are not assigned until Task 4.
  void debugForceEvent(String id) => _forcedEventId = id;
}
