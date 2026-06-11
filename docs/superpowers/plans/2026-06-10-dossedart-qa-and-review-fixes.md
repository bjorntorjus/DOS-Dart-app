# DOSSEDART QA + Code-Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 10 verified code-review findings + 2 verified cleanup findings + 5 tablet-QA points on branch `fix/dossedart-x01-cockpit-fixes`, including a one-time revocation of falsely granted achievements (APK 1.8.3+18 is already in testers' hands).

**Architecture:** The achievement bugs share one root cause — feat detection reads raw game state that is not undo- and bust-aware. The deep fix: derive feats from `throwHistory` wherever possible (history is popped on undo, so it is always consistent), and snapshot/restore counters in undo-data where history can't express the feat (Killer kills, Splitscore clutch). UI fixes restore the fixed-board invariant, the spec glow, and extract the duplicated active-strip into shared chrome.

**Tech Stack:** Flutter (no external state mgmt), SharedPreferences via PlayerStorage, `flutter test`.

**Out of scope (explicit):**
- X01 dartboard colors (TWILIGHT) — separate HTML-proposal round with Bjørn, NOT in this plan.
- Efficiency findings (startup retro-scan, stats-tab rebuilds) — not in the agreed fix list.
- Shanghai mid-game-change stats inconsistency — noted for later, not in this plan.

**Decisions locked with Bjørn (2026-06-10):**
1. Streak tracking is wired now (StatsRecorder), making the 4 streak badges obtainable.
2. ALL affected badges are revoked once for every player: `cri_the_nine`, `x01_maximum`, `x01_bullseye_finish`, `kil_killing_spree`, `spl_clutch_save`, `x_natural_talent`, `x_giant_slayer`.
3. Achievement descriptions: always visible in the gallery; short-press dialog in the stats PRESTASJONER section.
4. Win semantics: a tie (shared best placement) is a draw — nobody "wins" for achievements/streaks/gamesWon.

---

## Del A — Achievement-integritet

### Task 1: `DartThrow.isBust` field + X01 passes classified outcome

Fixes review finding 5b (no-bust overshoot counted as bust) and lays the foundation for findings 2 and 5a.

**Files:**
- Modify: `lib/models/dart_throw.dart` (constructor, ~line 12-22)
- Modify: `lib/screens/game_screen.dart:303-337` (`_onDartHit` bust computation)
- Test: `test/models/dart_throw_test.dart` (create if missing)

- [ ] **Step 1: Write the failing test**

```dart
// test/models/dart_throw_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart'; // adjust package name to pubspec `name:`

void main() {
  test('isBust defaults to false and round-trips through constructor', () {
    final t = DartThrow(
      playerIndex: 0,
      segment: 20,
      multiplier: 3,
      points: 60,
      scoreBefore: 100,
      turnNumber: 0,
      scoreAtStartOfTurn: 100,
    );
    expect(t.isBust, isFalse);

    final bust = DartThrow(
      playerIndex: 0,
      segment: 20,
      multiplier: 3,
      points: 60,
      scoreBefore: 40,
      turnNumber: 1,
      scoreAtStartOfTurn: 100,
      isBust: true,
    );
    expect(bust.isBust, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/dart_throw_test.dart`
Expected: FAIL — `isBust` is not defined.

- [ ] **Step 3: Add the field to the model**

In `lib/models/dart_throw.dart`, add to the class:

```dart
  /// True when this dart busted the turn (standard X01 rules). No-bust mode
  /// never sets this — overshoot there is a legal turn end, not a bust.
  final bool isBust;
```

and to the constructor parameter list:

```dart
    this.isBust = false,
```

- [ ] **Step 4: Make X01 derive isBust from `_classifyThrow` and pass it**

In `lib/screens/game_screen.dart` `_onDartHit` (~line 303-325), REPLACE the manual bust block:

```dart
  bool isBust = false;

  final needsSpecialOut = widget.masterOut != 'none';
  final isValidOut = widget.masterOut == 'double'
      ? multiplier == 2
      : widget.masterOut == 'master'
          ? multiplier >= 2
          : true;

  if (newScore < 0) {
    isBust = true;
  } else if (newScore == 0 && needsSpecialOut && !isValidOut) {
    isBust = true;
  } else if (newScore == 1 && needsSpecialOut) {
    isBust = true;
  }
```

with:

```dart
  // Single source of truth for outcome classification — no-bust mode never
  // produces a bust (overshoot is a legal turn end there).
  final isBust = _classifyThrow(newScore, multiplier) == _ThrowOutcome.bust;
```

NOTE: `_classifyThrow` (line ~203) reproduces exactly the deleted standard-path logic and returns `turnEndNoBust`/`finish` in no-bust mode. Keep the `if (isBust) { _bustsByPlayer... }` increment for now — Task 2 deletes it. If `needsSpecialOut`/`isValidOut` locals are used further down in `_onDartHit`, keep their declarations (only the `isBust` if-chain is replaced).

Then add `isBust: isBust,` to the `DartThrow(` construction (~line 327-337):

```dart
  final dartThrow = DartThrow(
    playerIndex: currentPlayerIndex,
    segment: segment,
    multiplier: multiplier,
    points: points,
    scoreBefore: scoreBefore,
    turnNumber: dartsInTurn,
    scoreAtStartOfTurn: scoreAtStartOfTurn,
    turnId: _turnIdCounter,
    roundNumber: _roundNumber,
    isBust: isBust,
  );
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/models/dart_throw_test.dart && flutter test test/screens/`
Expected: PASS (existing X01 behavior unchanged — same classification logic, new plumbing only).

- [ ] **Step 6: Commit**

```bash
git add lib/models/dart_throw.dart lib/screens/game_screen.dart test/models/dart_throw_test.dart
git commit -m "fix(x01): classify bust via _classifyThrow and record it on DartThrow"
```

---

### Task 2: SURGEON — derive bustCount from history, delete `_bustsByPlayer`

Fixes review finding 5 (undone bust permanently denies SURGEON).

**Files:**
- Modify: `lib/screens/game_screen.dart` (delete field ~line 82, delete increment ~line 322-324, change counter build ~line 764)
- Test: `test/screens/x01_bust_counter_test.dart` (create)

- [ ] **Step 1: Write the failing test**

The screen needs a tiny test hook. Pattern: `removePlayerForTest` in the same file already exists for widget tests with `dynamic` state access.

