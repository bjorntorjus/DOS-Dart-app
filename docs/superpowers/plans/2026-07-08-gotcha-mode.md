# Gotcha Game Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Gotcha game mode (DOSSEDART-only v1): race from 0 to an exact target, landing on an opponent's total resets them, with checkout + kill helpers in a redesigned cockpit scorecard, plus the home screen 3×3 mode grid.

**Architecture:** Engine pattern (CricketEngine snapshot-undo style) in `lib/models/gotcha_engine.dart`; own game screen reusing the shipped X01 DOSSEDART cockpit skeleton (CrtFrame/TopBar/Dartboard/ActionBar/menu/player-sheet) with a new Gotcha scorecard widget; Shanghai's deferred-stats + post-game-undo protocol; setup via `DossedartSetupScaffold`.

**Tech Stack:** Flutter, no new packages. Fonts `PressStart2P`/`VT323` (already bundled).

## Global Constraints

- **DOSSEDART-only v1** (decision 2026-07-08): no classic-home tile, no classic scaffold. Classic `player_setup_screen.dart` gets compile-required cases only.
- **Colors:** `DossedartTokens` only — never `colorScheme`, never raw hex.
- **All UI strings English** (guard test `test/design/no_norwegian_ui_text_test.dart` scans all of `lib/`). Design-JSX Norwegian strings translate as: `MÅL 301` → `TARGET 301`, `INGEN RUTE · > 3 DART` → `NO ROUTE · > 3 DARTS`, `INGEN INNEN 1 DART` → `NONE WITHIN 1 DART`, `NY: GOTCHA 💀` → `NEW: GOTCHA 💀`, `SNART FLERE` → `MORE SOON`.
- **Design fasit:** `docs/design/dossedart-handoff/gotcha/design_handoff_gotcha_home_scorecard/` (README + `gotcha-cockpit-v2.jsx` + `home-gotcha-3x3.jsx`). Rules fasit: `docs/superpowers/specs/2026-07-07-gotcha-design.md`. Spec wins over artboard.
- Coming-soon tiles row 3: **1UP ❤️** (NOT "Legs 🦵" — spec/brief terminology lock), **Golf ⛳**, generic **✨**.
- Mode key string: `'gotcha'` (GameMode.name). Emoji `💀`, label `'Gotcha'`.
- Target selector: 101/201/301/501, default **301**. Min players **2**.
- No new sound assets in v1 (spec §9): `announceKill` speaks TTS "Gotcha!" and calls `playRandom(['gotcha/kill'])` which silently no-ops until files ship. Do NOT declare `assets/sounds/gotcha/kill/` in pubspec.yaml (empty declared dirs break the build).
- Board zone/MISS/ActionBar identical to shipped X01 cockpit (`game_screen.dart:1560-1611`) — do not add the JSX "✗ MISS" corner hints (shipped Flutter X01 has none; parity rules).
- Kill rule interpretation (documented decision): a **0-point dart (miss) never kills** even if an opponent shares the thrower's total — kills require a scoring dart. Test-pinned in Task 3.
- Tests: engine tests are pure Dart; screen tests copy the stub harness from `test/screens/shanghai_postgame_undo_test.dart` (MethodChannel stubs for flutter_tts + battery, `SharedPreferences.setMockInitialValues({})`, `TtsService.instance.resetForTesting()`, `pump()` with Durations — never `pumpAndSettle`).
- Commit after every green task. Branch: `feat/gotcha`.

---

### Task 0: Branch

- [ ] **Step 1:** `git checkout -b feat/gotcha` (from `fix/dossedart-x01-cockpit-fixes` tip — the release-train branch with R1-R5 + specs).
- [ ] **Step 2:** `flutter test test/` → all pass (baseline, ~25s). `flutter analyze` → clean.

---

### Task 1: Straight-out checkout gains `dartsLeft`

**Files:**
- Modify: `lib/data/checkout_table.dart:172-217`
- Test: `test/data/checkout_table_test.dart` (exists from audit R5 — add a new `group`; if the file lives elsewhere, `Glob test/**/*checkout*` first and extend that file)

**Interfaces:**
- Produces: `String? straightOutCheckout(int score, {int dartsLeft = 3})` — space-separated labels (`'T20 D15'`), null when not finishable in ≤ dartsLeft darts. Existing call sites (X01 `_checkoutFor`) unchanged.

- [ ] **Step 1: Write failing tests**

```dart
group('straightOutCheckout dartsLeft', () {
  test('1 dart left: only single-dart finishes', () {
    expect(straightOutCheckout(20, dartsLeft: 1), 'S20');
    expect(straightOutCheckout(40, dartsLeft: 1), 'D20');
    expect(straightOutCheckout(50, dartsLeft: 1), 'Bull');
    expect(straightOutCheckout(41, dartsLeft: 1), isNull);
    expect(straightOutCheckout(61, dartsLeft: 1), isNull);
  });
  test('2 darts left: two-dart routes allowed, three-dart not', () {
    expect(straightOutCheckout(41, dartsLeft: 2), isNotNull);
    expect(straightOutCheckout(180, dartsLeft: 2), isNull); // needs 3 trebles
  });
  test('unreachable values return null even with 3 darts', () {
    for (final v in [163, 166, 169, 172, 173, 175, 176, 178, 179]) {
      expect(straightOutCheckout(v), isNull, reason: '$v');
    }
    expect(straightOutCheckout(180), 'T20 T20 T20');
  });
  test('default keeps existing behavior', () {
    expect(straightOutCheckout(100), isNotNull);
    expect(straightOutCheckout(0), isNull);
    expect(straightOutCheckout(181), isNull);
  });
});
```

