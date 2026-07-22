# 1UP Game Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 1UP game mode (DOSSEDART-only v1): lives-based "beat the target" — match or beat the previous throw (BEAT THE LAST) or the round's best throw (BEAT THE BEST) or lose a life; last player standing wins.

**Architecture:** Engine pattern (GotchaEngine snapshot-undo style) in `lib/models/one_up_engine.dart` with explicit per-round rotation order (injected `Random` for the shuffle toggle); own game screen reusing the shipped DOSSEDART cockpit chrome (CrtFrame/TopBar/X01 dartboard/ActionBar/menu/player-sheet) with a new 1UP active card + life pips; Wildcard's overlay state machine for the life-lost/elimination/winner moments; Shanghai's deferred-stats + post-game-undo protocol; setup via `DossedartSetupScaffold`.

**Tech Stack:** Flutter, no new packages. Fonts `PressStart2P`/`VT323` (already bundled).

## Global Constraints

- **Build order:** 1UP builds **after Gotcha ships** (Gotcha → 1UP → Golf). Branch `feat/one-up` from the then-current release-train tip (today that is `feat/wildcard-qa3`; re-check at execution time).
- **DOSSEDART-only v1** (same decision as Gotcha 2026-07-08): no classic-track work beyond compile-required cases in `player_setup_screen.dart`.
- **Home screen minimal wiring only** (decision 2026-07-16): Bjørn handles the home redesign separately. This plan only flips the existing 1UP tile from `soon` → `fresh` and adds the compile-required `_startGame` case. Touch NOTHING else in `dossedart_home_screen.dart` (not the ribbon string, not the grid).
- **Colors:** `DossedartTokens` only. New token **`lime = Color(0xFFC6FF3C)`** approved 2026-07-16 (1UP mode brand only — never a player colour; red/green keep danger/SAFE roles). Added in Task 1.
- **All UI strings English** (guard test `test/design/no_norwegian_ui_text_test.dart`).
- **Rules fasit:** `docs/superpowers/specs/2026-07-07-one-up-design.md` (rev 2026-07-16). **Design fasit:** `docs/design/dossedart-handoff/1up/` (README + `one-up-cockpit.jsx`). Spec wins over artboard.
- **Tie = success** everywhere: safe means `turnTotal >= target`; `NEED = target − turnTotal` (no +1); `CAN'T BEAT` when `need > 60 × dartsLeft`.
- **String fix (documented decision 2026-07-16):** artboard's `MISS = ELIMINATED` renders as **`FAIL = ELIMINATED`** (you are eliminated by not reaching the target, not only by missing).
- **Carousel translation (documented decision):** the artboard's peek-cards/pills carousel translates to the sibling-precedent **single active card + opponents strip** (exactly how Gotcha's climb-bar and Wildcard's standings strip translated their artboards). Opponents show name + life pips (+ 💀 `OUT`).
- **Two toggles (documented decision):** the scaffold's standard `RANDOM PLAYER ORDER` toggle (one-time start shuffle, default on — consistent with every other mode) stays; the spec's per-round shuffle is a second toggle **`SHUFFLE EVERY ROUND`** (→ `OneUpConfig.randomOrder`, default off).
- **Mode key string is `'oneUp'`** (`GameMode.oneUp.name`) in every string-keyed integration (StatsRecorder, PostGameScreen, stats screens, profile_stats).
- Emoji: `❤️` for `GameMode.emoji` (matches the existing home tile); cockpit TopBar title is `🕹️ 1UP` per artboard. Min players **2**. Lives chips **1 / 3 / 5**, default 3.
- **No sound assets in v1** (spec §6/§9 pattern from Gotcha): announcer calls `playRandom(['one_up/<event>'])` which silently no-ops until files ship. Do NOT declare `assets/sounds/one_up/` in pubspec.yaml (empty declared dirs break the build).
- **Logging:** Shanghai template — `logGameStart(... build: kAppVersion)` (do NOT repeat Gotcha's missing-build omission), `logTurnStart` + `logStandings` pair each turn (scores = lives left), `logRoster` on add/remove, free-form `R<n> STATE target=… variant=…` line.
- **Tests:** engine tests are pure Dart. Screen tests copy the stub harness from `test/screens/shanghai_postgame_undo_test.dart` (MethodChannel stubs for flutter_tts + battery, `SharedPreferences.setMockInitialValues({})`, `TtsService.instance.resetForTesting()`, `pump()` with Durations — never `pumpAndSettle`).
- Commit after every green task. Branch: `feat/one-up`.

---

### Task 0: Branch

- [ ] **Step 1:** `git checkout -b feat/one-up` from the release-train tip (verify Gotcha has shipped / been merged into the train first).
- [ ] **Step 2:** `flutter test test/` → all pass (baseline). `flutter analyze` → clean.

---

### Task 1: `lime` token

**Files:**
- Modify: `lib/theme/dossedart_tokens.dart` (accents block, after `orange` at line 22)

**Interfaces:**
- Produces: `DossedartTokens.lime` — used by Tasks 5, 6, 10.

- [ ] **Step 1: Add the token**

```dart
  static const Color orange = Color(0xFFFF7A00);

  /// 1UP / extra-life accent — mode brand only (approved 2026-07-16).
  /// Never a player colour; red/green keep the danger/SAFE roles.
  static const Color lime = Color(0xFFC6FF3C);
```

- [ ] **Step 2:** Run: `flutter test test/design/` → PASS (guard tests accept new tokens in the tokens file). `flutter analyze` → clean.
- [ ] **Step 3:** Commit: `feat(one-up): add lime accent token (approved palette extension)`

---

### Task 2: OneUpEngine — BEAT THE LAST core

**Files:**
- Create: `lib/models/one_up_engine.dart`
- Test: `test/models/one_up_engine_test.dart`

**Interfaces (produces — later tasks depend on these exact names):**

```dart
enum OneUpVariant { beatTheLast, beatTheBest }

class OneUpDartResult {
  final int points;        // segment × multiplier (0 for miss)
  final bool turnEnded;
  final bool lostLife;     // thrower failed the turn (turnEnded only)
  final bool eliminated;   // thrower hit 0 lives this turn
  final bool playerWon;    // game ended: last player standing
}

class OneUpEngine {
  OneUpEngine({
    required int playerCount,
    required int startingLives,
    OneUpVariant variant = OneUpVariant.beatTheLast,
    bool randomOrder = false,   // per-round shuffle (Task 4)
    Random? rng,
  });
  // read state
  int get playerCount; int get currentPlayerIndex; bool get canUndo;
  List<int> livesLeft; List<int> eliminationOrder; // first-out first
  int roundNumber; int dartsInTurn; int turnPoints;
  int? target;               // null = free throw
  int targetSetBy;           // seat that owns the target, -1 none
  bool gameOver; int? winnerIndex;
  bool isSkipped(int i); bool isEliminated(int i); bool isAlive(int i);
  List<int> get aliveIndices;
  bool get isFreeThrow; int get needed; bool get canStillBeat; bool get hasBeatenTarget;
  // per-seat stats
  List<int> livesLost, targetsSet, highestTurn, turnsSurvived, lastDartSaves, elimsDealt;
  // mutations
  OneUpDartResult applyDart(int segment, int multiplier);
  void undo(); void clearUndoStack();
  void addPlayer(); void removePlayer(int index);  // Task 4
}
```

- [ ] **Step 1: Write failing tests** (`test/models/one_up_engine_test.dart`):

```dart
import 'package:dart_scoring/models/one_up_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OneUpEngine BEAT THE LAST core', () {
    test('game opens with a free throw that sets the target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      expect(e.isFreeThrow, isTrue);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1); // 60
      expect(r.turnEnded, isTrue);
      expect(r.lostLife, isFalse);
      expect(e.target, 60);
      expect(e.targetSetBy, 0);
      expect(e.targetsSet[0], 1);
      expect(e.currentPlayerIndex, 1);
      expect(e.isFreeThrow, isFalse);
    });

    test('tie = success: equal total is safe, target unchanged', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60); // P0 free: target 60
      final r = _turn(e, 60); // P1 ties
      expect(r.lostLife, isFalse);
      expect(e.livesLeft, [3, 3]);
      expect(e.target, 60);
    });

    test('beat: total becomes the new target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      _turn(e, 100);
      expect(e.target, 100);
      expect(e.targetSetBy, 1);
    });

    test('fail: lose a life AND the lower total becomes the target', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      final r = _turn(e, 40);
      expect(r.lostLife, isTrue);
      expect(e.livesLeft, [3, 2]);
      expect(e.target, 40); // self-correcting bar
      expect(e.targetSetBy, 1);
      expect(e.livesLost[1], 1);
    });

    test('a 0 target cannot be failed (three misses then anything)', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 0); // free throw of 0
      final r = _turn(e, 0); // ties 0 → safe
      expect(r.lostLife, isFalse);
      expect(e.livesLeft, [3, 3]);
    });

    test('elimination + placement order + last alive wins', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);          // P0 sets 100
      var r = _turn(e, 50);   // P1 fails → 0 lives → out
      expect(r.eliminated, isTrue);
      expect(r.playerWon, isFalse);
      expect(e.eliminationOrder, [1]);
      r = _turn(e, 40);       // P2 fails vs 50 → out → P0 wins
      expect(r.eliminated, isTrue);
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      expect(e.eliminationOrder, [1, 2]);
    });

    test('eliminated player is skipped in rotation, their throw stays the target', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);
      _turn(e, 50); // P1 out, target now 50
      expect(e.target, 50);
      expect(e.currentPlayerIndex, 2);
      _turn(e, 60); // P2 beats
      expect(e.currentPlayerIndex, 0); // P1 skipped
    });

    test('undo restores lives, target and elimination', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 1);
      _turn(e, 100);
      _turn(e, 40); // P1 out, P0 wins
      expect(e.gameOver, isTrue);
      e.undo(); // rewind last dart
      expect(e.gameOver, isFalse);
      expect(e.livesLeft[1], 1);
      expect(e.eliminationOrder, isEmpty);
      expect(e.target, 100);
      expect(e.dartsInTurn, 2);
    });

    test('helper getters: needed / canStillBeat / hasBeatenTarget', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 150);
      e.applyDart(10, 1); // turnPoints 10, 2 darts left, need 140
      expect(e.needed, 140);
      expect(e.canStillBeat, isFalse); // 140 > 120
      e.applyDart(20, 3);
      e.applyDart(20, 3);
      expect(e.hasBeatenTarget, isFalse); // 130 < 150 — turn already resolved
    });

    test('saved on last dart counts', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      e.applyDart(20, 1);
      e.applyDart(20, 1);       // 40 — still below
      e.applyDart(20, 3);       // 100 → tie on the last dart
      expect(e.lastDartSaves[1], 1);
    });

    test('highest turn and turns survived tracked', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      _turn(e, 100);
      expect(e.highestTurn, [60, 100]);
      expect(e.turnsSurvived, [1, 1]);
    });
  });
}

/// Throws one full 3-dart turn totalling [total]: greedy T20s, then the
/// remainder as one dart, then misses. Works for any total 0-180 whose
/// remainder after 60s is a single (≤20), 25, 50, an even ≤40, or a
/// multiple of 3 ≤ 60 — asserts otherwise.
OneUpDartResult _turn(OneUpEngine e, int total) {
  var remaining = total;
  var r = const OneUpDartResult(
      points: 0, turnEnded: false, lostLife: false,
      eliminated: false, playerWon: false);
  for (var d = 0; d < 3; d++) {
    final v = remaining >= 60 ? 60 : remaining;
    remaining -= v;
    r = _dart(e, v);
  }
  assert(remaining == 0, 'total $total not expressible in 3 darts');
  return r;
}

OneUpDartResult _dart(OneUpEngine e, int points) {
  if (points == 0) return e.applyDart(0, 1);          // miss
  if (points <= 20) return e.applyDart(points, 1);
  if (points == 25) return e.applyDart(25, 1);        // bull
  if (points == 50) return e.applyDart(25, 2);        // double bull
  if (points % 3 == 0 && points <= 60) return e.applyDart(points ~/ 3, 3);
  if (points % 2 == 0 && points <= 40) return e.applyDart(points ~/ 2, 2);
  throw ArgumentError('inexpressible dart: $points');
}
```

- [ ] **Step 2:** Run: `flutter test test/models/one_up_engine_test.dart` → FAIL (file doesn't exist).
- [ ] **Step 3: Implement** `lib/models/one_up_engine.dart`:

```dart
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
```

- [ ] **Step 4:** Run: `flutter test test/models/one_up_engine_test.dart` → PASS. `flutter analyze` → clean.
- [ ] **Step 5:** Commit: `feat(one-up): OneUpEngine core — beat the last, tie = success, lives, elimination, undo`

---

### Task 3: OneUpEngine — BEAT THE BEST

**Files:**
- Modify: `lib/models/one_up_engine.dart` (logic already scaffolded in Task 2 — this task pins it with tests and fixes anything the tests flush out)
- Test: `test/models/one_up_engine_test.dart` (new group)

**Interfaces:**
- Consumes: Task 2 API. No new members.

- [ ] **Step 1: Write failing tests** (append group):

```dart
  group('OneUpEngine BEAT THE BEST', () {
    OneUpEngine best(int players, int lives) => OneUpEngine(
        playerCount: players, startingLives: lives,
        variant: OneUpVariant.beatTheBest);

    test('every round opens with a free throw and the max resets', () {
      final e = best(2, 3);
      expect(e.isFreeThrow, isTrue);
      _turn(e, 60);  // P0 free-sets 60
      _turn(e, 100); // P1 beats → round ends
      expect(e.roundNumber, 2);
      expect(e.isFreeThrow, isTrue); // reset
      expect(e.target, isNull);
    });

    test('fail never lowers the round max, several can lose lives to one throw', () {
      final e = best(4, 3);
      _turn(e, 150); // P0 free-sets 150
      _turn(e, 60);  // P1 fails
      _turn(e, 60);  // P2 fails
      expect(e.target, 150); // max stood the whole round
      expect(e.livesLeft, [3, 2, 2, 3]);
      _turn(e, 150); // P3 ties → safe, max unchanged
      expect(e.livesLeft, [3, 2, 2, 3]);
    });

    test('beating the max raises it mid-round', () {
      final e = best(3, 3);
      _turn(e, 60);
      _turn(e, 100); // P1 raises
      expect(e.target, 100);
      expect(e.targetSetBy, 1);
      _turn(e, 80); // P2 fails vs 100
      expect(e.livesLeft[2], 2);
    });

    test('a 0 opening makes the whole round risk-free', () {
      final e = best(3, 1);
      _turn(e, 0); // free throw of 0
      _turn(e, 0); // ties 0 → safe
      _turn(e, 0); // ties 0 → safe
      expect(e.livesLeft, [1, 1, 1]);
      expect(e.roundNumber, 2);
    });

    test('starter rotates round-robin when randomOrder is off', () {
      final e = best(3, 3);
      expect(e.currentPlayerIndex, 0);
      _turn(e, 50); _turn(e, 60); _turn(e, 70); // round 1: 0,1,2
      expect(e.roundNumber, 2);
      expect(e.currentPlayerIndex, 1); // round 2 starts P1
      _turn(e, 50); _turn(e, 60); _turn(e, 70); // round 2: 1,2,0
      expect(e.currentPlayerIndex, 2); // round 3 starts P2
    });

    test('starter rotation skips eliminated players', () {
      final e = best(3, 1);
      _turn(e, 100); // P0 sets
      _turn(e, 40);  // P1 fails → out
      _turn(e, 100); // P2 ties → safe; round over
      expect(e.roundNumber, 2);
      // round 2 starter would be P1 but they're dead → P2
      expect(e.currentPlayerIndex, 2);
    });

    test('undo across a round boundary restores the round max', () {
      final e = best(2, 3);
      _turn(e, 60);
      _turn(e, 100); // round ends
      expect(e.target, isNull);
      e.undo(); // rewind P1's 3rd dart
      expect(e.roundNumber, 1);
      expect(e.target, 60);
      expect(e.dartsInTurn, 2);
    });
  });
```

- [ ] **Step 2:** Run: `flutter test test/models/one_up_engine_test.dart` → the new group should largely pass (logic landed in Task 2); fix any failures in `_endTurn`/`_advance`/`_buildRoundOrder` until green. If everything passes first run, still eyeball `_starterCursor` handling against the two rotation tests.
- [ ] **Step 3:** Run full suite: `flutter test test/models/` → PASS.
- [ ] **Step 4:** Commit: `feat(one-up): BEAT THE BEST — round reset, running max, starter rotation`

---

### Task 4: OneUpEngine — per-round shuffle + roster (add/remove)

**Files:**
- Modify: `lib/models/one_up_engine.dart`
- Test: `test/models/one_up_engine_test.dart` (new group)

**Interfaces:**
- Produces: `void addPlayer()` (joins from the next round with full lives), `void removePlayer(int index)` (skip seat; survivor wins; target unchanged). Both call `clearUndoStack()`.

- [ ] **Step 1: Write failing tests** (append group):

```dart
  group('OneUpEngine shuffle + roster', () {
    test('randomOrder reshuffles alive players each round (seeded)', () {
      final e = OneUpEngine(
          playerCount: 4, startingLives: 3, randomOrder: true,
          rng: Random(42));
      final round1 = List.of(e.roundOrder);
      for (var i = 0; i < 12; i++) { e.applyDart(1, 1); } // 4 turns → round 2
      expect(e.roundNumber, 2);
      final round2 = List.of(e.roundOrder);
      expect(round2.toSet(), {0, 1, 2, 3});
      // With seed 42 the two orders differ; if this ever collides, bump the seed.
      expect(round2, isNot(equals(round1)));
    });

    test('shuffled order is restored by undo', () {
      final e = OneUpEngine(
          playerCount: 3, startingLives: 3, randomOrder: true,
          rng: Random(7));
      final round1 = List.of(e.roundOrder);
      for (var i = 0; i < 9; i++) { e.applyDart(1, 1); } // → round 2
      final round2 = List.of(e.roundOrder);
      e.undo(); // back into round 1's last turn
      expect(e.roundNumber, 1);
      expect(e.roundOrder, round1); // the ROUND-1 order is byte-restored
      e.applyDart(1, 1); // redo the dart → round 2 again
      // The re-shuffle draws fresh randomness, so identity with the first
      // round-2 order is NOT guaranteed — only membership:
      expect(e.roundNumber, 2);
      expect(e.roundOrder.toSet(), round2.toSet());
    });

    test('addPlayer joins from the next round with full lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 60);
      e.addPlayer();
      expect(e.playerCount, 3);
      expect(e.livesLeft[2], 3);
      expect(e.roundOrder.contains(2), isFalse); // not in current round
      _turn(e, 100); // P1 finishes the round
      expect(e.roundOrder.contains(2), isTrue); // in from round 2
      expect(e.canUndo, isFalse); // roster change cleared the stack
    });

    test('removePlayer: current thrower removed → in-progress turn discarded, target unchanged', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 3);
      _turn(e, 100); // P0 sets 100
      e.applyDart(20, 3); // P1 starts a turn
      e.removePlayer(1);
      expect(e.currentPlayerIndex, 2);
      expect(e.turnPoints, 0);
      expect(e.dartsInTurn, 0);
      expect(e.target, 100); // just a number — stays
      expect(e.canUndo, isFalse);
    });

    test('removing down to one alive player ends the game (survivor wins)', () {
      final e = OneUpEngine(playerCount: 3, startingLives: 1);
      _turn(e, 100);
      _turn(e, 40); // P1 eliminated
      e.removePlayer(0);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 2); // removed player never wins
    });

    test('a removed player is never the winner', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      _turn(e, 100);
      e.removePlayer(0); // the leader leaves
      expect(e.winnerIndex, 1);
      expect(e.isSkipped(0), isTrue);
    });
  });
```

- [ ] **Step 2:** Run → FAIL (`addPlayer`/`removePlayer` missing).
- [ ] **Step 3: Implement** (append to `OneUpEngine`):

```dart
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
    if (wasCurrent) {
      _advance(); // resets turnPoints/dartsInTurn and moves off the seat
    }
  }
```

- [ ] **Step 4:** Run: `flutter test test/models/one_up_engine_test.dart` → PASS. Full `flutter test test/models/` → no regressions.
- [ ] **Step 5:** Commit: `feat(one-up): per-round shuffle (seeded RNG), mid-game add/remove, survivor wins`

---

### Task 5: Widgets — `OneUpLifePips` + `DossedartOneUpActiveCard`

**Files:**
- Create: `lib/widgets/dossedart/one_up/one_up_life_pips.dart`
- Create: `lib/widgets/dossedart/one_up/dossedart_one_up_active_card.dart`
- Test: `test/widgets/one_up_active_card_test.dart`

**Interfaces (produces):**

```dart
class OneUpLifePips extends StatelessWidget {
  const OneUpLifePips({super.key, required this.lives, required this.max,
      required this.color, this.size = 17});
}

enum OneUpCardMode { free, normal, safe, cantBeat }

class OneUpOpponentEntry {
  final String name; final Color accent;
  final int lives; final int maxLives; final bool eliminated;
  const OneUpOpponentEntry({required this.name, required this.accent,
      required this.lives, required this.maxLives, required this.eliminated});
}

class DossedartOneUpActiveCard extends StatelessWidget {
  const DossedartOneUpActiveCard({super.key,
    required this.playerName, required this.accentColor,
    required this.lives, required this.maxLives,
    required this.target,            // null in free mode
    required this.turnTotal, required this.currentDartIndex, // 0..3
    required this.cardMode, required this.lastLife,
    required this.variantChip,       // 'BEAT THE LAST' / 'BEAT THE BEST · R3'
    required this.isRoundFree,       // BEST wording for the free state
    required this.opponents});       // List<OneUpOpponentEntry>
}
```

Design fasit: `one-up-cockpit.jsx` `OUActiveCard`/`LifePips` (states, copy, colors). Frame color: `DossedartTokens.green` when safe, `DossedartTokens.red` when cantBeat/lastLife, else `accentColor`. Variant chip is `DossedartTokens.lime`. `NOW THROWING` tab like the Gotcha card (`dossedart_gotcha_active_card.dart` — copy its `_nameFontSize()` downscale curve).

- [ ] **Step 1: Write failing widget test:**

```dart
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)));

DossedartOneUpActiveCard _card({
  OneUpCardMode mode = OneUpCardMode.normal,
  int? target = 87,
  int turnTotal = 42,
  bool lastLife = false,
  bool isRoundFree = false,
  String variantChip = 'BEAT THE LAST',
}) =>
    DossedartOneUpActiveCard(
      playerName: 'Jonas', accentColor: DossedartTokens.cyan,
      lives: 3, maxLives: 3, target: target, turnTotal: turnTotal,
      currentDartIndex: 1, cardMode: mode, lastLife: lastLife,
      variantChip: variantChip, isRoundFree: isRoundFree,
      opponents: const [
        OneUpOpponentEntry(name: 'Kari', accent: DossedartTokens.magenta,
            lives: 2, maxLives: 3, eliminated: false),
        OneUpOpponentEntry(name: 'Per', accent: DossedartTokens.green,
            lives: 0, maxLives: 3, eliminated: true),
      ],
    );

void main() {
  testWidgets('normal state shows BEAT target and NEED line (no +1)', (t) async {
    await t.pumpWidget(_wrap(_card()));
    expect(find.text('BEAT'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.textContaining('NEED 45 MORE'), findsOneWidget); // 87−42, tie counts
  });

  testWidgets('free state shows SET THE TARGET', (t) async {
    await t.pumpWidget(_wrap(_card(mode: OneUpCardMode.free, target: null)));
    expect(find.textContaining('SET THE'), findsOneWidget);
    expect(find.textContaining('FREE THROW'), findsOneWidget);
  });

  testWidgets('BEST round free state uses round wording', (t) async {
    await t.pumpWidget(_wrap(_card(
        mode: OneUpCardMode.free, target: null, isRoundFree: true,
        variantChip: 'BEAT THE BEST · R3')));
    expect(find.textContaining('NEW ROUND'), findsOneWidget);
    expect(find.textContaining('ROUND TARGET'), findsOneWidget);
  });

  testWidgets('safe state (tie included)', (t) async {
    await t.pumpWidget(_wrap(_card(mode: OneUpCardMode.safe, turnTotal: 87)));
    expect(find.textContaining('SAFE'), findsOneWidget);
    expect(find.textContaining('NEW TARGET'), findsOneWidget);
  });

  testWidgets('cant-beat state', (t) async {
    await t.pumpWidget(_wrap(_card(
        mode: OneUpCardMode.cantBeat, target: 170, turnTotal: 10)));
    expect(find.textContaining("CAN'T BEAT"), findsOneWidget);
    expect(find.textContaining('LIFE AT RISK'), findsOneWidget);
  });

  testWidgets('last life shows FAIL = ELIMINATED (not MISS)', (t) async {
    await t.pumpWidget(_wrap(_card(lastLife: true)));
    expect(find.textContaining('LAST'), findsWidgets);
    expect(find.textContaining('FAIL = ELIMINATED'), findsOneWidget);
    expect(find.textContaining('MISS = ELIMINATED'), findsNothing);
  });

  testWidgets('eliminated opponent shows OUT', (t) async {
    await t.pumpWidget(_wrap(_card()));
    expect(find.text('OUT'), findsOneWidget);
  });
}
```

- [ ] **Step 2:** Run: `flutter test test/widgets/one_up_active_card_test.dart` → FAIL.
- [ ] **Step 3: Implement `OneUpLifePips`** (`one_up_life_pips.dart`):

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Arcade life hearts: live ♥ in [color] with glow, spent ♡ dimmed.
class OneUpLifePips extends StatelessWidget {
  const OneUpLifePips({super.key, required this.lives, required this.max,
      required this.color, this.size = 17});

  final int lives;
  final int max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              i < lives ? '♥' : '♡',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: size,
                height: 1,
                color: i < lives
                    ? color
                    : Colors.white.withValues(alpha: 0.18),
                shadows: i < lives
                    ? [Shadow(color: color, blurRadius: 6)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `DossedartOneUpActiveCard`** — layout per `OUActiveCard` in the JSX: bordered container (3px frame color, gradient fill `frame @ 11% → 2%`, glow), `▶ NOW THROWING` tab (top-left, frame color), lime variant chip (top-right, `DossedartTokens.lime` border/text on `bg`), header row (avatar box with initials · name (Gotcha `_nameFontSize` curve) · `OneUpLifePips` colored red when `lastLife` else accent · `LAST LIFE` tag when `lastLife`), primary block by `cardMode`:
  - `free` → secondary line `FREE THROW · NO TARGET` (or `FIRST THROW · NEW ROUND` when `isRoundFree`) + lime headline `SET THE TARGET` (or `SET THE ROUND TARGET`),
  - `safe` → green `SAFE ✓` + `NEW TARGET · $turnTotal · building…`,
  - `normal`/`cantBeat` → small `BEAT` label + big target number (62-equivalent, red when danger);
  right block `THIS TURN` + `turnTotal` + three dart pips filled to `currentDartIndex` (copy the dart-pip row from `dossedart_gotcha_active_card.dart`); status line container (tinted green/red per state):
  - free → `▸ YOUR 3-DART TOTAL SETS THE BAR FOR EVERYONE`
  - normal → `NEED ${target! - turnTotal <= 0 ? 0 : target! - turnTotal} MORE · ${3 - currentDartIndex} dart(s) left` — but when `lastLife` show `NEED n MORE · FAIL = ELIMINATED`
  - safe → `BEAT $target · REMAINING DARTS PAD THE NEW TARGET`
  - cantBeat → `CAN'T BEAT · LIFE AT RISK · need $n, max ${60 * (3 - currentDartIndex)}`
  and finally the opponents strip: horizontal `ListView`/`Row` of compact tiles (name + `OneUpLifePips(size: 13)`, eliminated → 50% opacity + 💀 + red `OUT` label). All colors via `DossedartTokens`/passed accents — no raw hex.
- [ ] **Step 5:** Run the widget test → PASS. `flutter analyze` → clean.
- [ ] **Step 6:** Commit: `feat(one-up): life pips + active card widget (free/normal/safe/cant-beat/last-life states)`

---

### Task 6: Mode wiring — enum, config, game screen core, setup screen, compile cases

This task is deliberately one unit: adding `GameMode.oneUp` breaks three exhaustive switches at once, and the new cases need the new screens to exist. Everything lands together and compiles green.

**Files:**
- Modify: `lib/models/game_mode.dart` (enum + `label` + `emoji` switches, lines 1-56)
- Modify: `lib/models/game_config.dart` (append subclass)
- Create: `lib/screens/one_up_game_screen.dart`
- Create: `lib/screens/dossedart/dossedart_one_up_setup_screen.dart`
- Modify: `lib/screens/player_setup_screen.dart` (state fields ~line 86, `_startGame` switch lines 487-556, `_buildModeOptions` switch lines 755-1040, imports)
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (tile at `_gridTiles` line ~42, `_startGame` switch lines 640-662, import)
- Test: `test/screens/one_up_game_screen_test.dart`

**Interfaces:**
- Consumes: `OneUpEngine` (Tasks 2-4), `DossedartOneUpActiveCard`/`OneUpLifePips` (Task 5), `DossedartCrtFrame`, `DossedartTopBar`, `DossedartX01Dartboard` (+ `DartZone.toSegmentMultiplier()`), `DossedartActionBar`, `showDossedartCockpitMenu`, `dossedartAccent(int)`, `GameLogger.instance`, `GameAnnouncer`, `kAppVersion`.
- Produces: `OneUpConfig`, `OneUpGameScreen({required List<Player> players, required OneUpConfig config})`, `DossedartOneUpSetupScreen()`. `OneUpGameScreen` exposes `@visibleForTesting engineForTest` and `removedPlayerIndicesForTest` (used by Tasks 7/9 tests).

- [ ] **Step 1: enum + config.** In `game_mode.dart`: add `oneUp,` to the enum; `case GameMode.oneUp: return '1UP';` in `label`; `case GameMode.oneUp: return '❤️';` in `emoji`. In `game_config.dart` append (import `one_up_engine.dart` for the variant enum):

```dart
class OneUpConfig extends GameConfig {
  final int lives;                 // 1 / 3 / 5 (default 3)
  final OneUpVariant variant;      // beatTheLast (default) / beatTheBest
  final bool randomOrder;          // shuffle alive rotation every round
  const OneUpConfig({
    this.lives = 3,
    this.variant = OneUpVariant.beatTheLast,
    this.randomOrder = false,
  }) : super(GameMode.oneUp);
}
```

- [ ] **Step 2: `OneUpGameScreen` core.** Model on `gotcha_game_screen.dart` (same member layout, lifecycle, sound/menu wiring — copy its `initState`/`dispose`/menu blocks verbatim, renaming). Mode-specific core:

```dart
class OneUpGameScreen extends StatefulWidget {
  const OneUpGameScreen({super.key, required this.players, required this.config});
  final List<Player> players;
  final OneUpConfig config;
  @override
  State<OneUpGameScreen> createState() => _OneUpGameScreenState();
}

class _OneUpGameScreenState extends State<OneUpGameScreen> {
  late final OneUpEngine engine;
  late final List<Player> players;
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;
  final DateTime _gameStart = DateTime.now();

  @visibleForTesting
  OneUpEngine get engineForTest => engine;

  @override
  void initState() {
    super.initState();
    players = List.of(widget.players);
    engine = OneUpEngine(
      playerCount: players.length,
      startingLives: widget.config.lives,
      variant: widget.config.variant,
      randomOrder: widget.config.randomOrder,
    );
    _announcer.init();
    _log.logGameStart(
      gameMode: '1UP',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, widget.config.lives),
      config: {
        'lives': widget.config.lives,
        'variant': widget.config.variant.name,
        'randomOrder': widget.config.randomOrder,
      },
      build: kAppVersion,
    );
    _logTurn();
  }

  void _logTurn() {
    _log.logTurnStart(
      roundNumber: engine.roundNumber,
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      score: engine.livesLeft[engine.currentPlayerIndex],
    );
    _log.logStandings(
      roundNumber: engine.roundNumber,
      names: players.map((p) => p.name).toList(),
      scores: engine.livesLeft,
    );
    _log.log('R${engine.roundNumber} STATE '
        'target=${engine.target ?? '-'} '
        'setBy=${engine.targetSetBy >= 0 ? players[engine.targetSetBy].name : '-'} '
        'variant=${widget.config.variant.name}');
  }

  void _onDartHit(int segment, int multiplier) {
    if (engine.gameOver) return;
    final result = engine.applyDart(segment, multiplier);
    // throwHistory append + _turnIdCounter handling: copy the Gotcha block
    // (gotcha_game_screen.dart:151-186) verbatim, using engine.roundNumber.
    setState(() {});
    if (result.turnEnded) _handleTurnEnd(result);
  }

  void _onMiss() { /* copy gotcha _onMiss: play miss sound → _onDartHit(0, 0) */ }

  void _handleTurnEnd(OneUpDartResult result) {
    // Task 8 layers overlays/announcements here; core flow:
    if (result.playerWon) { _onGameEnd(); return; }
    _logTurn();
  }

  void _onUndo() {
    if (engine.gameOver) return;
    if (!engine.canUndo) return;
    setState(() {
      engine.undo();
      if (throwHistory.isNotEmpty) {
        final lastThrow = throwHistory.removeLast();
        _turnIdCounter = lastThrow.turnId;
      }
    });
    _log.logUndo();
  }

  void _onGameEnd() { /* Task 7 */ }

  // Card-state derivation for the active card:
  OneUpCardMode get _cardMode {
    if (engine.isFreeThrow) return OneUpCardMode.free;
    if (engine.hasBeatenTarget) return OneUpCardMode.safe;
    if (!engine.canStillBeat) return OneUpCardMode.cantBeat;
    return OneUpCardMode.normal;
  }

  String get _variantChip => widget.config.variant == OneUpVariant.beatTheBest
      ? 'BEAT THE BEST · R${engine.roundNumber}'
      : 'BEAT THE LAST';
}
```

  `build()` mirrors the Gotcha tree (Scaffold → `DossedartCrtFrame` → SafeArea → Column) with:
  - `DossedartTopBar(title: '🕹️ 1UP', trailing: '${engine.activePlayerCount} ALIVE', onExit: …copy Gotcha's exit-confirm…)`
  - `DossedartOneUpActiveCard(...)` fed from engine state: `accentColor: dossedartAccent(engine.currentPlayerIndex)`, `lives/maxLives`, `target: engine.target`, `turnTotal: engine.turnPoints`, `currentDartIndex: engine.dartsInTurn`, `cardMode: _cardMode`, `lastLife: engine.livesLeft[engine.currentPlayerIndex] == 1`, `variantChip: _variantChip`, `isRoundFree: widget.config.variant == OneUpVariant.beatTheBest && engine.isFreeThrow && engine.roundNumber > 0`, opponents built from all other non-skipped seats (`OneUpOpponentEntry(… eliminated: engine.isEliminated(i))`).
  - Board block + full-field MISS `GestureDetector` + `DossedartActionBar(onUndo: _onUndo, onMiss: _onMiss, onMenu: …copy Gotcha menu wiring…)` — copy Gotcha's `build()` board/action blocks (gotcha_game_screen.dart:655-721) verbatim, swapping the card and handlers. Wrap the Column in an outer `Stack` now (Wildcard shape, wildcard_game_screen.dart:1167-1275) so Task 8's overlays slot in without re-layout.
- [ ] **Step 3: `DossedartOneUpSetupScreen`** (copy the Gotcha setup file shape):

```dart
class DossedartOneUpSetupScreen extends StatefulWidget { … }

class _DossedartOneUpSetupScreenState extends State<DossedartOneUpSetupScreen> {
  int _lives = 3;
  OneUpVariant _variant = OneUpVariant.beatTheLast;
  bool _shuffleEachRound = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: '1UP',
      minPlayers: 2,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<int>(
          label: 'LIVES',
          value: _lives,
          options: const [('1', 1), ('3', 3), ('5', 5)],
          onChanged: (v) => setState(() => _lives = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<OneUpVariant>(
          label: 'VARIANT',
          value: _variant,
          options: const [
            ('BEAT THE LAST', OneUpVariant.beatTheLast),
            ('BEAT THE BEST', OneUpVariant.beatTheBest),
          ],
          onChanged: (v) => setState(() => _variant = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
          ('SHUFFLE EVERY ROUND', _shuffleEachRound,
              (v) => setState(() => _shuffleEachRound = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) => [
        '$playerCount PLAYERS',
        '$_lives ${_lives == 1 ? 'LIFE' : 'LIVES'}',
        _variant == OneUpVariant.beatTheBest ? 'BEAT THE BEST' : 'BEAT THE LAST',
        if (_shuffleEachRound) 'SHUFFLE',
      ].join(' · ');

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OneUpGameScreen(
          players: players,
          config: OneUpConfig(
            lives: _lives,
            variant: _variant,
            randomOrder: _shuffleEachRound,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: compile cases.**
  - `dossedart_home_screen.dart`: tile `_GridTile(_TileKind.soon, '❤️', '1UP', soonText: 'COMING SOON')` → `_GridTile(_TileKind.fresh, '❤️', '1UP', mode: GameMode.oneUp)`; add `case GameMode.oneUp: screen = const DossedartOneUpSetupScreen();` to `_startGame`; import the setup screen. **Nothing else in this file.**
  - `player_setup_screen.dart`: state fields `int _oneUpLives = 3; OneUpVariant _oneUpVariant = OneUpVariant.beatTheLast; bool _oneUpShuffle = false;`; `_startGame` case building `OneUpGameScreen(players: players, config: OneUpConfig(lives: _oneUpLives, variant: _oneUpVariant, randomOrder: _oneUpShuffle))`; `_buildModeOptions` case mirroring the Gotcha case's structure (lines 974-1001): `SegmentedButton<int>` for lives 1/3/5, `SegmentedButton<OneUpVariant>` for the two variants, `SwitchListTile` "Shuffle every round". Import the game screen.
- [ ] **Step 5: Smoke test** (`test/screens/one_up_game_screen_test.dart`) — copy the harness from `test/screens/shanghai_postgame_undo_test.dart` (setUp/tearDown verbatim), then:

```dart
testWidgets('1UP cockpit: free throw → target set → NEED line → life lost', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: OneUpGameScreen(
      players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
      config: const OneUpConfig(lives: 3),
    ),
  ));
  await tester.pump();
  expect(find.textContaining('SET THE TARGET'), findsOneWidget);

  final state = tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
  final engine = (state as dynamic).engineForTest as OneUpEngine;
  engine.applyDart(20, 3); engine.applyDart(20, 3); engine.applyDart(20, 3); // 180
  (state as dynamic).setState(() {});
  await tester.pump();
  expect(find.text('BEAT'), findsOneWidget);
  expect(find.text('180'), findsOneWidget);
  expect(find.textContaining('NEED 180 MORE'), findsOneWidget);
});
```

  (Drive the engine directly for state assertions — tapping the SVG board in tests is brittle; input plumbing is covered by Task 7/9 flows.)
- [ ] **Step 6:** Run: `flutter test test/screens/one_up_game_screen_test.dart` → PASS. `flutter analyze` → clean (this proves every exhaustive switch is patched). Full `flutter test test/` → no regressions.
- [ ] **Step 7:** Commit: `feat(one-up): mode wiring — enum, config, cockpit core, DOSSEDART setup, home tile live`

---

### Task 7: Game end → post-game, deferred stats, post-game undo

**Files:**
- Modify: `lib/screens/one_up_game_screen.dart`
- Modify: `lib/screens/post_game_screen.dart` (`_buildStats` switch, lines 275-306)
- Test: `test/screens/one_up_postgame_undo_test.dart`

**Interfaces:**
- Consumes: `PostGameScreen({required GameResult result})`, `GameResult`/`PlayerResult`, `EloService.updateRatings`, `StatsRecorder.recordGame`/`recordMidGameChanges`, `AchievementService.awardGameEnd`, `PlayerStorage`.
- Produces: `_showPostGame()`, `_updateStats(List<int> ranking)`, `_rankPlayers()` on the screen state.

- [ ] **Step 1: Write failing test** — copy the shape of `test/screens/gotcha_postgame_undo_test.dart`:

```dart
testWidgets('post-game Undo reopens a won 1UP game and restores the eliminated player', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: OneUpGameScreen(
      players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
      config: const OneUpConfig(lives: 1),
    ),
  ));
  await tester.pump();
  final state = tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));
  final engine = (state as dynamic).engineForTest as OneUpEngine;

  // A free-sets 100; B throws 3 misses → fails → eliminated → A wins.
  engine.applyDart(20, 3); engine.applyDart(20, 2); engine.applyDart(0, 1); // 100
  engine.applyDart(0, 1); engine.applyDart(0, 1); engine.applyDart(0, 1);
  expect(engine.gameOver, isTrue);
  (state as dynamic).onGameEndForTest();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(PostGameScreen), findsOneWidget);

  await tester.tap(find.textContaining('Back'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(PostGameScreen), findsNothing);
  expect(engine.gameOver, isFalse);
  expect(engine.livesLeft[1], 1);
});
```

  Expose `@visibleForTesting void onGameEndForTest() => _onGameEnd();` on the state (Shanghai pattern).
- [ ] **Step 2:** Run → FAIL (`_onGameEnd` is a stub).
- [ ] **Step 3: Implement.**
  - `_rankPlayers()`: winner first, then reverse elimination order, then (for aborted games) surviving non-winners by lives desc; exclude skipped seats:

```dart
List<int> _rankPlayers() {
  final ranked = <int>[];
  final w = engine.winnerIndex;
  if (w != null && !engine.isSkipped(w)) ranked.add(w);
  final alive = engine.aliveIndices.where((i) => i != w).toList()
    ..sort((a, b) => engine.livesLeft[b].compareTo(engine.livesLeft[a]));
  ranked.addAll(alive);
  for (final i in engine.eliminationOrder.reversed) {
    if (!engine.isSkipped(i) && !ranked.contains(i)) ranked.add(i);
  }
  return ranked;
}
```

  - `_onGameEnd()`: announce winner + generic winner video (copy Gotcha's game-end announce block), then `_prepareRatingPreview` + `_showPostGame()` — copy Gotcha's `_showPostGame` (gotcha_game_screen.dart:418-474) with: `gameMode: 'oneUp'`, per-player `stats: {'highestTurn': …, 'targetsSet': …, 'livesLost': …, 'turnsSurvived': …, 'lastDartSaves': …, 'elimsDealt': …}` from the engine lists, placements = position in `_rankPlayers()` (no tie-sharing — elimination order is strict), and the same `.then((action) …)` deferred-stats + `'undo'` rewind protocol (guard `engine.canUndo`).
  - `_updateStats(ranking)`: copy Gotcha's `_updateStats` (gotcha_game_screen.dart:332-416) with `gameMode: 'oneUp'`, `modeCounters`: `{'livesLost': …, 'targetsSet': …, 'turnsSurvived': …, 'lastDartSaves': …, 'elimsDealt': …, 'max:highestTurn': …, 'totalDarts': …, 'totalGames': 1}`, `gameConfig: '${widget.config.lives} lives · ${widget.config.variant == OneUpVariant.beatTheBest ? 'Beat the best' : 'Beat the last'}${widget.config.randomOrder ? ' · Shuffle' : ''}'`.
  - `post_game_screen.dart` `_buildStats`, new case after `'gotcha'`:

```dart
      case 'oneUp':
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['targetsSet'] != null) entries.add('Targets: ${stats['targetsSet']}');
        if (stats['livesLost'] != null) entries.add('Lives lost: ${stats['livesLost']}');
        if (stats['turnsSurvived'] != null) entries.add('Turns: ${stats['turnsSurvived']}');
        if (stats['lastDartSaves'] != null && stats['lastDartSaves'] != 0) {
          entries.add('Last-dart saves: ${stats['lastDartSaves']}');
        }