```dart
// test/screens/x01_bust_counter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';

void main() {
  testWidgets('undone bust does not count toward bustCount', (tester) async {
    final players = [Player(name: 'P0', score: 41), Player(name: 'P1', score: 41)];
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: players,
        startingScore: 41, // small score so a T20 busts immediately
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic state =
        tester.state<State<GameScreen>>(find.byType(GameScreen));

    state.onDartHitForTest(20, 3); // 41-60 → bust, recorded in history
    await tester.pumpAndSettle();
    state.undoForTest();           // pops the bust throw
    await tester.pumpAndSettle();

    expect(state.bustCountForTest(0), 0,
        reason: 'an undone bust must not count toward SURGEON');
  });
}
```

NOTE: adapt `GameScreen` constructor args to the real signature (check how `removed_player_winner_test.dart` constructs it). Add the three `@visibleForTesting` hooks in Step 3 if they don't exist: `onDartHitForTest` → `_onDartHit`, `undoForTest` → `_undo`, `bustCountForTest(i)` → the history derivation.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/x01_bust_counter_test.dart`
Expected: FAIL (hooks missing / counter still counts 1).

- [ ] **Step 3: Implement — derive from history**

In `lib/screens/game_screen.dart`:

1. DELETE the field declaration (~line 82): `final Map<int, int> _bustsByPlayer = {};`
2. DELETE the increment (~line 322-324):
```dart
  if (isBust) {
    _bustsByPlayer[currentPlayerIndex] =
        (_bustsByPlayer[currentPlayerIndex] ?? 0) + 1;
  }
```
3. REPLACE the counter build (~line 764) `counters[i] = {'bustCount': _bustsByPlayer[i] ?? 0};` with:
```dart
      counters[i] = {'bustCount': _bustCountFor(i)};
```
4. ADD next to the other helpers:
```dart
  /// Busts derived from history — undo pops the throw, so this is always
  /// consistent (a counter would survive undo and corrupt SURGEON).
  int _bustCountFor(int playerIndex) =>
      throwHistory.where((t) => t.playerIndex == playerIndex && t.isBust).length;

  @visibleForTesting
  int bustCountForTest(int playerIndex) => _bustCountFor(playerIndex);

  @visibleForTesting
  Future<void> onDartHitForTest(int segment, int multiplier) =>
      _onDartHit(segment, multiplier);

  @visibleForTesting
  void undoForTest() => _undo();
```
(Skip any hook that already exists.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/x01_bust_counter_test.dart && flutter test`
Expected: PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart test/screens/x01_bust_counter_test.dart
git commit -m "fix(x01): derive bustCount from throw history so undo cannot corrupt SURGEON"
```

---

### Task 3: X01 feats ignore busted darts (MAXIMUM / BULLSEYE FINISH)

Fixes review finding 2.

**Files:**
- Modify: `lib/utils/x01_achievement_feats.dart:23-40`
- Test: `test/utils/x01_achievement_feats_test.dart` (extend existing)

- [ ] **Step 1: Write the failing tests**

Add to the existing test file (mirror its helper style for constructing DartThrows; add `isBust:` where shown):

```dart
  test('busted 180 does not grant MAXIMUM', () {
    // 181 left: T20, T20, T20 — third dart leaves 1 → bust in double-out.
    final throws = [
      _t(seg: 20, mult: 3, scoreBefore: 181, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 121, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 61, turnId: 1, isBust: true),
    ];
    final feats = X01Feats.analyze(throws);
    expect(feats.hit180, isFalse);
  });

  test('clean 180 still grants MAXIMUM', () {
    final throws = [
      _t(seg: 20, mult: 3, scoreBefore: 501, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 441, turnId: 1),
      _t(seg: 20, mult: 3, scoreBefore: 381, turnId: 1),
    ];
    expect(X01Feats.analyze(throws).hit180, isTrue);
  });

  test('busted single bull at 25 does not grant BULLSEYE FINISH', () {
    final throws = [
      _t(seg: 25, mult: 1, scoreBefore: 25, turnId: 1, isBust: true),
    ];
    expect(X01Feats.analyze(throws).bullFinish, isFalse);
  });

  test('D-bull checkout grants BULLSEYE FINISH', () {
    final throws = [
      _t(seg: 25, mult: 2, scoreBefore: 50, turnId: 1),
    ];
    expect(X01Feats.analyze(throws).bullFinish, isTrue);
  });
```

Extend the file's `_t` helper with `isBust` (default false) and make `points` = seg*mult if the helper computes it.

- [ ] **Step 2: Run to verify the two bust tests fail**

Run: `flutter test test/utils/x01_achievement_feats_test.dart`
Expected: the two "busted" tests FAIL.

- [ ] **Step 3: Implement**

In `lib/utils/x01_achievement_feats.dart` `analyze`:
- In the per-turn grouping (group by `turnId`), skip any turn containing a busted dart before checking `total == 180`:
```dart
      if (turn.any((t) => t.isBust)) continue;
```
- In the bullFinish check (~line 37-38), add the bust guard:
```dart
    final bullFinish = playerThrows
        .any((t) => t.segment == 25 && t.scoreBefore == t.points && !t.isBust);
```

- [ ] **Step 4: Run tests** — `flutter test test/utils/x01_achievement_feats_test.dart` → all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/x01_achievement_feats.dart test/utils/x01_achievement_feats_test.dart
git commit -m "fix(achievements): busted darts no longer grant MAXIMUM or BULLSEYE FINISH"
```

---

### Task 4: Cricket turnId + dead-target-aware marks (THE NINE)

Fixes review finding 1 (most severe — THE NINE unlocks for everyone) including the dead-target sub-defect.

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` (add `_turnIdCounter`, pass turnId, restore on undo)
- Modify: `lib/utils/cricket_achievement_feats.dart` (replay-based marks)
- Modify: the call site `lib/screens/cricket_game_screen.dart:573-577`
- Test: `test/utils/cricket_achievement_feats_test.dart` (rewrite), `test/screens/cricket_turn_id_test.dart` (create)

- [ ] **Step 1: Write the failing feats tests (rewrite the unit test file)**

```dart
// test/utils/cricket_achievement_feats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/utils/cricket_achievement_feats.dart';

DartThrow _t(int player, int seg, int mult, int turnId) => DartThrow(
      playerIndex: player,
      segment: seg,
      multiplier: mult,
      points: 0,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turnId,
    );

void main() {
  final targets = {15, 16, 17, 18, 19, 20, 25};

  test('nine marks in ONE turn → 9', () {
    final throws = [
      _t(0, 20, 3, 1), _t(0, 19, 3, 1), _t(0, 18, 3, 1),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 9);
  });

  test('nine marks spread over three turns → max 3 (turnId regression)', () {
    final throws = [
      _t(0, 20, 3, 1), _t(0, 19, 3, 3), _t(0, 18, 3, 5),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 3);
  });

  test('marks on a target closed by ALL players count 0 (dead target)', () {
    final throws = [
      // both players close 20 first (3 marks each)
      _t(0, 20, 3, 1),
      _t(1, 20, 3, 2),
      // now 20 is dead — a T20 turn scores no real marks
      _t(0, 20, 3, 3), _t(0, 20, 3, 3), _t(0, 20, 3, 3),
    ];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 3,
        reason: 'best real turn is the opening T20; the dead-target turn is 0');
  });

  test('non-target segments count 0', () {
    final throws = [_t(0, 5, 3, 1), _t(0, 20, 2, 1)];
    expect(cricketMaxMarksInTurn(throws, targets, 0, 2), 2);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/utils/cricket_achievement_feats_test.dart`
Expected: FAIL — new signature doesn't exist / dead-target case wrong.

- [ ] **Step 3: Rewrite the feats util (replay closure state)**

Replace the contents of `lib/utils/cricket_achievement_feats.dart`:

```dart
import '../models/dart_throw.dart';

/// Max real marks scored by [playerIndex] in a single turn, replayed from the
/// FULL chronological [allThrows] (every player) so closure state is known at
/// each dart: a hit on a target closed by ALL players (dead) scores 0 marks.
/// History-derived → automatically undo-safe.
int cricketMaxMarksInTurn(
  List<DartThrow> allThrows,
  Set<int> targets,
  int playerIndex,
  int playerCount,
) {
  final marks = List.generate(playerCount, (_) => <int, int>{});
  final marksByTurn = <int, int>{};
  for (final t in allThrows) {
    if (!targets.contains(t.segment)) continue;
    if (t.playerIndex >= playerCount) continue;
    final dead = List.generate(
            playerCount, (p) => (marks[p][t.segment] ?? 0) >= 3)
        .every((closed) => closed);
    final gained = dead ? 0 : t.multiplier;
    marks[t.playerIndex][t.segment] =
        (marks[t.playerIndex][t.segment] ?? 0) + t.multiplier;
    if (t.playerIndex == playerIndex && gained > 0) {
      marksByTurn[t.turnId] = (marksByTurn[t.turnId] ?? 0) + gained;
    }
  }
  return marksByTurn.values.fold(0, (m, v) => v > m ? v : m);
}
```

(Delete the old `cricketMarksForDart` helper if nothing else uses it — verify with grep first.)

- [ ] **Step 4: Wire turnId in the Cricket screen**

In `lib/screens/cricket_game_screen.dart`:
1. Add field near the other turn state: `int _turnIdCounter = 0;`
2. In `_advancePlayer` (~line 350), after `dartsInTurn = 0;` add: `_turnIdCounter++;`
3. In the `DartThrow(` construction (~line 183-191) add: `turnId: _turnIdCounter,`
4. In `_undo` (~line 368-388), after `throwHistory.removeLast();` add:
```dart
      _turnIdCounter = lastThrow.turnId;
```
(`lastThrow` is already captured at the top of `_undo` — same pattern as X01 `game_screen.dart:1204`.)

- [ ] **Step 5: Update the game-end call site**

At `cricket_game_screen.dart:573-577`, change the call to the new signature:

```dart
      if (cricketMaxMarksInTurn(
              throwHistory, targetSet, i, players.length) >= 9) {
```
(The old call filtered `throwHistory.where((t) => t.playerIndex == i)` — pass the FULL history now; the function filters internally and needs all players for closure state.)

- [ ] **Step 6: Write the screen-level turnId regression test**

```dart
// test/screens/cricket_turn_id_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

void main() {
  testWidgets('cricket throws get distinct turnIds per turn', (tester) async {
    final players = [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)];
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(players: players /* + required config args */),
    ));
    await tester.pumpAndSettle();
    final dynamic state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    // P0 full turn (3 darts) then P1's first dart
    state.registerHitForTest(20, 1);
    state.registerHitForTest(20, 1);
    state.registerHitForTest(20, 1);
    await tester.pumpAndSettle();
    state.registerHitForTest(19, 1);
    await tester.pumpAndSettle();

    final ids = state.throwHistory.map((t) => t.turnId).toSet();
    expect(ids.length, 2, reason: 'two turns → two distinct turnIds');
  });
}
```

Adapt constructor args to the real `CricketGameScreen` signature (see `removed_player_winner_test.dart`), and add `@visibleForTesting void registerHitForTest(int seg, int mult) => _registerHit(seg, mult);` to the screen if missing. `throwHistory` is accessible via dynamic state if it's a public field; otherwise add a getter.

- [ ] **Step 7: Run all tests** — `flutter test` → PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/cricket_game_screen.dart lib/utils/cricket_achievement_feats.dart test/utils/cricket_achievement_feats_test.dart test/screens/cricket_turn_id_test.dart
git commit -m "fix(achievements): THE NINE requires 9 real marks in ONE turn (turnId + dead-target replay)"
```

---

### Task 5: Killer KILLING SPREE undo-safe

Fixes review finding 3.

**Files:**
- Modify: `lib/screens/killer_game_screen.dart` (`_KillerUndoData` ~1778-1796, undo-push site, `_undo` ~531-573)
- Test: `test/screens/killer_kills_undo_test.dart` (create)

- [ ] **Step 1: Extend `_KillerUndoData`**

Add two fields + constructor params to the class (~line 1778):

```dart
  final int killsThisTurnBefore;
  final Map<int, int> maxKillsInTurnBefore;
```

At the `_undoStack.add(_KillerUndoData(...))` push site (find it where lives/shields snapshots are taken), add:

```dart
      killsThisTurnBefore: _killsThisTurn,
      maxKillsInTurnBefore: Map.of(_maxKillsInTurn),
```

- [ ] **Step 2: Restore in `_undo`**

In the playing-phase setState block of `_undo` (~line 552-564), after `shields = data.shieldsBefore;` add:

```dart
    _killsThisTurn = data.killsThisTurnBefore;
    _maxKillsInTurn
      ..clear()
      ..addAll(data.maxKillsInTurnBefore);
```

- [ ] **Step 3: Write the regression test**

```dart
// test/screens/killer_kills_undo_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';

void main() {
  testWidgets('undone elimination does not count toward KILLING SPREE',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(players: players /* + required config args */),
    ));
    await tester.pumpAndSettle();
    final dynamic state =
        tester.state<State<KillerGameScreen>>(find.byType(KillerGameScreen));

    // Drive assignment phase + set up P1 at 1 life as P0 (killer) — use the
    // screen's test hooks / direct state, mirroring how killer tests elsewhere
    // in test/ arrange phase. Then:
    state.onDartHitForTest(/* P1's number */ 5, 1); // eliminates P1 → kill
    await tester.pumpAndSettle();
    state.undoForTest();
    await tester.pumpAndSettle();

    expect(state.killsThisTurnForTest, 0,
        reason: 'undo must roll back the kill counter');
    expect(state.maxKillsInTurnForTest[0] ?? 0, 0);
  });
}
```

Add `@visibleForTesting` getters `killsThisTurnForTest` / `maxKillsInTurnForTest` and hooks for `_onDartHit`/`_undo` if missing. Arranging Killer state (assignment phase) is fiddly — set `phase`, `assignedNumbers`, `lives`, `isKiller` directly through the dynamic state in the test if no hook exists; that is acceptable for a regression test.

- [ ] **Step 4: Run** — `flutter test test/screens/killer_kills_undo_test.dart && flutter test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/killer_game_screen.dart test/screens/killer_kills_undo_test.dart
git commit -m "fix(killer): undo rolls back kill counters so KILLING SPREE cannot be granted falsely"
```

---

### Task 6: Splitscore CLUTCH SAVE undo-safe

Fixes review finding 4. Same pattern as Task 5.

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart` (`_HalveItUndoData` ~1790-1808, push site ~before line 147, `_undo` ~334-362)
- Test: `test/screens/halve_it_clutch_undo_test.dart` (create)