- [ ] **Step 2:** Run: `flutter test test/data/checkout_table_test.dart` → FAIL (named param doesn't exist).
- [ ] **Step 3: Implement** — change the signature and gate the 2-/3-dart sections:

```dart
String? straightOutCheckout(int score, {int dartsLeft = 3}) {
  if (score <= 0 || score > 180 || dartsLeft < 1) return null;

  // 1-dart finishes ... (existing body unchanged)

  if (dartsLeft < 2) return null;
  // 2-dart finishes ... (existing body unchanged)

  if (dartsLeft < 3) return null;
  // 3-dart finishes ... (existing body unchanged)

  return null;
}
```

- [ ] **Step 4:** Run the test file → PASS. Run `flutter test test/` → no regressions.
- [ ] **Step 5:** Commit: `feat(gotcha): straightOutCheckout honors darts left in turn`

---

### Task 2: GotchaEngine — scoring, bust, win, snapshot undo

**Files:**
- Create: `lib/models/gotcha_engine.dart`
- Test: `test/models/gotcha_engine_test.dart`

**Interfaces (produces — later tasks depend on these exact names):**

```dart
class GotchaDartResult {
  final int points;        // raw dart value (segment × multiplier)
  final List<int> killed;  // opponent indices reset to 0 by this dart
  final bool isBust;
  final bool turnEnded;
  final bool playerWon;
}
class GotchaEngine {
  GotchaEngine({required int target, required int playerCount});
  final int target;
  late List<int> totals;
  late List<int> killsMade, timesKilled, busts; // per player
  int currentPlayerIndex; int dartsInTurn; int turnStartScore;
  bool gameOver; int? winnerIndex;
  int get playerCount; bool get canUndo;
  bool isSkipped(int i); Set<int> get skippedIndices; int get activePlayerCount;
  static String? singleDartLabel(int value);
  List<(String, int)> killTips();            // (dartLabel, opponentIndex)
  GotchaDartResult applyDart(int segment, int multiplier);
  void undo(); void clearUndoStack();
  void addPlayer({int initialScore = 0}); void removePlayer(int index);
}
```

- [ ] **Step 1: Write failing tests** (core scoring — kills/roster in Task 3):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/gotcha_engine.dart';

void main() {
  group('GotchaEngine core', () {
    test('players start at 0 and climb', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      expect(e.totals, [0, 0]);
      final r = e.applyDart(20, 3); // T20
      expect(r.points, 60);
      expect(e.totals[0], 60);
      expect(e.dartsInTurn, 1);
      expect(r.turnEnded, isFalse);
    });
    test('turn ends after 3 darts and rotation advances', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.applyDart(20, 1); e.applyDart(20, 1);
      final r = e.applyDart(20, 1);
      expect(r.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartsInTurn, 0);
      expect(e.turnStartScore, 0); // next player's turn baseline
    });
    test('exact target wins immediately', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); e.applyDart(20, 2); // 100
      final r = e.applyDart(1, 1);            // 101
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
    });
    test('overshoot busts: revert to turn start, turn ends, bust counted', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); e.applyDart(20, 3); e.applyDart(20, 1); // P0: 140>101? no -> 60,120 bust!
      // recompute: 60 then 120 busts at dart 2
      final e2 = GotchaEngine(target: 101, playerCount: 2);
      e2.applyDart(20, 3);                 // 60
      final r = e2.applyDart(20, 3);       // 120 > 101 → bust
      expect(r.isBust, isTrue);
      expect(r.turnEnded, isTrue);
      expect(e2.totals[0], 0);             // reverted to turn start (0)
      expect(e2.busts[0], 1);
      expect(e2.currentPlayerIndex, 1);
    });
    test('bust reverts to score at START of turn, not previous dart', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.applyDart(20, 1); e.applyDart(20, 1); e.applyDart(20, 1); // P0=60
      e.applyDart(1, 1); e.applyDart(1, 1); e.applyDart(1, 1);    // P1=3
      e.applyDart(20, 3);                                          // P0=120
      final r = e.applyDart(20, 3) /* 180 */;
      expect(r.isBust, isFalse);
      final r2 = e.applyDart(20, 3); // 240 fine (301 target) — craft real bust:
      expect(r2.isBust, isFalse);
      // (301-target bust covered by 101 test above; keep this as turn-baseline test)
      expect(e.totals[0], 240);
    });
    test('snapshot undo restores everything', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); // 60
      final r = e.applyDart(20, 3); // bust → 0, seat advanced
      expect(r.isBust, isTrue);
      e.undo();
      expect(e.totals[0], 60);
      expect(e.busts[0], 0);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 1);
      e.undo();
      expect(e.totals[0], 0);
      expect(e.canUndo, isFalse);
      e.undo(); // empty stack: silent no-op
      expect(e.totals[0], 0);
    });
    test('undo across a win reopens the game', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); e.applyDart(20, 2);
      e.applyDart(1, 1); // win
      expect(e.gameOver, isTrue);
      e.undo();
      expect(e.gameOver, isFalse);
      expect(e.winnerIndex, isNull);
      expect(e.totals[0], 100);
    });
    test('miss (0 points) consumes a dart, cannot bust', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      final r = e.applyDart(0, 0);
      expect(r.points, 0);
      expect(r.isBust, isFalse);
      expect(e.dartsInTurn, 1);
    });
  });
}
```

(Fix the sloppy middle test while writing: keep only assertions that hold — baseline-revert is already covered by the 101-target test.)

- [ ] **Step 2:** Run → FAIL (file missing).
- [ ] **Step 3: Implement** `lib/models/gotcha_engine.dart` (mirror `cricket_engine.dart` structure/comment style):

```dart
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
  });
}

class GotchaEngine {
  final int target;

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

  final Set<int> _skipped = {};
  final List<_GotchaUndoEntry> _undoStack = [];

  int get playerCount => totals.length;

