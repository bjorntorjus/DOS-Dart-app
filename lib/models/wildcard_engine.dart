/// Pure WILDCARD game logic — no Flutter dependencies.
///
/// A chaos points race: 3-dart turns bank into a running total (floor 0),
/// fed by a 0-10 chaos meter that climbs on triples and drops on true misses.
/// Bull hits (single or double) hand the thrower a meter-direction choice
/// instead of an automatic delta — see [applyDart]/[resolveBullChoice].
///
/// Turn-modifiers (spec §4), restriction dimming, the scoring transforms they
/// apply, THE WINDOW, and freeze are wired here. Hidden jokers, cursed
/// numbers, and the 9 instant events (spec §5), plus CUT!/REWIND round
/// surgery, are wired here too — the engine is spec-complete (§2-§5, §10).
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

  /// Revealed joker number, or null when this dart didn't hit a joker.
  final int? jokerHit;

  /// Instant event fired by the joker, or null.
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
  final bool missedThisTurn;
  final List<({int segment, int multiplier})> turnDarts;
  final List<bool> hadModifierLastTurn;
  final Set<int> jokers;
  final int? cursedNumber;
  final int? frozenPlayer;
  final int? pendingBullChoice;
  final bool gameOver;
  final int? winnerIndex;
  final bool doubleJeopardyPending;
  final int? giftTargetIndex;
  final int giftBaselinePoints;
  final WcEventResolution? lastEventResolution;

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
    required this.missedThisTurn,
    required this.turnDarts,
    required this.hadModifierLastTurn,
    required this.jokers,
    required this.cursedNumber,
    required this.frozenPlayer,
    required this.pendingBullChoice,
    required this.gameOver,
    required this.winnerIndex,
    required this.doubleJeopardyPending,
    required this.giftTargetIndex,
    required this.giftBaselinePoints,
    required this.lastEventResolution,
  });
}

/// One flag rendered on a player's standings row after an instant event
/// resolves (spec §5 dialog).
typedef WcEventFlag = ({int playerIndex, String flagText, bool good});