- [ ] **Step 1: Extend `_HalveItUndoData`**

Add field + constructor param:

```dart
  final Set<int> clutchSaversBefore;
```

At the `_undoStack.add(_HalveItUndoData(...))` push site add:

```dart
      clutchSaversBefore: Set.of(_clutchSavers),
```

- [ ] **Step 2: Restore in `_undo`**

In the setState block (~line 341-352), after `turnHasHit = data.turnHasHit;` add:

```dart
    _clutchSavers
      ..clear()
      ..addAll(data.clutchSaversBefore);
```

- [ ] **Step 3: Regression test**

```dart
// test/screens/halve_it_clutch_undo_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

void main() {
  testWidgets('undone third-dart hit removes the clutch-save flag',
      (tester) async {
    final players = [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)];
    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(players: players /* + required config args */),
    ));
    await tester.pumpAndSettle();
    final dynamic state = tester
        .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));

    state.onMissForTest();          // dart 1 miss
    state.onMissForTest();          // dart 2 miss
    state.onDartHitForTest(20, 1);  // dart 3 hit → clutch flagged
    await tester.pumpAndSettle();
    expect(state.clutchSaversForTest, contains(0));

    state.undoForTest();            // undo the saving dart
    await tester.pumpAndSettle();
    expect(state.clutchSaversForTest, isNot(contains(0)),
        reason: 'undo must unwind the clutch flag');
  });
}
```