  GotchaEngine({required this.target, required int playerCount}) {
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
            totals[j] = 0;
            timesKilled[j]++;
            killed.add(j);
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
      dartsInTurn = 0;
      _advancePlayer();
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
```

- [ ] **Step 4:** Run `flutter test test/models/gotcha_engine_test.dart` → PASS.
- [ ] **Step 5:** Commit: `feat(gotcha): GotchaEngine — climb scoring, bust, exact win, snapshot undo`

---

### Task 3: GotchaEngine — kills, kill tips, roster

**Files:**
- Modify: `test/models/gotcha_engine_test.dart` (add groups; engine code from Task 2 should already pass most — this task pins behavior)

**Interfaces:** consumes Task 2's engine; no new API.

- [ ] **Step 1: Write the tests** (some pass immediately — that's fine, they pin spec §2/§3.2/§7):

```dart
group('GotchaEngine kills', () {
  GotchaEngine threePlayers({int target = 301}) {
    final e = GotchaEngine(target: target, playerCount: 3);
    // P0 turn: 60. P1 turn: 60? No — engineer P1 to 45, P2 to 0 (untouched).
    e.applyDart(20, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 60
    e.applyDart(15, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P1 = 45
    e.applyDart(0, 0); e.applyDart(0, 0); e.applyDart(0, 0);  // P2 = 0
    return e; // P0's turn, totals [60, 45, 0]
  }

  test('landing exactly on an opponent resets them, thrower keeps score', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.applyDart(15, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 45
    e.applyDart(20, 1); e.applyDart(20, 1); final r0 = e.applyDart(5, 1); // P1 = 45!
    expect(r0.killed, [0]);
    expect(e.totals[0], 0);   // P0 gotcha'd
    expect(e.totals[1], 45);  // thrower unaffected
    expect(e.killsMade[1], 1);
    expect(e.timesKilled[0], 1);
  });
  test('multiple opponents on the same score all reset on one dart', () {
    final e = GotchaEngine(target: 301, playerCount: 3);
    e.applyDart(20, 1); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 20
    e.applyDart(20, 1); e.applyDart(0, 0); e.applyDart(0, 0); // P1 = 20
    final r = e.applyDart(20, 1);                              // P2 = 20 → double kill
    expect(r.killed, [0, 1]);
    expect(e.totals, [0, 0, 20]);
    expect(e.killsMade[2], 2);
  });
  test('players at 0 cannot be killed; miss never kills', () {
    final e = threePlayers(); // [60, 45, 0], P0 throwing
    final r = e.applyDart(0, 0); // miss at 60 — P2 at 0 untouched, no self-kill logic
    expect(r.killed, isEmpty);
    // craft: P1 throws to 60 → P0 at 60 killed, but P2 at 0 never
    e.applyDart(0, 0); e.applyDart(0, 0);           // P0 done
    final r2 = e.applyDart(15, 1);                   // P1: 45+15=60 → kills P0
    expect(r2.killed, [0]);
    expect(e.totals[2], 0); // unchanged, no timesKilled bump
    expect(e.timesKilled[2], 0);
  });
  test('kills stand when the thrower busts later in the same turn', () {
    final e = GotchaEngine(target: 101, playerCount: 2);
    e.applyDart(20, 2); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 40
    e.applyDart(20, 2);                                        // P1 dart1: 40 → kills P0
    expect(e.totals[0], 0);
    final r = e.applyDart(20, 3); // P1: 40+60=100 ok (101) — force real bust:
    expect(r.isBust, isFalse);
    final rBust = e.applyDart(2, 1); // 102 > 101 → bust
    expect(rBust.isBust, isTrue);
    expect(e.totals[1], 40);  // reverted to turn start... (turn started at 0!)
    // Correction: P1's turnStartScore was 0 → totals[1] == 0 after bust.
    // Assert the SPEC point: the kill on P0 is NOT rolled back by the bust.
    expect(e.totals[0], 0);
    expect(e.killsMade[1], 1);
  });
  test('undo across a kill restores the victim', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.applyDart(15, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 45
    e.applyDart(15, 3);                                        // P1 = 45 → kill P0
    expect(e.totals[0], 0);
    e.undo();
    expect(e.totals[0], 45);
    expect(e.killsMade[1], 0);
    expect(e.timesKilled[0], 0);
  });
});

group('GotchaEngine.singleDartLabel', () {
  test('notation preferences per spec §3.2', () {
    expect(GotchaEngine.singleDartLabel(18), 'S18'); // not D9/T6
    expect(GotchaEngine.singleDartLabel(25), '25');
    expect(GotchaEngine.singleDartLabel(50), 'BULL');
    expect(GotchaEngine.singleDartLabel(40), 'D20');
    expect(GotchaEngine.singleDartLabel(57), 'T19');
    expect(GotchaEngine.singleDartLabel(60), 'T20');
    expect(GotchaEngine.singleDartLabel(23), isNull);
    expect(GotchaEngine.singleDartLabel(41), isNull);
    expect(GotchaEngine.singleDartLabel(0), isNull);
    expect(GotchaEngine.singleDartLabel(-5), isNull);
    expect(GotchaEngine.singleDartLabel(61), isNull);
  });
});

group('GotchaEngine.killTips', () {
  test('one tip per killable opponent; dead and trailing excluded', () {
    final e = GotchaEngine(target: 301, playerCount: 4);
    // craft totals directly (white-box, engine lists are public)
    e.totals[0] = 132; e.totals[1] = 149; e.totals[2] = 172; e.totals[3] = 0;
    e.currentPlayerIndex = 0;
    final tips = e.killTips();
    expect(tips, [('S17', 1), ('D20', 2)]); // 149-132=17, 172-132=40; P3 dead
  });
  test('no tips when game over', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.totals[1] = 20; e.gameOver = true;
    expect(e.killTips(), isEmpty);
  });
});

group('GotchaEngine roster', () {
  test('addPlayer joins at initial score and clears undo', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.applyDart(20, 1);
    e.addPlayer(initialScore: 50);
    expect(e.playerCount, 3);
    expect(e.totals[2], 50);
    expect(e.canUndo, isFalse);
  });
  test('removing current player advances the seat and resets turn baseline', () {
    final e = GotchaEngine(target: 301, playerCount: 3);
    e.applyDart(20, 1); // P0 mid-turn
    e.removePlayer(0);
    expect(e.currentPlayerIndex, 1);
    expect(e.dartsInTurn, 0);
    expect(e.isSkipped(0), isTrue);
  });
  test('removal down to one active player ends the game with the survivor', () {
    final e = GotchaEngine(target: 301, playerCount: 3);
    e.removePlayer(0);
    e.removePlayer(2);
    expect(e.gameOver, isTrue);
    expect(e.winnerIndex, 1);
  });
  test('a removed player is never the winner', () {
    final e = GotchaEngine(target: 301, playerCount: 3);
    e.totals[0] = 250; // leader
    e.removePlayer(0);
    e.removePlayer(2);
    expect(e.winnerIndex, 1); // survivor, not the removed leader
  });
});
```

(While writing, clean up the two tests annotated with corrections so assertions match the engine contract — the comments above show the reasoning; final test code must assert the corrected values.)

- [ ] **Step 2:** Run → fix any engine gaps until PASS (expected: all green from Task 2's implementation; treat failures as engine bugs, not test bugs — the spec text wins).
- [ ] **Step 3:** Commit: `test(gotcha): pin kill rules, kill tips, notation, roster behavior`

---

### Task 4: `GameMode.gotcha` + `GotchaConfig` + compile sweep

**Files:**
- Modify: `lib/models/game_mode.dart` (both extensions)
- Modify: `lib/models/game_config.dart` (append subclass)
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart:551` (`_startGame` switch)
- Modify: `lib/screens/player_setup_screen.dart` (`_startGame` dispatch ~:477, `_buildModeOptions` ~:731, new field ~:76)
- Test: `test/models/game_mode_test.dart` (extend if it exists, else create)

**Interfaces:**
- Produces: `GameMode.gotcha` (`label == 'Gotcha'`, `emoji == '💀'`), `GotchaConfig({int targetScore = 301})`.
- Two nav switches get **temporary placeholders** replaced in Tasks 6 (player_setup) and 8 (home).

- [ ] **Step 1:** Failing test:

```dart
test('gotcha mode metadata', () {
  expect(GameMode.gotcha.label, 'Gotcha');
  expect(GameMode.gotcha.emoji, '💀');
  expect(const GotchaConfig().targetScore, 301);
  expect(const GotchaConfig(targetScore: 101).mode, GameMode.gotcha);
});
```

- [ ] **Step 2:** Add enum value + extension cases; append to `game_config.dart`:

```dart
class GotchaConfig extends GameConfig {
  final int targetScore; // 101 / 201 / 301 / 501 — must be hit exactly
  const GotchaConfig({this.targetScore = 301}) : super(GameMode.gotcha);
}
```

- [ ] **Step 3:** `flutter analyze` → fix EVERY "missing case" error it reports. Known sites:
  - `dossedart_home_screen.dart:551` — temporary: `case GameMode.gotcha: throw UnimplementedError('replaced in Task 8');` (tile is not in the modes list yet, case is unreachable).
  - `player_setup_screen.dart:477` — temporary identical placeholder (replaced in Task 6).
  - `player_setup_screen.dart:731` `_buildModeOptions` — real implementation now: add field `int _gotchaTarget = 301;` next to `_shanghaiTargetEnd` and a case mirroring the Shanghai options card (match the file's exact card/row helpers — copy the Shanghai case's wrapper structure verbatim and swap contents):

```dart
case GameMode.gotcha:
  // Target score selector — same SegmentedButton pattern as Shanghai's range.
  ... SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 101, label: Text('101')),
      ButtonSegment(value: 201, label: Text('201')),
      ButtonSegment(value: 301, label: Text('301')),
      ButtonSegment(value: 501, label: Text('501')),
    ],
    selected: {_gotchaTarget},
    onSelectionChanged: (v) => setState(() => _gotchaTarget = v.first),
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
  ),
```

  - If analyze flags other exhaustive switches (e.g. in `AchievementService`), add a sensible `gotcha` case there too — follow the Shanghai case at each site.
- [ ] **Step 4:** `flutter analyze` clean, mode test PASS, full `flutter test test/` green.
- [ ] **Step 5:** Commit: `feat(gotcha): GameMode.gotcha, GotchaConfig, exhaustive-switch sweep`

---

### Task 5: Gotcha scorecard widget (climb bar + helper bars)

**Files:**
- Create: `lib/widgets/dossedart/gotcha/dossedart_gotcha_active_card.dart`
- Test: `test/widgets/dossedart_gotcha_active_card_test.dart`

**Interfaces (produces):**

```dart
class GotchaOpponentTick {
  const GotchaOpponentTick({required this.initial, required this.total, required this.danger});
  final String initial; final int total; final bool danger;
}
class GotchaKillChip {
  const GotchaKillChip({required this.dart, required this.name});
  final String dart; final String name;
}
class DossedartGotchaActiveCard extends StatelessWidget {
  const DossedartGotchaActiveCard({
    required this.playerName, required this.avatarPath, required this.accentColor,
    required this.total, required this.target, required this.currentDartIndex,
    required this.lastTurnLabel, required this.lastTurnSum,
    required this.checkoutRoute,   // 'T20 › D15' or null → dim helper
    required this.kills,           // List<GotchaKillChip>, empty → dim helper
    required this.opponents,       // List<GotchaOpponentTick>
  });
}
```

Design fasit: `gotcha-cockpit-v2.jsx` `ScoreCard`/`ClimbBar`/`HelperBar`/`CheckoutHelper`/`KillHelper`. Match `dossedart_x01_active_card.dart` idiom (same margins/border/glow: margin `fromLTRB(14,12,14,10)`, `Border.all(accentColor, 3)`, surface bg, accent glow blur 14).

- [ ] **Step 1: Failing widget test:**

```dart
Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

testWidgets('default state: both helpers dim with empty texts', (tester) async {
  await tester.pumpWidget(wrap(DossedartGotchaActiveCard(
    playerName: 'Jonas', avatarPath: null, accentColor: DossedartTokens.cyan,
    total: 60, target: 301, currentDartIndex: 1,
    lastTurnLabel: 'S20 · S20 · S20', lastTurnSum: 60,
    checkoutRoute: null, kills: const [],
    opponents: const [
      GotchaOpponentTick(initial: 'K', total: 78, danger: false),
      GotchaOpponentTick(initial: 'M', total: 0, danger: false),
    ],
  )));
  expect(find.text('NO ROUTE · > 3 DARTS'), findsOneWidget);
  expect(find.text('NONE WITHIN 1 DART'), findsOneWidget);
  expect(find.textContaining('TO GO'), findsOneWidget);
  expect(find.text('60'), findsWidgets); // big score
});

testWidgets('active helpers: route text, WIN ▶, kill chips', (tester) async {
  await tester.pumpWidget(wrap(DossedartGotchaActiveCard(
    playerName: 'Jonas', avatarPath: null, accentColor: DossedartTokens.cyan,
    total: 261, target: 301, currentDartIndex: 2,
    lastTurnLabel: 'T19 · S20 · D14', lastTurnSum: 105,
    checkoutRoute: 'D20',
    kills: const [GotchaKillChip(dart: 'S12', name: 'KARI')],
    opponents: const [GotchaOpponentTick(initial: 'K', total: 273, danger: true)],
  )));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('D20'), findsOneWidget);
  expect(find.text('WIN ▶'), findsOneWidget);
  expect(find.text('S12'), findsOneWidget);
  expect(find.text('→ KARI'), findsOneWidget);
  expect(find.text('NO ROUTE · > 3 DARTS'), findsNothing);
});
```

- [ ] **Step 2:** Run → FAIL. **Step 3: Implement.** Structure (all values from the JSX; `PressStart2P`/`VT323` literals like the X01 card):

```dart
// Card container: Container(margin 14/12/14/10, padding fromLTRB(16,13,16,13),
//   color: DossedartTokens.surface, Border.all(accentColor, 3),
//   boxShadow accent alpha .25 blur 16)
// + '▶ NOW THROWING' ribbon: Stack + Positioned(top:-9? use Transform.translate
//   like the NEW ribbon, or a Row chip above — match X01 card simplicity:
//   small accent-bg chip, PressStart2P 9, color DossedartTokens.bg).
//
// Row A (compact header, gap 13):
//   DossedartPlayerAvatar(size: 52, borderColor: accentColor)
//   Expanded(Column: name PressStart2P 17 white ls2 (reuse X01's _nameFontSize
//     downscaling for long names); Row(3 pips 9×9 accent-fill<currentDartIndex,
//     'DART $currentDartIndex/3' VT323 14 white54, '·', 'LAST' VT323 14,
//     lastTurnLabel ?? '—' VT323 16 yellow, if lastTurnSum != null
//     '=$lastTurnSum' PressStart2P 10 yellow))
//   Column(right: Row(baseline: 'SCORE' PressStart2P 9 white55,
//     '$total' PressStart2P 46 accent glow ls-2);
//     'TO GO · $toGo': VT323 16 yellow, number PressStart2P 11)
//
// _ClimbBar (StatefulWidget, AnimationController for danger pulse):
//   track height 14, color Color(0xFF05000E), border accent alpha .27 w2,
//   fill width = total/target fraction, gradient accent55→accent, glow;
//   leading edge: 3px white bar w/ white glow at fraction;
//   per opponent: 2px tick at total/target fraction, extends 9px above/below
//     (SizedBox height 32 + Stack), color: dead(total<=0) white18 /
//     danger DossedartTokens.red + glow + pulse / else phosphor;
//   label above tick: danger ? '💀' : initial (VT323 12);
//   pulse: opacity 1↔0.4, 1s repeat — skip when
//     MediaQuery.of(context).disableAnimations.
//   labels row: '0' … 'CLIMB TO TARGET' … '$target' (yellow), VT323 12.
//
// _HelperBar(tag, tagColor, icon, active, emptyText, child):
//   minHeight 46, border 2 (active? tagColor : white14),
//   bg active? tagColor alpha .07 : white alpha .02,
//   glow active? tagColor alpha .25 blur 14 : none, opacity active?1:0.5;
//   left tag block: icon (grayscale when dim → just Opacity 0.5 wrapper is
//   fine, Flutter has no cheap grayscale filter for emoji) + tag PressStart2P 9;
//   content: child when active else emptyText VT323 15 white40.
//
// CHECKOUT helper: tag 'CHECKOUT', color DossedartTokens.green, icon '🎯',
//   active: checkoutRoute != null; content: Row(Expanded(route PressStart2P 13
//   white, green glow), 'WIN ▶' PressStart2P 9 green glow).
//   emptyText 'NO ROUTE · > 3 DARTS'.
// KILL helper: tag 'KILL', color DossedartTokens.red, icon '💀',
//   active: kills.isNotEmpty; content: Wrap(spacing 8, runSpacing 4, chips:
//   Container(padding 3/8, bg red alpha .13, border red alpha .53 w1,
//   Row(dart PressStart2P 10 Color(0xFFFF8FA6)… — NO raw hex: use
//   DossedartTokens.red for the dart text instead; name '→ NAME' VT323 16
//   white)). emptyText 'NONE WITHIN 1 DART'.
```

Write it as real Flutter code following the X01 card file as the style template. **No raw hex** — the JSX's `#ff8fa6`/`#05000e` map to `DossedartTokens.red` / `DossedartTokens.bg`.

- [ ] **Step 4:** Tests PASS. `flutter analyze` clean.
- [ ] **Step 5:** Commit: `feat(gotcha): DOSSEDART scorecard — compact header, climb bar, checkout+kill helpers`

---

### Task 6: GotchaGameScreen core — cockpit, input, undo

**Files:**
- Create: `lib/screens/gotcha_game_screen.dart`
- Modify: `lib/screens/player_setup_screen.dart` (replace Task 4 placeholder with real dispatch + import)
- Test: `test/screens/gotcha_game_screen_test.dart`

**Interfaces:**
- Consumes: `GotchaEngine` (Task 2/3), `DossedartGotchaActiveCard` + tick/chip types (Task 5), `straightOutCheckout(score, dartsLeft:)` (Task 1), `GotchaConfig` (Task 4).
- Produces: `GotchaGameScreen({required List<Player> players, required GotchaConfig config})` and `@visibleForTesting` hooks: `engineForTest`, `onDartHitForTest(int segment, int multiplier)`, `onUndoForTest()`, `onGameEndForTest()`, `removePlayerForTest(int)`, `updateStatsForTest()`.

**Model the file on `shanghai_game_screen.dart` state/lifecycle (imports, `initState` service wiring, `BatterySampler`, `_log`, `_meme`, `_announcer`, `throwHistory` + `_turnIdCounter`, `_confirmExit`) and on `game_screen.dart:1512-1617` for the cockpit build.** Key mode-specific code:

- [ ] **Step 1: Failing smoke test** (harness copied from `test/screens/shanghai_postgame_undo_test.dart:30-58` — TTS/battery channel stubs, `SharedPreferences.setMockInitialValues({})`, `TtsService.instance.resetForTesting()`; `pump()` with Durations only):

```dart
testWidgets('gotcha cockpit renders and registers darts', (tester) async {
  await tester.pumpWidget(MaterialApp(home: GotchaGameScreen(
    players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
    config: const GotchaConfig(targetScore: 301),
  )));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('💀 GOTCHA · 301'), findsOneWidget);
  expect(find.text('TARGET 301'), findsOneWidget);
  final state = tester.state<dynamic>(find.byType(GotchaGameScreen));
  state.onDartHitForTest(20, 3);
  await tester.pump(const Duration(milliseconds: 100));
  expect(state.engineForTest.totals[0], 60);
  state.onUndoForTest();
  await tester.pump(const Duration(milliseconds: 100));
  expect(state.engineForTest.totals[0], 0);
});

testWidgets('kill helper appears when an opponent is one dart away', (tester) async {
  // pump, then: P0 throws S20×3 (=60); P1 throws S15×3 (=45); P0's dart makes
  // no tip (60>45 → P0 leads). Instead: P1 now throwing, diff 60-45=15 → 'S15'.
  // Assert find.text('S15') inside the kill helper and '→ A'.
});
```

- [ ] **Step 2:** FAIL. **Step 3: Implement the screen:**

```dart
class GotchaGameScreen extends StatefulWidget {
  final List<Player> players;
  final GotchaConfig config;
  const GotchaGameScreen({super.key, required this.players, required this.config});
  ...
}
```

State essentials (beyond the Shanghai-copied service plumbing):

```dart
late GotchaEngine engine; // GotchaEngine(target: widget.config.targetScore, playerCount: players.length)
List<DartThrow> throwHistory = [];
int _turnIdCounter = 0;
int _roundNumber = 0; // increments when rotation wraps to seat lower than previous

void _onDartHit(int segment, int multiplier) {
  if (engine.gameOver) return;
  final playerIdx = engine.currentPlayerIndex;
  final dartNo = engine.dartsInTurn;
  final before = engine.totals[playerIdx];
  final turnStart = engine.turnStartScore;

  late GotchaDartResult result;
  setState(() => result = engine.applyDart(segment, multiplier));

  final delta = engine.totals[playerIdx] - before; // bust → negative revert
  throwHistory.add(DartThrow(
    playerIndex: playerIdx,
    segment: segment,
    multiplier: multiplier,
    points: delta,
    scoreBefore: before,
    turnNumber: dartNo,
    scoreAtStartOfTurn: turnStart,
    turnId: _turnIdCounter,
    roundNumber: _roundNumber,
    isBust: result.isBust,
  ));
  _log.logThrow(...); // same fields as shanghai _onHit

  final label = segment == 0 ? 'miss' : (multiplier == 3 ? 'T$segment' : multiplier == 2 ? 'D$segment' : 'S$segment');
  final memeTriggered = _meme.onThrow(throwHistory.last);

  if (result.playerWon) {
    _onGameEnd();
  } else if (result.isBust) {
    _announcer.announceGameEvent('Bust');       // existing bust sound path
  } else if (result.killed.isNotEmpty) {
    _announcer.announceKill(
        [for (final k in result.killed) players[k].name]);
    // Signature-moment video hook — folder has no assets in v1, silent no-op:
    VideoService.instance.showRandomFromFolder(context, 'gotcha_kill');
  } else if (!memeTriggered) {
    _announcer.announceThrow(segment == 0 ? 'miss' : '${segment * multiplier}');
  }

  if (result.turnEnded && !engine.gameOver) {
    _meme.onTurnEnd();
    _turnIdCounter++;
    if (engine.currentPlayerIndex <= playerIdx) _roundNumber++;
    _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
  }
}

void _onMiss() {
  if (_memeEnabled) SoundService.instance.play('miss/miss');
  _onDartHit(0, 0);
}

void _onUndo() {
  if (engine.gameOver) return;
  if (!engine.canUndo) return;
  setState(() {
    engine.undo();
    if (throwHistory.isNotEmpty) {
      final lastThrow = throwHistory.removeLast();
      _turnIdCounter = lastThrow.turnId;
      _roundNumber = lastThrow.roundNumber;
    }
  });
  _log.logUndo(...);
}
```

Cockpit build — copy `game_screen.dart:1532-1616` verbatim, with these swaps:
- `DossedartTopBar(title: '💀 GOTCHA · ${widget.config.targetScore}', onExit: _confirmExit, trailing: 'TARGET ${widget.config.targetScore}')`
- Active card:

```dart
DossedartGotchaActiveCard(
  playerName: players[cur].name,
  avatarPath: players[cur].avatarPath,
  accentColor: DossedartTokens.cyan, // locked rule: active thrower is cyan
  total: engine.totals[cur],
  target: engine.target,
  currentDartIndex: engine.dartsInTurn,
  lastTurnLabel: throwHistory.recentTurnLabel(cur),
  lastTurnSum: throwHistory.recentTurnLabel(cur) == null
      ? null : throwHistory.recentTurnSum(cur),
  checkoutRoute: _checkoutRoute(),
  kills: _killChips(),
  opponents: _opponentTicks(),
)
```

with helpers (recompute every build → “after every dart and on undo” for free):

```dart
String? _checkoutRoute() {
  final remaining = engine.target - engine.totals[engine.currentPlayerIndex];
  final route =
      straightOutCheckout(remaining, dartsLeft: 3 - engine.dartsInTurn);
  return route?.replaceAll(' ', ' › ');
}

List<GotchaKillChip> _killChips() => [
  for (final (dart, idx) in engine.killTips())
    GotchaKillChip(dart: dart, name: players[idx].name.toUpperCase()),
];

List<GotchaOpponentTick> _opponentTicks() {
  final dangerIdx = {for (final (_, idx) in engine.killTips()) idx};
  return [
    for (int i = 0; i < players.length; i++)
      if (i != engine.currentPlayerIndex && !engine.isSkipped(i))
        GotchaOpponentTick(
          initial: players[i].name.isEmpty ? '?' : players[i].name[0].toUpperCase(),
          total: engine.totals[i],
          danger: dangerIdx.contains(i),
        ),
  ];
}
```

- Board zone + `DossedartX01Dartboard(onTap: ...)` + `DossedartActionBar(onUndo: _onUndo, onMiss: _onMiss, onMenu: ...)` — identical to X01 (`_showDossedartMenu` + `_openDossedartPlayerSheet` copied from Shanghai's, with `primary: '${engine.totals[i]}'`).

`GameAnnouncer` addition (in `lib/services/game_announcer.dart`, next to `announceWinner`):

```dart
/// Gotcha kill: speak the event, then layer the kill sound when TTS is idle.
/// assets/sounds/gotcha/kill/ ships no recordings in v1 (spec §9) —
/// playRandom is a silent no-op until files are added + declared in pubspec.
void announceKill(List<String> victimNames) {
  if (_gameEvents) {
    final names = victimNames.join(' and ');
    _tts.speak(victimNames.length > 1 ? 'Double gotcha! $names back to zero'
                                      : 'Gotcha! $names back to zero');
  }
  _tts.callWhenIdle(() => _sound.playRandom(['gotcha/kill']));
}
```

Replace the Task 4 placeholder in `player_setup_screen.dart:_startGame`:

```dart
case GameMode.gotcha:
  screen = GotchaGameScreen(
    players: players,
    config: GotchaConfig(targetScore: _gotchaTarget),
  );
```

- [ ] **Step 4:** Tests PASS; `flutter analyze` clean; full suite green.
- [ ] **Step 5:** Commit: `feat(gotcha): game screen — cockpit, dart input, kill/checkout helpers, undo`

---

### Task 7: Game-end flow — winner, deferred stats, post-game undo

**Files:**
- Modify: `lib/screens/gotcha_game_screen.dart`
- Test: `test/screens/gotcha_postgame_undo_test.dart`

**Interfaces:** consumes `PostGameScreen(result: GameResult)` action-string contract (`'undo'`/`'home'`), `StatsRecorder.recordGame`, `EloService.updateRatings`, `AchievementService.awardGameEnd`, `buildEarnedFeats`.

Copy Shanghai's `_onGameEnd` / `_prepareRatingPreview` / `_buildPlacements` / `_updateStats` / `_showPostGame` / `_rankPlayers` wholesale (`shanghai_game_screen.dart:253-473`) with these Gotcha substitutions:

- `_rankPlayers()`: sort active (non-skipped) by `engine.totals` desc; if `engine.winnerIndex != null && !engine.isSkipped(engine.winnerIndex!)`, move winner to front.
- `_fireWinnerCelebration`: generic `'winner'` video + `announceWinner` (no instant-Shanghai branch).
- `modeCounters` per non-skipped player with savedPlayerId:

```dart
final highestTurns = _highestTurns();
modeCounters[playerId] = {
  'kills': engine.killsMade[pi],
  'timesKilled': engine.timesKilled[pi],
  'busts': engine.busts[pi],
  'max:highestTurn': highestTurns[pi] ?? 0,
  'totalDarts': throwHistory.where((t) => t.playerIndex == pi).length,
  'totalGames': 1,
};
```

with

```dart
/// Best non-bust 3-dart turn per player, from throwHistory turnId groups.
Map<int, int> _highestTurns() {
  final byTurn = <(int, int), List<DartThrow>>{};
  for (final t in throwHistory) {
    (byTurn[(t.playerIndex, t.turnId)] ??= []).add(t);
  }
  final best = <int, int>{};
  for (final e in byTurn.entries) {
    if (e.value.any((t) => t.isBust)) continue;
    final sum = e.value.fold<int>(0, (s, t) => s + t.points);
    if (sum > (best[e.key.$1] ?? 0)) best[e.key.$1] = sum;
  }
  return best;
}
```

- `_showPostGame` PlayerResult stats map:

```dart
stats: {
  'score': engine.totals[i],
  'kills': engine.killsMade[i],
  'timesKilled': engine.timesKilled[i],
  'busts': engine.busts[i],
  'highestTurn': _highestTurns()[i] ?? 0,
  'darts': throwHistory.where((t) => t.playerIndex == i).length,
},
```

- `GameResult(gameMode: 'gotcha', results: results)`; `recordGame(gameMode: 'gotcha', gameConfig: 'Race to ${widget.config.targetScore}', ...)`.
- `awardGameEnd(mode: GameMode.gotcha, eventsByIndex: const {}, ...)`.
- Post-game `'undo'` branch = Shanghai's exactly (guard `engine.canUndo`, `engine.undo()`, pop `throwHistory`, restore `_turnIdCounter`/`_roundNumber`).

- [ ] **Step 1: Failing test** (clone `shanghai_postgame_undo_test.dart` harness):

```dart
testWidgets('post-game Undo reopens a won gotcha game and restores kill victims',
    (tester) async {
  // target 101: P0 → T20,D20 (=100)+miss? No: T20(60), S20(80)? craft simply:
  // P0: S20,S20,S20 → 60 · P1: S20,S20,S20 → 60?? equal-total kills happen on
  // LANDING — P1's third S20 lands on 60 → kills P0! Good: assert that first.
  // Then P1: D20 dart? Use hooks:
  final state = tester.state<dynamic>(find.byType(GotchaGameScreen));
  // P0 to 60:
  state.onDartHitForTest(20, 1); state.onDartHitForTest(20, 1); state.onDartHitForTest(20, 1);
  // P1 to 41: S20, S20, S1 → 41
  ...
  // P0: S20 → 80, S20 → 100, S1 → 101 exact → game over
  ...
  await tester.pump(const Duration(seconds: 1)); // let winner flow settle
  expect(find.text('↶ Back'), findsOneWidget);
  await tester.tap(find.text('↶ Back'));
  await tester.pump(const Duration(milliseconds: 400));
  expect(state.engineForTest.gameOver, isFalse);
  expect(state.engineForTest.totals[0], 100); // winning dart undone
});

testWidgets('removed mid-game player never wins', (tester) async {
  // 3 players; give P0 the highest total via hooks; removePlayerForTest(0);
  // removePlayerForTest(2) → game over; assert engineForTest.winnerIndex == 1.
});
```

(Flesh the `...` into concrete `onDartHitForTest` sequences while writing — every dart listed explicitly, totals asserted along the way.)

- [ ] **Step 2:** FAIL → **Step 3:** implement game-end flow → **Step 4:** PASS + full suite green.
- [ ] **Step 5:** Commit: `feat(gotcha): winner flow, deferred stats, post-game undo protocol (Shanghai parity)`

---

### Task 8: Mid-game add/remove + setup screen + home 3×3 grid

**Files:**
- Modify: `lib/screens/gotcha_game_screen.dart` (add/remove — copy Shanghai's `_addSavedPlayerMidGame`/`_removePlayerMidGame`/`_openDossedartPlayerSheet` verbatim, `engine.addPlayer(initialScore: avgScore)`)
- Create: `lib/screens/dossedart/dossedart_gotcha_setup_screen.dart`
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (grid + `_startGame` case replaces Task 4 placeholder)

**Setup screen** (clone `dossedart_shanghai_setup_screen.dart`):

```dart
class _DossedartGotchaSetupScreenState extends State<DossedartGotchaSetupScreen> {
  int _targetScore = 301;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'GOTCHA',
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
          label: 'TARGET SCORE',
          value: _targetScore,
          options: const [('101', 101), ('201', 201), ('301', 301), ('501', 501)],
          onChanged: (v) => setState(() => _targetScore = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) =>
      ['$playerCount PLAYERS', 'RACE TO $_targetScore'].join(' · ');

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GotchaGameScreen(
        players: players,
        config: GotchaConfig(targetScore: _targetScore),
      ),
    ));
  }
}
```

**Home screen** — rewrite `_buildModesBlock`/`_modeCell`/`_comingSoonCell` (`dossedart_home_screen.dart:356-438`) per `home-gotcha-3x3.jsx`:

```dart
enum _TileKind { live, fresh, soon }
class _GridTile {
  const _GridTile(this.kind, this.emoji, this.label, {this.mode, this.soonText});
  final _TileKind kind; final String emoji; final String label;
  final GameMode? mode; final String? soonText;
}

static const _gridTiles = [
  _GridTile(_TileKind.live, '🎯', 'Cricket', mode: GameMode.cricket),
  _GridTile(_TileKind.live, '🕐', 'Around the Clock', mode: GameMode.aroundTheClock),
  _GridTile(_TileKind.live, '🔪', 'Killer', mode: GameMode.killer),
  _GridTile(_TileKind.live, '✂️', 'Splitscore', mode: GameMode.halveIt),
  _GridTile(_TileKind.live, '🐉', 'Shanghai', mode: GameMode.shanghai),
  _GridTile(_TileKind.fresh, '💀', 'Gotcha', mode: GameMode.gotcha),
  // Hardcoded placeholders until the modes exist — no dead enum values.
  // 1UP, not "Legs": spec/brief terminology lock (collides with X01 legs/sets).
  _GridTile(_TileKind.soon, '❤️', '1UP', soonText: 'COMING SOON'),
  _GridTile(_TileKind.soon, '⛳', 'Golf', soonText: 'COMING SOON'),
  _GridTile(_TileKind.soon, '✨', 'Coming soon', soonText: 'MORE SOON'),
];
```

`_buildModesBlock`: header row `Text('► OR PICK A LEVEL', _press(11, cyan))` + `SizedBox(width:10)` + `Text('NEW: GOTCHA 💀', _vt(14, color: DossedartTokens.yellow))`; then `for (var i = 0; i < 9; i += 3)` rows of three `Expanded(child: _gridCell(_gridTiles[i+k]))` with the existing 8px gaps.

`_gridCell(_GridTile t)` — states per JSX:
- **live**: `InkWell(onTap: () => _startGame(t.mode!))`, bg `DossedartTokens.surface`, `Border.all(DossedartTokens.phosphor, 2)`, `BoxShadow(phosphor alpha .2, blur 8)`, emoji 28, label `_press(9, Colors.white)`. *(Live tiles change from today's cyan border to phosphor — that IS the handoff design; cyan now marks the new tile.)*
- **fresh** (Gotcha): bg `cyan alpha .06`, `Border.all(cyan, 2)`, glow `cyan alpha .4 blur 16`, label `_press(9, cyan)`, plus `Stack(clipBehavior: Clip.none)` NEW ribbon: `Positioned(top: -9, right: -6, child: Transform.rotate(angle: 5 * math.pi / 180, child: Container(padding 3/7, color: yellow, child: Text('NEW', _press(8, color: DossedartTokens.bg)))))` with yellow glow.
- **soon**: no `InkWell`, `Opacity(0.55)`, `Border.all(magenta alpha .33, 2)` *(solid — Flutter has no native dashed border; same accepted deviation as the X01 checkout strip)*, emoji 28 (24 for ✨), label + `soonText` in `_vt(12, Colors.white54)`.
- Tile padding: `EdgeInsets.symmetric(vertical: 10, horizontal: 8)` (down from 18 — three rows must fit; the DOSSEDART home podium is the tight list variant, no height trim needed).

Replace the Task 4 home placeholder:

```dart
case GameMode.gotcha:
  screen = const DossedartGotchaSetupScreen();
```

- [ ] **Step 1:** Widget test first (add to `test/screens/gotcha_game_screen_test.dart`): mid-game add joins at average / removal announces next player is NOT required (no announcer assert) — assert engine state: after `removePlayerForTest(0)` mid-turn, `engine.currentPlayerIndex == 1` and `updateStatsForTest()` completes without recording a game (roster changed → early return).
- [ ] **Step 2:** FAIL → implement → PASS.
- [ ] **Step 3:** Manual check: `flutter run` on the Galaxy Tab emulator → home shows 3×3 with NEW ribbon; Gotcha tile → setup → game; soon-tiles not tappable.
- [ ] **Step 4:** `flutter analyze` + full suite green.
- [ ] **Step 5:** Commit: `feat(gotcha): setup screen, mid-game roster, home 3×3 grid with 1UP/Golf coming-soon tiles`

---

### Task 9: Stats surfaces

**Files:**
- Modify: `lib/screens/post_game_screen.dart:236` (`_buildStats`)
- Modify: `lib/screens/stats_screen.dart:422` (`_buildModeDetailStats` + new `_buildGotchaStats`)
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart:249` (`_modeExtras`)
- Modify: `lib/screens/dossedart/game_detail_screen.dart:509` (`progressionForEntry`)

- [ ] **Step 1:** post_game rows:

```dart
case 'gotcha':
  if (stats['kills'] != null) entries.add('Kills: ${stats['kills']}');
  if (stats['timesKilled'] != null) entries.add('Killed: ${stats['timesKilled']}');
  if (stats['busts'] != null) entries.add('Busts: ${stats['busts']}');
  if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
  if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
```

- [ ] **Step 2:** stats_screen — `case 'gotcha': return _buildGotchaStats(ms);` and (mirror `_buildX01Stats` grid helper usage):

```dart
List<Widget> _buildGotchaStats(ModeStats ms) {
  return [
    _buildStatsGrid([
      _StatItem('💀', 'Kills', '${ms.get('kills')}'),
      _StatItem('🪦', 'Times killed', '${ms.get('timesKilled')}'),
      _StatItem('💥', 'Busts', '${ms.get('busts')}'),
      _StatItem('⚡', 'Best turn', ms.get('highestTurn') > 0 ? '${ms.get('highestTurn')}' : '-'),
    ]),
  ];
}
```

- [ ] **Step 3:** dossedart `_modeExtras`:

```dart
case 'gotcha':
  return ['kills ${ms.get('kills')}', 'best turn ${ms.get('highestTurn')}'];
```

- [ ] **Step 4:** progression — Gotcha counts up; DartThrow.points is the true thrower delta (bust darts carry the negative revert), so cumulative-by-round tracks the thrower's real total. Kill resets on the *victim's* line are invisible to their own throws — same accepted limitation as Splitscore's halving (see the class comment):

```dart
case 'gotcha':
  return CumulativeScoreProgression(maxValue: 0);
```

- [ ] **Step 5:** `flutter analyze` + full suite. Manual: finish a Gotcha game (emulator), check post-game rows, stats screens, KAMPDETALJER graph + round log.
- [ ] **Step 6:** Commit: `feat(gotcha): post-game stat rows, per-mode stats, match-detail progression`

---

### Task 10: Full verification + review

- [ ] **Step 1:** `flutter analyze` → 0 issues.
- [ ] **Step 2:** `flutter test test/` → all green (expect ~460+ tests, <40s). Guard test passes with the new screens.
- [ ] **Step 3:** `flutter test integration_test/` if emulator available, else note skipped.
- [ ] **Step 4:** Manual emulator pass (Galaxy Tab): full game with a kill (announcement fires), a bust, a win (video + winner announcement), post-game Undo returns to play, mid-game add/remove, stats recorded, home tile states.
- [ ] **Step 5:** Run superpowers:requesting-code-review against the spec + handover README.
- [ ] **Step 6:** Final commit + hold for Bjørn: push/PR only when he says so (release-train rule).

---

## Self-review notes (already applied)

- Spec §3.1 route separator: design shows `T20 › D15`; utility returns space-separated — the screen's `_checkoutRoute()` maps `' '` → `' › '`.
- Spec §7 "bust dart cannot kill": structurally guaranteed (bust branch skips kill check) + pinned by test.
- Spec §7 "two+ opponents same score → all reset": Task 3 multi-kill test.
- Spec §4.4 "post-game Undo must work": Task 7 clones the Shanghai protocol including deferred stats.
- Spec §6 removed-player-wins: engine winner logic + Task 7 regression test.
- F19 pattern: screen delegates ALL rules to `GotchaEngine`; screen keeps only display state (`throwHistory`, `_turnIdCounter`, `_roundNumber`).
- Handover "helpers always present so layout never jumps": both HelperBars render in dim state — board zone is bottom-anchored anyway (X01 pattern), double protection.
- No Norwegian literals anywhere (guard test); no raw hex (JSX `#ff8fa6`/`#05000e` mapped to tokens); no `colorScheme` in DOSSEDART files.