```

- [ ] **Step 4:** Run: `flutter test test/screens/one_up_postgame_undo_test.dart` → PASS. Full suite → no regressions.
- [ ] **Step 5:** Commit: `feat(one-up): post-game with elimination placements, deferred stats, post-game undo`

---

### Task 8: Moments — overlays + announcer

**Files:**
- Modify: `lib/screens/one_up_game_screen.dart`
- Modify: `lib/services/game_announcer.dart`
- Test: `test/screens/one_up_game_screen_test.dart` (extend), `test/services/` only if an announcer test file already covers siblings (check `Glob test/**/*announcer*`; if none, screen-level coverage is enough)

**Interfaces:**
- Produces: `GameAnnouncer.announceOneUp(String phrase, {List<String> soundFolders = const []})`.

- [ ] **Step 1: Announcer method** (after `announceKill`, same pattern):

```dart
  /// 1UP moment (target beaten / life lost / last life / elimination / big target).
  void announceOneUp(String phrase, {List<String> soundFolders = const []}) {
    if (_gameEvents) _tts.speak(phrase);
    if (soundFolders.isNotEmpty) {
      _tts.callWhenIdle(() => _sound.playRandom(soundFolders));
    }
  }
```

- [ ] **Step 2: Overlay state machine** (Wildcard pattern, simplified): `enum _OuOverlay { lifeLost, eliminated, winner }` + `_OuOverlay? _overlay` + `String _momentName = ''` + `int _momentTarget = 0`. Gate `_onDartHit`/`_onMiss` on `_overlay != null`. In `_handleTurnEnd`:

```dart
void _handleTurnEnd(OneUpDartResult result) {
  final seat = _lastThrowerSeat; // capture currentPlayerIndex BEFORE engine advances (store it in _onDartHit before applyDart)
  final name = players[seat].name.toUpperCase();
  if (result.playerWon) {
    _announcer.announceOneUp('${players[engine.winnerIndex!].name} wins! Last player standing!',
        soundFolders: const ['one_up/winner', 'win']);
    setState(() { _overlay = _OuOverlay.winner; _momentName = players[engine.winnerIndex!].name.toUpperCase(); });
    return;
  }
  if (result.eliminated) {
    _announcer.announceOneUp('$name is eliminated!', soundFolders: const ['one_up/eliminated']);
    setState(() { _overlay = _OuOverlay.eliminated; _momentName = name; });
  } else if (result.lostLife) {
    _announcer.announceOneUp('$name loses a life!', soundFolders: const ['one_up/life_lost']);
    setState(() { _overlay = _OuOverlay.lifeLost; _momentName = name; _momentTarget = _failedTarget; });
  } else if (engine.targetSetBy == seat && (engine.target ?? 0) >= 100) {
    _announcer.announceOneUp('${engine.target}! Beat that!');
  }
  _logTurn();
}
```

  (`_failedTarget`: capture `engine.target` before `applyDart` in `_onDartHit` — after a fail in BEAT THE LAST the engine's target is already the new lower number.) Overlay widgets per the JSX `OUOverlay`s: full-frame radial tint (red/red/yellow), 💔 `−1 LIFE` + `<NAME> FAILED TO BEAT <target>`; 💀 `ELIMINATED` + `<NAME> · OUT OF LIVES` + placement (`'${_ordinal(placement)} PLACE'`); `★ ★ ★` `1UP!` + `<NAME> WINS` + `LAST PLAYER STANDING`. Tap anywhere dismisses (`lifeLost`/`eliminated` → clear overlay; `winner` → clear + `_onGameEnd()`). Respect `MediaQuery.disableAnimations` for any pulse (copy `_DangerVignette`'s controller lifecycle if a pulse is added — a static overlay is acceptable v1).
- [ ] **Step 3:** Undo while an overlay is up: `_onUndo` clears `_overlay` first (Wildcard's `_applyUndo` pattern).
- [ ] **Step 4: Tests** — extend the smoke test file:

```dart
testWidgets('life lost overlay appears and tap dismisses', (tester) async {
  // 2 players, 3 lives; A sets 100, B misses out the turn.
  … pump screen, drive engine via state's public dart handler:
  final dyn = state as dynamic;
  dyn.onDartHitForTest(20, 3); dyn.onDartHitForTest(20, 2); dyn.onDartHitForTest(0, 1);
  dyn.onDartHitForTest(0, 1); dyn.onDartHitForTest(0, 1); dyn.onDartHitForTest(0, 1);
  await tester.pump();
  expect(find.text('−1 LIFE'), findsOneWidget);
  expect(find.textContaining('FAILED TO BEAT 100'), findsOneWidget);
  await tester.tapAt(const Offset(400, 600));
  await tester.pump();
  expect(find.text('−1 LIFE'), findsNothing);
});