Add `@visibleForTesting` hooks (`onMissForTest`, `onDartHitForTest`, `undoForTest`, `clutchSaversForTest`) as needed. Adapt the hit segment to the active round's target (round 1's target — check `rounds[0]`; use a config whose first round accepts segment 20, or read `rounds[currentRoundIndex]` in the test to pick a valid segment).

- [ ] **Step 4: Run** — `flutter test test/screens/halve_it_clutch_undo_test.dart && flutter test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/halve_it_game_screen.dart test/screens/halve_it_clutch_undo_test.dart
git commit -m "fix(splitscore): undo unwinds clutch-save flag"
```

---

### Task 7: Strict-win semantics on ties (achievements + stats + gamesWon)

Fixes review finding 6. Decision: shared best placement = draw, nobody wins.

**Files:**
- Modify: `lib/services/achievement_service.dart:79-99`
- Modify: `lib/services/stats_recorder.dart:26-40`
- Modify: `lib/screens/halve_it_game_screen.dart:386-403` (gamesWon tie guard)
- Modify: `lib/screens/shanghai_game_screen.dart` (same guard IF it increments gamesWon on a tie-able placement — grep `gamesWon++` first)
- Test: `test/services/achievement_tie_test.dart` (create), extend `test/services/stats_recorder_test.dart` if it exists

- [ ] **Step 1: Failing test for the service**

```dart
// test/services/achievement_tie_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('tied placements [1,1] do not count as a win for either player', () {
    AchievementService.instance.registerCatalog(achievementCatalog);
    final a = SavedPlayer(id: 'a', name: 'A')..gamesPlayed = 1;
    final b = SavedPlayer(id: 'b', name: 'B')..gamesPlayed = 1;

    AchievementService.instance.awardGameEnd(
      mode: GameMode.halveIt,
      playerIds: ['a', 'b'],
      savedPlayers: [a, b],
      placements: [1, 1],
      ratingsBefore: {'a': 1000, 'b': 1000},
      ratingsAfter: {'a': 1000, 'b': 1000},
    );

    // NATURAL TALENT = win the very first game → must NOT unlock on a tie.
    expect(a.unlockedAchievementIds, isNot(contains('x_natural_talent')));
    expect(b.unlockedAchievementIds, isNot(contains('x_natural_talent')));
  });
}
```

Adapt `SavedPlayer` constructor to its real required params.

- [ ] **Step 2: Run to verify it fails** (both currently unlock NATURAL TALENT).

- [ ] **Step 3: Implement**

`achievement_service.dart` (~line 79): after computing `best`, add:

```dart
    final bestIsShared = placements.where((p) => p == best).length > 1;
```

and change the outcome (~line 99): `won: placements[i] == best && !bestIsShared,`

`stats_recorder.dart` (~line 26): after `bestPlacement`, add the same `bestIsShared` computation and change (~line 38-39):

```dart
      if (placements[i] == bestPlacement && !bestIsShared) {
        mode.won++;
      }
```

`halve_it_game_screen.dart` (~line 390-403): compute tie and guard:

```dart
    final tieForBest =
        totalScores.where((s) => s == bestScore).length > 1;
```
and change `if (pi == winnerIdx) sp.gamesWon++;` → `if (pi == winnerIdx && !tieForBest) sp.gamesWon++;`

Grep `gamesWon++` in `shanghai_game_screen.dart` (and the other screens) — apply the identical guard wherever a points-tie can produce a shared best (Shanghai: yes; X01/ATC/Killer/Cricket: placements are finish-order/unique, no change needed, verify by reading the increment's context).

- [ ] **Step 4: Run** — `flutter test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/achievement_service.dart lib/services/stats_recorder.dart lib/screens/halve_it_game_screen.dart lib/screens/shanghai_game_screen.dart test/services/achievement_tie_test.dart
git commit -m "fix(achievements/stats): shared first place is a draw — no win credit anywhere"
```

---

### Task 8: Streak tracking (makes 4 dead badges obtainable)

Fixes review finding 10. Win = sole best placement; tie = breaks both streaks; anything else = loss.

**Files:**
- Modify: `lib/services/stats_recorder.dart` (inside the per-player loop of `recordGame`)
- Test: `test/services/streak_tracking_test.dart` (create)

- [ ] **Step 1: Failing test**

```dart
// test/services/streak_tracking_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

void main() {
  SavedPlayer p(String id) => SavedPlayer(id: id, name: id);

  void play(List<SavedPlayer> sps, List<int> placements) {
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: sps.map((s) => s.id).toList(),
      playerNames: sps.map((s) => s.name).toList(),
      placements: placements,
      savedPlayers: sps,
    );
  }

  test('win/loss streaks update and bestWinStreak high-water-marks', () {
    final a = p('a'), b = p('b');
    play([a, b], [1, 2]); // a wins
    play([a, b], [1, 2]); // a wins
    play([a, b], [2, 1]); // a loses
    expect(a.currentWinStreak, 0);
    expect(a.bestWinStreak, 2);
    expect(a.currentLossStreak, 1);
    expect(b.currentWinStreak, 1);
    expect(b.currentLossStreak, 0);
  });

  test('a tie breaks both streaks without counting as win or loss', () {
    final a = p('a'), b = p('b');
    play([a, b], [1, 2]); // a wins
    play([a, b], [1, 1]); // tie
    expect(a.currentWinStreak, 0);
    expect(a.currentLossStreak, 0);
    expect(a.bestWinStreak, 1);
  });
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

In `recordGame`'s per-player loop, right after the `mode.won` update (with `bestIsShared` from Task 7 in scope):

```dart
      // Win/loss streaks (cross-mode). Sole best = win; shared best = draw
      // (breaks both streaks); everything else = loss.
      if (placements[i] == bestPlacement && !bestIsShared) {
        sp.currentWinStreak++;
        if (sp.currentWinStreak > sp.bestWinStreak) {
          sp.bestWinStreak = sp.currentWinStreak;
        }
        sp.currentLossStreak = 0;
      } else if (placements[i] == bestPlacement) {
        sp.currentWinStreak = 0;
        sp.currentLossStreak = 0;
      } else {
        sp.currentLossStreak++;
        sp.currentWinStreak = 0;
      }
```

NOTE: every game screen calls `recordGame` BEFORE `awardGameEnd` (verified for all 6), so streak milestones (`bestWinStreak >= 3` etc.) evaluate fresh values in the same game — HOT START unlocks live on the third straight win.

- [ ] **Step 4: Run** — `flutter test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats_recorder.dart test/services/streak_tracking_test.dart
git commit -m "feat(stats): track win/loss streaks — HOT START/ON FIRE/UNSTOPPABLE/COLD STREAK now obtainable"
```

---

### Task 9: One-time revocation of falsely granted badges

Decision: revoke ALL affected ids for every player; they can be re-earned legitimately.

**Files:**
- Modify: `lib/models/saved_player.dart` (new flag `falseUnlocksRevoked`)
- Modify: `lib/services/achievement_service.dart` (new `revokeFalseUnlocks`)
- Modify: `lib/main.dart:21-32` (run revoke in the existing startup loop)
- Test: `test/services/achievement_revoke_test.dart` (create)

- [ ] **Step 1: Failing test**

```dart
// test/services/achievement_revoke_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('revokeFalseUnlocks strips affected ids exactly once', () {
    final p = SavedPlayer(id: 'a', name: 'A')
      ..unlockedAchievementIds.addAll(
          {'cri_the_nine', 'x01_maximum', 'x01_first_win_unrelated'})
      ..achievementUnlockedAt['cri_the_nine'] = DateTime(2026, 6, 9);

    final changed = AchievementService.instance.revokeFalseUnlocks(p);
    expect(changed, isTrue);
    expect(p.unlockedAchievementIds, isNot(contains('cri_the_nine')));
    expect(p.unlockedAchievementIds, isNot(contains('x01_maximum')));
    expect(p.unlockedAchievementIds, contains('x01_first_win_unrelated'));
    expect(p.achievementUnlockedAt.containsKey('cri_the_nine'), isFalse);
    expect(p.falseUnlocksRevoked, isTrue);

    expect(AchievementService.instance.revokeFalseUnlocks(p), isFalse,
        reason: 'second call is a no-op');
  });
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

`saved_player.dart` — add alongside `achievementsRetroGranted`:
```dart
  bool falseUnlocksRevoked;
```
constructor: `this.falseUnlocksRevoked = false,` — toJson: `'falseUnlocksRevoked': falseUnlocksRevoked,` — fromJson: `falseUnlocksRevoked: json['falseUnlocksRevoked'] as bool? ?? false,`

`achievement_service.dart` — add:

```dart
  /// Pre-1.8.4 builds granted these falsely (bust-tainted feats, missing
  /// turnId, tie-as-win). One-time strip; players re-earn them legitimately.
  static const falselyGrantedIds = {
    'cri_the_nine',
    'x01_maximum',
    'x01_bullseye_finish',
    'kil_killing_spree',
    'spl_clutch_save',
    'x_natural_talent',
    'x_giant_slayer',
  };

  bool revokeFalseUnlocks(SavedPlayer player) {
    if (player.falseUnlocksRevoked) return false;
    player.unlockedAchievementIds.removeAll(falselyGrantedIds);
    player.achievementUnlockedAt
        .removeWhere((k, _) => falselyGrantedIds.contains(k));
    player.falseUnlocksRevoked = true;
    return true;
  }
```

`main.dart` — extend the existing loop (~line 26-31):