/// Result of the most recently resolved instant event (cleared at the start
/// of every [WildcardEngine.applyDart] call). `detail` is engine-built from
/// indices/numbers only ('STEAL 50 · P1 288 → 238') — the screen maps player
/// indices to names for the human-readable dialog copy.
typedef WcEventResolution = ({
  WcInstantEventDef event,
  String detail,
  List<WcEventFlag> flags,
});

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

  /// Raw (segment, multiplier) pairs for every dart thrown this turn, in
  /// order — the literal HOLY TRINITY banking check ([_computeBankedAmount])
  /// needs the actual darts, not just [turnPoints]. Cleared per turn
  /// alongside [turnDartLabels].
  late List<({int segment, int multiplier})> turnDarts;

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

  /// True once a TRUE miss (segment 0) has landed during the current turn —
  /// only the FIRST miss of a turn moves the meter; later misses in the
  /// same turn are a no-op (still void THE WINDOW, see [applyDart]). Reset
  /// for each new turn in [_rollTurnModifier].
  bool _missedThisTurn = false;

  /// Per-player cooldown: true when that player's PREVIOUS turn had an
  /// [activeModifier] (rolled or forced), set at banking time
  /// ([_bankCurrentTurn]). A true flag makes that player's next
  /// [_rollTurnModifier] skip the roll entirely (and clear the flag)
  /// WITHOUT consuming a pending [debugForceModifier] — the force survives
  /// to the next roll that actually happens, mirroring the frozen-thrower
  /// skip semantics already documented there. Grows in [addPlayer].
  late List<bool> _hadModifierLastTurn;

  /// Hidden joker numbers (test-visible), assigned at round start (and the
  /// constructor) per [wcJokerCount]. Re-rolls one-at-a-time as each is hit.
  Set<int> jokers = {};

  /// Hidden cursed number (1-20), or null. Scores −segment×multiplier when
  /// hit, then clears. Assigned by the CURSED NUMBER instant event.
  int? cursedNumber;

  /// One-round flag set by DOUBLE JEOPARDY: the next joker assignment draws
  /// 2 regardless of [wcJokerCount], then this is consumed.
  bool _doubleJeopardyPending = false;

  /// GIFT redirect (locked interpretation #10): while non-null, everything
  /// banked above [_giftBaselinePoints] this turn credits this player
  /// instead of the thrower. Consumed at banking.
  int? _giftTargetIndex;
  int _giftBaselinePoints = 0;

  /// The most recently resolved instant event, or null. Cleared at the start
  /// of every [applyDart] call.
  WcEventResolution? lastEventResolution;

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
    turnDarts = [];
    _hadModifierLastTurn = List.filled(playerCount, false, growable: true);
    _assignJokersForRound(); // round 1's jokers, per spec §5
    _rollTurnModifier(); // the game's very first turn also rolls (locked #16)
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool isSkipped(int index) => _skipped.contains(index);
  int get activePlayerCount => totals.length - _skipped.length;

  /// Returns true for a (segment, multiplier) dart that does NOT score under
  /// the active modifier; null while no modifier restricts scoring (open
  /// throw or THE WINDOW — dimming never applies during a window, spec §4).
  bool Function(int segment, int multiplier)? get dimPredicate {
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
    lastEventResolution = null; // cleared at the start of every dart

    final mod = activeModifier;
    final frozenTurn = frozenPlayer == currentPlayerIndex;
    final rawPoints = segment * multiplier;
    final turnPointsBeforeDart = turnPoints;

    // Per-dart scoring transform, per the locked interpretations (§4):
    // freeze zeroes everything; bull always scores (FORTUNE/CURSE replace
    // its points with a flat ±100; DOUBLE TROUBLE's ×3 still applies to a
    // double bull) — EXCEPT under HOLY TRINITY, the one modifier where bull
    // does NOT score (spec §4/§10, locked with Bjørn): trinity is about
    // exactly three numbers, so bull is deliberately excluded from the
    // blanket bull-exemption below and falls through to the dims check
    // instead, which zeroes it like any other non-{20,5,1} segment. This is
    // a hardcoded id check, not a generic "consult dims for bull" rule,
    // because a VALUE-based restriction (e.g. ONLY EVENS) would otherwise
    // wrongly dim bull too — 25 is odd. Do not genericize this.
    // Restriction dims otherwise zero a non-bull dart on a dimmed segment;
    // DOUBLE TROUBLE otherwise turns doubles into ×3 and triples into 0;
    // everything else scores normally. GOLDEN DART then triples whatever
    // the 3rd dart came out to.
    int points;
    if (frozenTurn) {
      points = 0;
    } else if (segment == 25 && mod?.id != 'holyTrinity') {
      if (mod?.id == 'bullsFortune') {
        points = 100;
      } else if (mod?.id == 'bullsCurse') {
        points = -100;
      } else if (mod?.id == 'doubleTrouble' && multiplier == 2) {
        points = segment * 3; // D-Bull under DOUBLE TROUBLE: 75
      } else {
        points = rawPoints; // 25 (single) or 50 (double), unaffected
      }
    } else if (segment != 0 &&
        mod?.dims != null &&
        mod!.dims!(segment, multiplier)) {
      points = 0; // dimmed restriction hit — alive, but scores nothing
    } else if (mod?.id == 'doubleTrouble' && multiplier == 2) {
      points = segment * 3;
    } else if (mod?.id == 'doubleTrouble' && multiplier == 3) {
      points = 0;
    } else {
      points = rawPoints;
    }

    // CURSED NUMBER (locked interpretation #12): hitting the hidden number
    // overrides whatever it would otherwise have scored (including a dimmed
    // 0) to a flat negative, then the curse clears. Suppressed only by
    // freeze, which zeroes every dart unconditionally.
    final hitCurse =
        !frozenTurn && segment != 0 && segment != 25 && segment == cursedNumber;
    if (hitCurse) {
      points = -rawPoints;
      cursedNumber = null;
    }

    if (!frozenTurn && mod?.id == 'goldenDart' && dartsInTurn == 2) {
      points *= 3;
    }

    turnPoints += points;
    turnDartLabels[dartsInTurn] = _labelFor(segment, multiplier);
    turnDarts.add((segment: segment, multiplier: multiplier));

    var meterDelta = 0;
    var needsBullChoice = false;
    var bullChoiceMagnitude = 0;

    // Meter reactions follow the DART thrown, not the points it scored — a
    // dimmed triple (or a DOUBLE TROUBLE triple) still moves the meter.
    if (segment == 25) {
      // Bull (single or double) never falls into the plain multiplier
      // branches below — it keeps its own ±1/±3 lever via resolveBullChoice.
      needsBullChoice = true;
      bullChoiceMagnitude = multiplier == 2 ? 3 : 1;
      pendingBullChoice = bullChoiceMagnitude;
    } else if (multiplier == 3) {
      meterDelta = _applyMeterChange(2); // triple: +2 (tablet-QA tuning)
    } else if (multiplier == 2) {
      meterDelta = _applyMeterChange(1); // double-ring: +1 (new)
    } else if (segment == 0) {
      // TRUE miss: only the FIRST one this turn costs the meter -1; later
      // misses in the same turn are a no-op (still void THE WINDOW below).
      if (!_missedThisTurn) {
        _missedThisTurn = true;
        meterDelta = _applyMeterChange(-1);
      }
      if (mod?.id == 'theWindow') _windowVoided = true;
    }

    dartsInTurn++;

    // Joker trigger (spec §5): any 1-20 segment, any multiplier, dimmed
    // included — never bull (bull is handled entirely above via
    // needsBullChoice/segment==25, so this range check alone excludes it).
    int? jokerHit;
    WcInstantEventDef? instantEvent;
    var roundRestructured = false;
    if (!needsBullChoice && segment >= 1 && segment <= 20 && jokers.contains(segment)) {
      jokerHit = segment;
      jokersHitCount[currentPlayerIndex]++;
      meterDelta += _applyMeterChange(2);
      instantEvent = _drawInstantEvent();
      roundRestructured =
          _resolveInstantEvent(instantEvent, turnPointsBeforeDart);
      // CUT!/REWIND already settled the joker set for the (new or restarted)
      // round inside _resolveInstantEvent — a normal reroll here would stack
      // an extra number on top of that fresh assignment.
      if (!roundRestructured) _rerollJoker(segment);
    }

    var turnEnded = false;
    var roundEnded = false;
    if (roundRestructured) {
      // CUT!/REWIND already banked/discarded the turn and moved the round
      // along inside _resolveInstantEvent — the normal 3rd-dart bank below
      // must not also run.
      turnEnded = true;
      roundEnded = true;
    } else if (!needsBullChoice && dartsInTurn >= 3) {
      turnEnded = true;
      final roundBefore = round;
      _bankTurnAndAdvance();
      roundEnded = round != roundBefore;
    }

    return WildcardDartResult(
      points: points,
      meterDelta: meterDelta,
      jokerHit: jokerHit,
      instantEvent: instantEvent,
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
  /// miss); EVERYTHING ×2 doubles it; HOLY TRINITY v3 adds +100 when the
  /// turn's darts COVER all three of 20, 5, and 1 — any ring on each (a
  /// double or triple counts, since the restriction dims everything else to
  /// 0 already, so partial trinity hits keep their points automatically);
  /// a true miss records segment 0 and bull records 25, so neither
  /// contributes to coverage. Any other/no modifier banks [turnPoints]
  /// unchanged.
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
        final segs = turnDarts.map((d) => d.segment).toSet();
        if (segs.containsAll(const {20, 5, 1})) {
          return turnPoints + 100;
        }
        return turnPoints;
      default:
        return turnPoints;
    }
  }

  /// Banks the current player's in-progress turn into [totals] and resets
  /// the per-turn scratch state. Does NOT advance the seat/round — see
  /// [_bankTurnAndAdvance] (normal 3rd-dart end) and [_executeCut] (round
  /// guillotined mid-turn), which both call this then handle rotation
  /// themselves.
  ///
  /// GIFT redirect (locked interpretation #10): when [_giftTargetIndex] is
  /// set, everything from the triggering dart onward ([_giftBaselinePoints]
  /// through the raw [turnPoints]) is a "gift share" credited to that player
  /// instead — floor 0 on both the thrower's remaining share and the gift
  /// share. This bypasses the whole-turn modifier transforms below
  /// ([_computeBankedAmount]) deliberately: GIFT is a raw-points redirect,
  /// not a re-run of the turn-total math (no test exercises GIFT stacked
  /// with a restriction/multiplier modifier in the same turn).
  void _bankCurrentTurn() {
    // Cooldown (spec §4 tuning): a modifier assigned this turn (rolled or
    // forced) puts this player's NEXT turn on cooldown — see
    // [_rollTurnModifier]. A frozen/no-modifier turn leaves the flag alone
    // (it was already reset false at this turn's roll).
    if (activeModifier != null) {
      _hadModifierLastTurn[currentPlayerIndex] = true;
    }
    final giftTarget = _giftTargetIndex;
    int bankedAmount;
    if (giftTarget != null) {
      final throwerShare = math.max(0, _giftBaselinePoints);
      final giftShare = math.max(0, turnPoints - _giftBaselinePoints);
      bankedAmount = throwerShare;
      totals[giftTarget] = math.max(0, totals[giftTarget] + giftShare);
      if (giftShare > highestTurn[giftTarget]) {
        highestTurn[giftTarget] = giftShare;
      }
    } else {
      bankedAmount = _computeBankedAmount();
    }
    totals[currentPlayerIndex] =
        math.max(0, totals[currentPlayerIndex] + bankedAmount);
    if (bankedAmount > highestTurn[currentPlayerIndex]) {
      highestTurn[currentPlayerIndex] = bankedAmount;
    }
    if (frozenPlayer == currentPlayerIndex) frozenPlayer = null;
    turnPoints = 0;
    dartsInTurn = 0;
    turnDartLabels = List.filled(3, '—');
    turnDarts = [];
    _giftTargetIndex = null;
    _giftBaselinePoints = 0;
  }

  void _bankTurnAndAdvance() {
    _bankCurrentTurn();
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
  /// happens (locked interpretation #16). A thrower on modifier COOLDOWN
  /// (see [_hadModifierLastTurn]) gets the same treatment: no roll, the
  /// cooldown flag clears, and any pending forced id survives untouched for
  /// the next roll that actually happens.
  void _rollTurnModifier() {
    activeModifier = null;
    window = null;
    _windowVoided = false;
    _missedThisTurn = false;

    if (frozenPlayer == currentPlayerIndex) return;

    if (_hadModifierLastTurn[currentPlayerIndex]) {
      _hadModifierLastTurn[currentPlayerIndex] = false;
      return;
    }

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
        _assignJokersForRound();
      }
      if (currentPlayerIndex == startIndex) break;
    } while (isSkipped(currentPlayerIndex));
  }

  /// First non-skipped seat, scanning from index 0 — the round's starting
  /// seat for a fresh round (CUT!'s next round, REWIND's restart).
  int _firstActiveSeat() {
    for (var i = 0; i < totals.length; i++) {
      if (!isSkipped(i)) return i;
    }
    return 0;
  }

  /// Assigns fresh hidden jokers for the round about to start (spec §5):
  /// [wcJokerCount] numbers from 1-20, unique, never [cursedNumber] — or 2
  /// unconditionally if DOUBLE JEOPARDY armed the one-round flag. Called
  /// from the constructor (round 1) and every round rollover ([_advancePlayer]
  /// normal wrap, [_advanceRoundForCut] after CUT!).
  void _assignJokersForRound() {
    final count = _doubleJeopardyPending ? 2 : wcJokerCount(chaos);
    _doubleJeopardyPending = false;
    final result = <int>{};
    while (result.length < count) {
      final n = 1 + _rng.nextInt(20);
      if (n == cursedNumber) continue;
      if (!result.add(n)) continue;
    }
    jokers = result;
  }

  /// Re-rolls a just-hit joker to a new number, excluding the one just hit,
  /// every other currently-active joker, and [cursedNumber]. If no number is
  /// available the joker is simply removed (locked interpretation, spec §10;
  /// unreachable in practice — at most 2 jokers + 1 curse ever occupy the
  /// 20-number space).
  void _rerollJoker(int justHit) {
    final others = {...jokers}..remove(justHit);
    final excluded = {...others, justHit, ?cursedNumber};
    final candidates = [
      for (var n = 1; n <= 20; n++)
        if (!excluded.contains(n)) n
    ];
    if (candidates.isEmpty) {
      jokers = others;
      return;
    }
    final newNumber = candidates[_rng.nextInt(candidates.length)];
    jokers = {...others, newNumber};
  }

  /// Rolls a fresh [cursedNumber] for the CURSED NUMBER event: 1-20,
  /// excluding current jokers and the number already cursed (locked
  /// interpretation #12).
  int _rollNewCursedNumber() {
    final excluded = {...jokers, ?cursedNumber};
    final candidates = [
      for (var n = 1; n <= 20; n++)
        if (!excluded.contains(n)) n
    ];
    return candidates[_rng.nextInt(candidates.length)];
  }

  /// Draws the instant event fired by a joker hit: [debugForceEvent]
  /// overrides the draw outright (consumed once); otherwise uniform over a
  /// list built by expanding [wcSeverityPool] (a severity may repeat — wild
  /// appears twice at chaos 9-10 to double-weight it) into its matching
  /// [wcInstantEvents]. Falls back to the mild tier if the pool is empty
  /// (chaos 0, reachable only via a stale DOUBLE JEOPARDY joker surviving a
  /// meter drop to 0).
  WcInstantEventDef _drawInstantEvent() {
    final forcedId = _forcedEventId;
    if (forcedId != null) {
      _forcedEventId = null;
      return wcInstantEvents.firstWhere((e) => e.id == forcedId);
    }
    final pool = wcSeverityPool(chaos);
    final effectivePool = pool.isEmpty ? const [WcSeverity.mild] : pool;
    final weighted = <WcInstantEventDef>[
      for (final s in effectivePool) ...wcInstantEvents.where((e) => e.severity == s),
    ];
    return weighted[_rng.nextInt(weighted.length)];
  }

  List<int> _livingOthers(int hitter) => [
        for (var i = 0; i < totals.length; i++)
          if (i != hitter && !isSkipped(i)) i
      ];

  List<int> _livingIncluding(int hitter) => [
        for (var i = 0; i < totals.length; i++)
          if (!isSkipped(i)) i
      ];

  /// Highest-total index among [indices]; ties resolve to the earliest seat
  /// because the scan only replaces on a strictly-greater total.
  int _highestAmong(List<int> indices) {
    var best = indices.first;
    for (final i in indices.skip(1)) {
      if (totals[i] > totals[best]) best = i;
    }
    return best;
  }

  /// Lowest-total index among [indices]; ties resolve to the earliest seat
  /// (see [_highestAmong]).
  int _lowestAmong(List<int> indices) {
    var best = indices.first;
    for (final i in indices.skip(1)) {
      if (totals[i] < totals[best]) best = i;
    }
    return best;
  }

  /// Resolves [event] for the current joker-hitter (locked interpretations
  /// #9-#15). Returns true when the round was restructured (CUT!/REWIND) —
  /// the caller must then skip the normal end-of-turn banking, since this
  /// method already handled it.
  bool _resolveInstantEvent(WcInstantEventDef event, int turnPointsBeforeDart) {
    final hitter = currentPlayerIndex;
    switch (event.id) {
      case 'chaosSurge':
        final applied = _applyMeterChange(3);
        lastEventResolution =
            (event: event, detail: 'CHAOS +$applied', flags: <WcEventFlag>[]);
        return false;

      case 'scoreSwap':
        final others = _livingOthers(hitter);
        if (others.isEmpty) {
          lastEventResolution =
              (event: event, detail: 'SWAP · no target', flags: <WcEventFlag>[]);
          return false;
        }
        final other = others[_rng.nextInt(others.length)];
        final a = totals[hitter];
        final b = totals[other];
        totals[hitter] = b;
        totals[other] = a;
        final hitterDelta = b - a;
        final otherDelta = a - b;
        lastEventResolution = (
          event: event,
          detail: 'SWAP · P$hitter $a ↔ P$other $b',
          flags: <WcEventFlag>[
            (
              playerIndex: hitter,
              flagText:
                  '${hitterDelta >= 0 ? '+' : '-'}${hitterDelta.abs()} SWAP',
              good: hitterDelta >= 0,
            ),
            (
              playerIndex: other,
              flagText:
                  '${otherDelta >= 0 ? '+' : '-'}${otherDelta.abs()} SWAP',
              good: otherDelta >= 0,
            ),
          ],
        );
        return false;

      case 'robinHood':
        final others = _livingOthers(hitter);
        if (others.isEmpty) {
          lastEventResolution = (
            event: event,
            detail: 'STEAL · no target',
            flags: <WcEventFlag>[],
          );
          return false;
        }
        final victim = _highestAmong(others);
        final before = totals[victim];
        final stolen = math.min(50, before);
        totals[victim] = before - stolen;
        totals[hitter] += stolen;
        pointsStolen[hitter] += stolen;
        lastEventResolution = (
          event: event,
          detail: 'STEAL $stolen · P$victim $before → ${before - stolen}',
          flags: <WcEventFlag>[
            (playerIndex: hitter, flagText: '+$stolen STEAL', good: true),
            (playerIndex: victim, flagText: '-$stolen ROBBED', good: false),
          ],
        );
        return false;

      case 'gift':
        final others = _livingOthers(hitter);
        if (others.isEmpty) {
          lastEventResolution =
              (event: event, detail: 'GIFT · no target', flags: <WcEventFlag>[]);
          return false;
        }
        final target = _lowestAmong(others);
        _giftTargetIndex = target;
        _giftBaselinePoints = turnPointsBeforeDart;
        lastEventResolution = (
          event: event,
          detail: 'GIFT · rest of turn to P$target',
          flags: <WcEventFlag>[],
        );
        return false;

      case 'freeze':
        final alive = _livingIncluding(hitter);
        final leader = _highestAmong(alive);
        frozenPlayer = leader;
        lastEventResolution = (
          event: event,
          detail: 'FREEZE · P$leader',
          flags: <WcEventFlag>[],
        );
        return false;

      case 'cursedNumber':
        final newCurse = _rollNewCursedNumber();
        cursedNumber = newCurse;
        // The dialog copy must NOT reveal the cursed number — that's the
        // whole point of a hidden curse. Keep this detail digit-free.
        lastEventResolution = (
          event: event,
          detail: 'A hidden number is now CURSED — hit it and it bites',
          flags: <WcEventFlag>[],
        );
        return false;

      case 'doubleJeopardy':
        _doubleJeopardyPending = true;
        lastEventResolution = (
          event: event,
          detail: 'DOUBLE JEOPARDY · 2 jokers next round',
          flags: <WcEventFlag>[],
        );
        return false;

      case 'cutEvent':
        final roundEnding = round;
        _executeCut();
        lastEventResolution = (
          event: event,
          detail: 'CUT! · round $roundEnding ends',
          flags: <WcEventFlag>[],
        );
        return true;

      case 'rewindEvent':
        _executeRewind();
        lastEventResolution = (
          event: event,
          detail: 'REWIND · round $round restarts',
          flags: <WcEventFlag>[],
        );
        return true;

      default:
        return false;
    }
  }

  /// CUT! (locked interpretation #14): the current thrower's in-progress
  /// turn banks as-is, everyone else's turn this round is skipped, and the
  /// next round starts immediately from its first active seat. Firing on
  /// the final round ends the game instead.
  void _executeCut() {
    _bankCurrentTurn();
    round++;
    if (round > rounds) {
      gameOver = true;
      final ranked = ranking();
      winnerIndex = ranked.isEmpty ? null : ranked.first;
      return;
    }
    roundStartTotals = List.of(totals);
    currentPlayerIndex = _firstActiveSeat();
    _assignJokersForRound();
    _rollTurnModifier();
  }

  /// REWIND (locked interpretation #15): every player's this-round banked
  /// points are wiped back to [roundStartTotals], the in-progress turn is
  /// discarded, and the round restarts from its first active seat. Jokers
  /// and [cursedNumber] are untouched — only scores rewind.
  void _executeRewind() {
    totals = List.of(roundStartTotals);
    turnPoints = 0;
    dartsInTurn = 0;
    turnDartLabels = List.filled(3, '—');
    turnDarts = [];
    _giftTargetIndex = null;
    _giftBaselinePoints = 0;
    currentPlayerIndex = _firstActiveSeat();
    _rollTurnModifier();
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
      missedThisTurn: _missedThisTurn,
      turnDarts: List.of(turnDarts),
      hadModifierLastTurn: List.of(_hadModifierLastTurn),
      jokers: Set.of(jokers),
      cursedNumber: cursedNumber,
      frozenPlayer: frozenPlayer,
      pendingBullChoice: pendingBullChoice,
      gameOver: gameOver,
      winnerIndex: winnerIndex,
      doubleJeopardyPending: _doubleJeopardyPending,
      giftTargetIndex: _giftTargetIndex,
      giftBaselinePoints: _giftBaselinePoints,
      lastEventResolution: lastEventResolution,
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
    _missedThisTurn = e.missedThisTurn;
    turnDarts = e.turnDarts;
    _hadModifierLastTurn = e.hadModifierLastTurn;
    jokers = e.jokers;
    cursedNumber = e.cursedNumber;
    frozenPlayer = e.frozenPlayer;
    pendingBullChoice = e.pendingBullChoice;
    gameOver = e.gameOver;
    winnerIndex = e.winnerIndex;
    _doubleJeopardyPending = e.doubleJeopardyPending;
    _giftTargetIndex = e.giftTargetIndex;
    _giftBaselinePoints = e.giftBaselinePoints;
    lastEventResolution = e.lastEventResolution;
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
    _hadModifierLastTurn.add(false);
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
      turnDarts = [];
      pendingBullChoice = null;
      _giftTargetIndex = null;
      _giftBaselinePoints = 0;
      _advancePlayer();
      // A modifier is personal (spec §4: one thrower, one turn) — the seat
      // inheritor must get a fresh roll, not the removed player's leftover
      // activeModifier/window/_windowVoided. Guarded because _advancePlayer
      // may itself have just ended the game (final-round wraparound).
      if (!gameOver) _rollTurnModifier();
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

  /// Dev/QA override: force the next joker-triggered instant event to [id]
  /// (spec §8), bypassing the severity-pool draw entirely. Consumed once by
  /// the next [_drawInstantEvent] call.
  void debugForceEvent(String id) => _forcedEventId = id;
}