testWidgets('winner overlay shows 1UP! and leads to post-game', (tester) async {
  … 1-life game as in Task 7 but via onDartHitForTest;
  expect(find.text('1UP!'), findsOneWidget);
  await tester.tapAt(const Offset(400, 600));
  await tester.pump(); await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(PostGameScreen), findsOneWidget);
});
```

  Add `@visibleForTesting void onDartHitForTest(int s, int m) => _onDartHit(s, m);`.
- [ ] **Step 5:** Run the screen test file → PASS. Full suite → no regressions.
- [ ] **Step 6:** Commit: `feat(one-up): life-lost/elimination/winner overlays + announcer hooks`

---

### Task 9: Mid-game add/remove + removed-player regression

**Files:**
- Modify: `lib/screens/one_up_game_screen.dart`
- Test: `test/screens/one_up_postgame_undo_test.dart` (extend)

**Interfaces:**
- Consumes: `showDossedartPlayerSheet` (`dossedart_player_sheet.dart:31-39`), `StatsRecorder.recordMidGameChanges`.
- Produces: `removedPlayerIndicesForTest` getter.

- [ ] **Step 1: Wire the player sheet** — copy Gotcha's `_openDossedartPlayerSheet`/`_addSavedPlayerMidGame`/`_removePlayerMidGame` (gotcha_game_screen.dart:516-565) with 1UP specifics: rows show lives as the score column; `onAdd` → `engine.addPlayer()` + append `Player` + track `_joinedMidGameIds` + `_midGamePlayerChanges = true` + `_log.logRoster(action: 'ADD', …scores: engine.livesLeft)`; `addInfoText: 'Joins next round with ${widget.config.lives} lives'`; `onRemove` → `engine.removePlayer(index)` + `_log.logRoster(action: 'REMOVE', …)` + if `engine.gameOver` → `_onGameEnd()`. Add `@visibleForTesting Set<int> get removedPlayerIndicesForTest => engine.skippedIndices;`.
- [ ] **Step 2: Write regression tests** (engine-level ones exist from Task 4; these are screen-level, same file as Task 7's test):

```dart
testWidgets('1UP: removed mid-game player does not become winner', (tester) async {
  // 3 players, 1 life. A sets 100. Remove A (the target owner) and C via state helpers.
  … pump; drive: A 100; then
  (state as dynamic).removePlayerForTest(0);
  (state as dynamic).removePlayerForTest(2);
  await tester.pump(); await tester.pump(const Duration(milliseconds: 300));
  final engine = (state as dynamic).engineForTest as OneUpEngine;
  expect(engine.winnerIndex, 1);
  expect((state as dynamic).removedPlayerIndicesForTest, {0, 2});
});