```dart
  for (final p in savedPlayers) {
    if (AchievementService.instance.revokeFalseUnlocks(p)) {
      retroChanged = true;
    }
    if (!p.achievementsRetroGranted) {
      AchievementService.instance.retroGrantSilently(p);
      retroChanged = true;
    }
  }
```

(Revoke BEFORE retro-grant; retro-grant cannot re-grant any of these — outcome-gated milestones get `outcome: null`, the rest are event-based.)

- [ ] **Step 4: Run** — `flutter test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/saved_player.dart lib/services/achievement_service.dart lib/main.dart test/services/achievement_revoke_test.dart
git commit -m "fix(achievements): one-time revocation of falsely granted badges from 1.8.3"
```

---

## Del B — Cockpit-chrome

### Task 10: Fixed board position + spec glow (X01 + Killer)

Fixes review findings 7 and 8.

**Files:**
- Modify: `lib/screens/game_screen.dart:1546-1572` (board section of `_buildDossedartCockpit`)
- Modify: `lib/screens/killer_game_screen.dart:800-827` (`_killerBoard`)
- Modify: `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart` (stale comments ~line 94 and ~153)

- [ ] **Step 1: Anchor the board to the bottom of the Expanded + add glow (game_screen)**

Replace the `Center(child: Padding(...))` inside the Expanded Stack with a bottom-anchored Positioned wrapping a circular glow:

```dart
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onMiss,
                    ),
                  ),
                  // Bottom-anchored so active-card height changes eat the gap
                  // ABOVE the board — tap targets never move between darts.
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Spec (x01-cockpit-final): no frame, glow only —
                          // 0 0 70px magenta @ 0x3a ≈ alpha 0.23.
                          boxShadow: [
                            BoxShadow(
                              color: DossedartTokens.magenta
                                  .withValues(alpha: 0.23),
                              blurRadius: 70,
                            ),
                          ],
                        ),
                        child: DossedartX01Dartboard(
                          onTap: (zone) {
                            final (seg, mult) = zone.toSegmentMultiplier();
                            if (seg == 0) {
                              _onMiss();
                            } else {
                              _onDartHit(seg, mult);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
```

- [ ] **Step 2: Same glow in Killer**

In `_killerBoard` (~line 800), wrap the existing `Stack` (board + overlay) in the identical glow Container:

```dart
  Widget _killerBoard(Map<int, Color> tints) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: DossedartTokens.magenta.withValues(alpha: 0.23),
                blurRadius: 70,
              ),
            ],
          ),
          child: Stack(
            children: [
              // ... existing DossedartX01Dartboard + overlay unchanged ...
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Fix the stale painter comments**

In `dossedart_x01_dartboard.dart`, update both comments that claim the parent provides the glow so they read e.g. `// Glow comes from the circular BoxDecoration the cockpits wrap the board in (game_screen / killer_game_screen).` — now true.

- [ ] **Step 4: Run** — `flutter test` → PASS (layout change; dartboard tests are widget-local and unaffected).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart lib/screens/killer_game_screen.dart lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart
git commit -m "fix(dossedart): bottom-anchor the board (no mid-turn shifts) + restore spec glow"
```

---

### Task 11: Splitscore top bar `RUNDE` → `RND`

Fixes review finding 9 (one-liner).

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart:584`

- [ ] **Step 1: Change**

```dart
              trailing: 'RND ${currentRoundIndex + 1}/${rounds.length}',
```
(Scorecard column header 'RUNDE' at ~line 796 is design-mandated — do NOT touch.)

- [ ] **Step 2: Run** — `flutter test` → PASS. Commit:

```bash
git add lib/screens/halve_it_game_screen.dart
git commit -m "fix(splitscore): top bar RND per design spec and cross-mode consistency"
```

---

### Task 12: X01 uses the shared cockpit-menu helper

Fixes verified cleanup finding (X01 duplicates `showDossedartCockpitMenu` inline).

**Files:**
- Modify: `lib/widgets/dossedart/dossedart_cockpit_menu.dart` (add `onSoundChanged` hook)
- Modify: `lib/screens/game_screen.dart:1603-1649` (replace inline body)
- Test: `test/widgets/dossedart/dossedart_cockpit_menu_test.dart` (create or extend)

- [ ] **Step 1: Add the hook to the helper**

In `showDossedartCockpitMenu`, add parameter `ValueChanged<bool>? onSoundChanged,` and change the sound callback:

```dart
          onSoundChanged: (v) {
            SoundService.instance.setEnabled(v);
            AppSettings.setSoundEffectsEnabled(v);
            onSoundChanged?.call(v);
          },
```

- [ ] **Step 2: Replace X01's inline copy**

Replace the entire `_showDossedartMenu` body in `game_screen.dart` with:

```dart
  Future<void> _showDossedartMenu(BuildContext outerContext) {
    return showDossedartCockpitMenu(
      outerContext,
      meme: _meme,
      onSoundChanged: (v) => setState(() => _soundEnabled = v),
      onTtsChanged: (v) => setState(() => _ttsEnabled = v),
      onPlayerOverview: _openPlayerOverview,
      onExit: _confirmExit,
    );
  }
```

Add the import for the helper; remove now-unused imports (`dossedart_menu_sheet.dart` etc.) if the analyzer flags them.

- [ ] **Step 3: Test the hook**

Mirror the style of `test/widgets/dossedart/x01/dossedart_menu_sheet_test.dart`: pump a button that calls `showDossedartCockpitMenu(... onSoundChanged: captured ...)`, toggle the sound row, assert the callback received the new value.

- [ ] **Step 4: Run** — `flutter test` → PASS. Commit:

```bash
git add lib/widgets/dossedart/dossedart_cockpit_menu.dart lib/screens/game_screen.dart test/widgets/dossedart/
git commit -m "refactor(x01): use shared cockpit menu helper (new onSoundChanged hook)"
```

---

### Task 13: Extract shared `DossedartActiveStrip` (kills 4-way copy-paste + drift)

Fixes verified cleanup finding. Canonical styling: NO glow on dart dots (cricket's glow was drift), `LAST · ` prefix present, trailing widget slot for the mode-specific stat.

**Files:**
- Create: `lib/widgets/dossedart/dossedart_active_strip.dart`
- Modify: `lib/screens/cricket_game_screen.dart:733` (delete `_dossedartActiveStrip` + `_dossedartDartDots`, use shared)
- Modify: `lib/screens/around_the_clock_game_screen.dart:1092` (same for `_atcActiveStrip`/`_atcDartDots`)
- Modify: `lib/screens/halve_it_game_screen.dart:608` (same for `_splitActiveStrip`/`_splitDartDots`)
- Modify: `lib/screens/shanghai_game_screen.dart:594` (same for `_shanghaiActiveStrip`/`_shanghaiDartDots`)
- Test: `test/widgets/dossedart/dossedart_active_strip_test.dart` (create)

- [ ] **Step 1: Write the shared widget**

```dart
// lib/widgets/dossedart/dossedart_active_strip.dart
import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'dossedart_player_avatar.dart';

/// Shared active-player hero strip used by the Cricket/ATC/Splitscore/Shanghai
/// cockpits (X01 uses the larger DossedartX01ActiveCard). One source so the
/// chrome cannot drift between modes.
class DossedartActiveStrip extends StatelessWidget {
  const DossedartActiveStrip({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.dartsInTurn,
    this.lastThrowLabel,
    this.trailing,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int dartsInTurn; // 0..3
  final String? lastThrowLabel;
  final Widget? trailing; // mode-specific stat (target, lives, round pts...)

  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.12), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: c, width: 3)),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.27), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          DossedartPlayerAvatar(
            avatarPath: avatarPath,
            size: 52,
            borderColor: c,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '▶ ${playerName.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: c,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DartDots(filled: dartsInTurn, color: c),
                    const SizedBox(width: 10),
                    Text(
                      'DART ${dartsInTurn + 1} / 3',
                      style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                    if (lastThrowLabel != null) ...[
                      const SizedBox(width: 12),
                      const Text(
                        'LAST · ',
                        style: TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 14,
                          color: Colors.white38,
                          letterSpacing: 1,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          lastThrowLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 14,
                            color: DossedartTokens.yellow,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _DartDots extends StatelessWidget {
  const _DartDots({required this.filled, required this.color});
  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: i < filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
          ),
          if (i < 2) const SizedBox(width: 5),
        ],
      ],
    );
  }
}
```

IMPORTANT: before finalizing, open ONE of the existing strips (`cricket_game_screen.dart:733`) and align exact paddings/font sizes/dot sizes with what is actually shipped (the values above are from the review's verifier quotes — verify, don't guess). The widget is the new single source; the four copies adapt to IT, not vice versa.

- [ ] **Step 2: Widget test**

```dart
// test/widgets/dossedart/dossedart_active_strip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_active_strip.dart';

void main() {
  testWidgets('renders name, dart counter, LAST row and trailing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartActiveStrip(
          playerName: 'Bjørn',
          avatarPath: null,
          accentColor: Colors.cyan,
          dartsInTurn: 1,
          lastThrowLabel: 'T20',
          trailing: Text('ON 7'),
        ),
      ),
    ));
    expect(find.textContaining('BJØRN'), findsOneWidget);
    expect(find.text('DART 2 / 3'), findsOneWidget);
    expect(find.text('LAST · '), findsOneWidget);
    expect(find.text('T20'), findsOneWidget);
    expect(find.text('ON 7'), findsOneWidget);
  });

  testWidgets('omits LAST row when label is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartActiveStrip(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          dartsInTurn: 0,
        ),
      ),
    ));
    expect(find.text('LAST · '), findsNothing);
  });
}
```

- [ ] **Step 3: Replace the four private copies, one screen at a time**

For each of cricket (`_dossedartActiveStrip` + `_dossedartDartDots`), ATC (`_atcActiveStrip` + `_atcDartDots`), splitscore (`_splitActiveStrip` + `_splitDartDots`), shanghai (`_shanghaiActiveStrip` + `_shanghaiDartDots`):
1. Identify the right-side stat content in the old strip (the part that differs per mode — e.g. ATC's current target, Splitscore's round points) and move it verbatim into the `trailing:` parameter.
2. Replace the call site in the cockpit Column with `DossedartActiveStrip(playerName: ..., avatarPath: ..., accentColor: DossedartTokens.cyan, dartsInTurn: dartsInTurn, lastThrowLabel: lastThrowLabel, trailing: <moved widget>)` using that screen's actual state fields (the old strip body shows exactly which fields feed name/avatar/dots/last).
3. Delete the now-unused private strip + dots methods.
4. Run `flutter test` after EACH screen before moving to the next.

(Shanghai's old strip has no LAST row — pass its `lastThrowLabel` anyway so all four modes gain it consistently; that drift was the bug.)

- [ ] **Step 4: Run full suite + analyzer** — `flutter test && flutter analyze` → green, no unused-method warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/dossedart_active_strip.dart lib/screens/ test/widgets/dossedart/dossedart_active_strip_test.dart
git commit -m "refactor(dossedart): one shared DossedartActiveStrip across Cricket/ATC/Splitscore/Shanghai"
```

---

## Del C — QA-punkter fra tablet-testen

### Task 14: Cricket — larger opponent glyphs

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart:1079-1108` (`_dossedartGlyph`)

- [ ] **Step 1: Bump sizes**

In `_dossedartGlyph`: empty dot `'·'` fontSize 16 → **22**; `'⊗'` fontSize 20 → **26**; `'/'`/`'X'` fontSize 20 → **26**. (Leave the active-input cell's own glyph column at 16 — it is cyan-on-cyan-tint and was not the complaint; bump later if Bjørn asks.)

- [ ] **Step 2: Run** — `flutter test` → PASS. Commit:

```bash
git add lib/screens/cricket_game_screen.dart
git commit -m "fix(cricket): larger opponent mark glyphs for readability"
```

---

### Task 15: ATC — drop opponent meters, more air at the bottom, bigger MISS

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart:1073` (remove meters from Column), `:1320-1405` (delete dead methods), `:1416-1417` (input padding)
- Modify: `lib/widgets/dossedart/dossedart_action_bar.dart` (button height — shared, ALL modes per consistency rule)

- [ ] **Step 1: Remove opponent progress from the cockpit**

In `_buildDossedartCockpit` (~line 1073) delete the line `_atcOpponentMeters(),`. Delete the now-dead `_atcOpponentMeters` and `_atcMeter` methods (~1320-1405). Opponent progress remains available in the player sheet (MENU → PLAYER OVERVIEW shows per-player primary). The clock ring + input rows get the freed space automatically (ring is in an Expanded).

- [ ] **Step 2: Air between input cells and the action bar**

`_atcInputCells` padding (~line 1417): `EdgeInsets.fromLTRB(16, 4, 16, 4)` → `EdgeInsets.fromLTRB(16, 8, 16, 14)`.

- [ ] **Step 3: Bigger MISS (shared action bar — all modes identical)**

In `dossedart_action_bar.dart` `_Btn`: button padding `EdgeInsets.symmetric(vertical: 12)` → `EdgeInsets.symmetric(vertical: 16)`. Also bump the MISS label's visual weight: in the MISS `Expanded`, change `flex: 2` → `flex: 3` so MISS grows relative to UNDO/MENU.

NOTE on "knappen som tar deg ut av appen": the most plausible culprit is Android's gesture/nav area at the very bottom edge — the extra `bottom: 14` input padding plus the taller bar moves tap targets up from that edge. If Bjørn still hits it after this round, add extra bottom inset under the action bar (`padding: EdgeInsets.fromLTRB(14, 12, 14, 18)` on the bar container).

- [ ] **Step 4: Check the action-bar test**

`test/widgets/dossedart/dossedart_action_bar_test.dart` may assert sizes/flex — update expectations to the new values, intentionally.

- [ ] **Step 5: Run** — `flutter test` → PASS. Commit:

```bash
git add lib/screens/around_the_clock_game_screen.dart lib/widgets/dossedart/dossedart_action_bar.dart test/widgets/dossedart/dossedart_action_bar_test.dart
git commit -m "fix(atc): drop bottom opponent meters, add bottom air; bigger MISS in shared action bar"
```

---

### Task 16: Splitscore — scorecard fills more of the screen

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart:832-945` (`_splitScoreRow`, `_splitCellText`, `_splitScoreHeader`, `_splitSumRow`)

- [ ] **Step 1: Bigger rows and text**

- `_splitScoreRow` (~line 847 + 864): both `vertical: 9` paddings → `vertical: 14`; round-label fontSize 9 → **11**.
- `_splitCellText` (~line 876-892): fontSize 16/16/17 → **20/20/22**.
- `_splitScoreHeader` (~line 780) and `_splitSumRow` (~line 894): increase every fontSize by **+2** and any vertical padding by **+4** so header/sum stay proportional to the rows (open the methods and apply uniformly).

- [ ] **Step 2: Run** — `flutter test` → PASS. Visual check happens in Bjørn's next tablet round. Commit:

```bash
git add lib/screens/halve_it_game_screen.dart
git commit -m "fix(splitscore): larger scorecard rows/text so the hero fills the screen"
```

---

### Task 17: Achievements — descriptions always visible in gallery, short-press in stats

**Files:**
- Modify: `lib/screens/dossedart/achievements_gallery_screen.dart:142-172` (`_GalleryTile` + grid params)
- Modify: `lib/widgets/dossedart/stats/prestasjoner_section.dart:121-141` (`_MedalRow` tap → dialog)
- Test: `test/widgets/dossedart/achievements_description_test.dart` (create)

- [ ] **Step 1: Failing test**

```dart
// test/widgets/dossedart/achievements_description_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import the gallery tile's screen + an Achievement fixture from the catalog
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/screens/dossedart/achievements_gallery_screen.dart';

void main() {
  testWidgets('gallery shows description text without interaction',
      (tester) async {
    // Pump the gallery (constructor args per its real signature) with the
    // standard catalog; pick a known badge and assert its description text
    // is present in the tree (no long-press needed).
    await tester.pumpWidget(const MaterialApp(
      home: AchievementsGalleryScreen(/* args */),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Score a 180 in one turn'), findsWidgets);
  });
}
```

(Adapt to the screen's constructor; if it loads players async, pump with a fake/empty storage the way existing gallery/stats tests do — check `test/` for the established pattern first.)

- [ ] **Step 2: Gallery tile — always-visible description**

In `_GalleryTile`, remove the `Tooltip` wrapper and add the description under the name:

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AchievementMedal(achievement: achievement, unlocked: unlocked, size: 64),
        const SizedBox(height: 6),
        Text(
          achievement.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'PressStart2P',
            height: 1.3,
            color: unlocked ? Colors.white : DossedartTokens.disabledFg,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          achievement.description,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'VT323',
            height: 1.15,
            color: unlocked
                ? Colors.white70
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
```

Adjust the grid so taller tiles fit: in the `GridView.builder` `SliverGridDelegateWithMaxCrossAxisExtent`, `maxCrossAxisExtent: 120` → `150`, `childAspectRatio: 0.8` → `0.62` (tune until no overflow in the test run — overflow throws in widget tests, which is the guard).

- [ ] **Step 3: Stats section — short-press dialog**

In `prestasjoner_section.dart` `_MedalRow`, wrap each medal in a tap handler:

```dart
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _showAchievementInfo(context, a, unlocked),
                child: AchievementMedal(
                    achievement: a, unlocked: unlocked, size: 44),
              ),
            ),
```

and add in the same file:

```dart
void _showAchievementInfo(BuildContext context, Achievement a, bool unlocked) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: DossedartTokens.surface,
      shape: Border.all(color: DossedartTokens.cyan, width: 2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: a, unlocked: unlocked, size: 64),
            const SizedBox(height: 12),
            Text(
              a.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.phosphor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

(Import what's needed; reuse the existing `AchievementMedal` import in the file.)

- [ ] **Step 4: Run** — `flutter test` → PASS (incl. no grid overflow). Commit:

```bash
git add lib/screens/dossedart/achievements_gallery_screen.dart lib/widgets/dossedart/stats/prestasjoner_section.dart test/widgets/dossedart/achievements_description_test.dart
git commit -m "feat(achievements): always-visible descriptions in gallery, tap-for-info in stats"
```

---

## Avslutning

### Task 18: Full verification

- [ ] **Step 1:** `flutter analyze` → No issues found.
- [ ] **Step 2:** `flutter test` → All tests passed.
- [ ] **Step 3:** Review `git log --oneline main..HEAD` — every task above has its commit.
- [ ] **Step 4:** Report to Bjørn. Per release-train: NO push/CI until Bjørn says so. Version bump (→ 1.8.4) + APK build happens when Bjørn calls the next build — remember `pubspec.yaml` + `home_screen.dart` version string.

**After-plan follow-ups (not tasks here):**
- X01 dartboard color round: 2-3 HTML palette proposals → Bjørn picks → separate implementation.
- Bjørn's next tablet round verifies: glyph size, ATC bottom, splitscore scorecard, gallery layout, board position/glow.