testWidgets('1UP: removed player is excluded from the result screen', (tester) async {
  … after the removal-driven game end, PostGameScreen shows only B (winner) —
  expect(find.text('A'), findsNothing);
});
```

  Add `@visibleForTesting void removePlayerForTest(int i) => _removePlayerMidGame(i);`.
- [ ] **Step 3:** Verify `_showPostGame` result-building iterates `if (!engine.isSkipped(i))` and `_updateStats` short-circuits to `recordMidGameChanges` when `_midGamePlayerChanges` (both come from the Task 7 Gotcha copy — confirm, don't assume).
- [ ] **Step 4:** Run: `flutter test test/screens/` → PASS.
- [ ] **Step 5:** Commit: `feat(one-up): mid-game roster via player sheet; removed player never wins`

---

### Task 10: Stats surfaces parity sweep + guards

Every place `'gotcha'` appears as a mode key gets an `'oneUp'` sibling (verified list from grep 2026-07-16):

**Files:**
- Modify: `lib/screens/stats_screen.dart:434` (classic stats — mirror the `case 'gotcha':` block structure with the 1UP counters: `livesLost`, `targetsSet`, `turnsSurvived`, `lastDartSaves`, `max:highestTurn`)
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart:24` (mode color map: `'oneUp': DossedartTokens.lime,`), `:50` (tab list: `('oneUp', '1UP'),`), `:282` (stat-rows case — mirror gotcha's)
- Modify: `lib/stats/profile_stats.dart:90-92` (record tile: `final oneUp = _firstMode(p, ['oneUp']); … RecordTile(mode: 'oneUp', value: '${oneUp.get('highestTurn')}', label: 'best turn')` — same shape as the gotcha tile)
- Explicitly skipped (documented): `lib/stats/mode_progression.dart` (no round-progression chart for 1UP v1 — lives aren't a cumulative score) and `lib/data/achievement_catalog.dart` (no 1UP achievements in v1 spec).

- [ ] **Step 1:** Make the four edits above, following each file's existing gotcha case shape exactly.
- [ ] **Step 2:** Run guards + full suite:
  - `flutter test test/design/no_norwegian_ui_text_test.dart` → PASS
  - `flutter test test/design/` → PASS (color guard sees lime only via tokens)
  - `flutter test test/` → all pass
  - `flutter analyze` → clean
- [ ] **Step 3:** Commit: `feat(one-up): stats surfaces — classic + DOSSEDART stats, profile record tile`

---

### Task 11: Final review gate

- [ ] **Step 1:** Re-read the spec (`2026-07-07-one-up-design.md` rev 2026-07-16) section by section against the implementation; check each §7 edge case has a test.
- [ ] **Step 2:** `flutter test test/` full run + `flutter analyze` → paste output.
- [ ] **Step 3:** Request code review per superpowers:requesting-code-review. Do NOT push — release train, Bjørn triggers CI. Tablet QA (Galaxy Tab emulator) follows per protocol.

---

## Out of scope (guard against creep)

- Home screen redesign (Bjørn's separate track) — only the tile flip + switch case.
- Round events ("only white beds score" …) — v2, spec §9.
- Sound-pack recordings, dedicated winner video, achievements, mode progression chart, Elo display changes.
