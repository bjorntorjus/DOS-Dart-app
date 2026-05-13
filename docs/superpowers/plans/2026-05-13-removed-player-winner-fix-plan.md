# Removed mid-game player winner fix — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player removed mid-game in Cricket, X01, or Around the Clock must never be declared the winner.

**Architecture:** Minimal-blast-radius fix. Add a private helper `_winnerIndexExcludingRemoved()` per game screen that walks `finishedPlayers` and returns the first index not in `_removedPlayerIndices`. Replace all `finishedPlayers.first`-based winner picks with the helper. Leave `finishedPlayers` membership semantics alone — removed players continue to be added to `finishedPlayers` so existing "is this player still playing?" checks across ~70 sites stay correct.

**Tech Stack:** Flutter (Dart), existing `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-05-13-removed-player-winner-fix-design.md` (commit `3941a8a`).

**Trade-off acknowledged in plan:** The spec discussed two approaches — (A) drop `finishedPlayers.add(playerIndex)` in the remove handler and audit ~70 `finishedPlayers.contains`/`length` sites, or (B) change only the winner-picking. This plan goes with (B). It fixes the user-visible bug (removed player declared winner) without rewriting placement logic. If a follow-up reveals that removed players still appear in the wrong rank on post-game (e.g., as `2nd place` instead of `removed`), that becomes a separate spec/PR.

---

## File map

**Modified:**
- `lib/screens/cricket_game_screen.dart` — add `_winnerIndexExcludingRemoved()` helper; replace winner picks at lines 142, 145, 373
- `lib/screens/game_screen.dart` (X01) — add helper; replace at lines 506, 725, 738, 820, 836, 914, 934, 1056
- `lib/screens/around_the_clock_game_screen.dart` — add helper; replace at lines 381, 424, 504, 727, 797

**Created:**
- `test/screens/removed_player_winner_test.dart` — one parameterized-style test per affected mode

**Verified, no change:**
- `lib/screens/halve_it_game_screen.dart` — winner is highest score; remove handler at line 1197 only adds to `_removedPlayerIndices`, not `finishedPlayers`
- `lib/screens/killer_game_screen.dart` — already filters via `isEliminated` + `_removedPlayerIndices.contains` checks
- `lib/screens/shanghai_game_screen.dart` — engine-based winner pattern

---

## Task 1: Cricket — helper + winner pick replacements

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` (new helper near `_removedPlayerIndices` field declaration; line replacements at 142, 145, 373)

- [ ] **Step 1.1: Confirm exact line numbers and field types**

Before editing, run:
```bash
cd .worktrees/removed-player-fix
grep -n "finishedPlayers\.first\|_removedPlayerIndices\s*=\|int? winnerIndex\|int winnerIndex" lib/screens/cricket_game_screen.dart
```

This pins the current line numbers (drift since plan was written) and confirms whether `winnerIndex` is `int?` or `int`. The replacements in Steps 1.3-1.5 assume the helper returns `int?`; if a call site assigns to non-nullable `int`, add `!` after the helper call where the surrounding logic guarantees a winner exists.

- [ ] **Step 1.2: Add the helper method**

In `lib/screens/cricket_game_screen.dart`, find the section near the top of `_CricketGameScreenState` where `_removedPlayerIndices` is declared (search for `final Set<int> _removedPlayerIndices` or similar). Immediately after the field declarations, add:

```dart
  /// First player in [finishedPlayers] who has not been removed mid-game.
  /// Used for winner picking — a removed player must never be declared winner
  /// even if their index happens to appear first in [finishedPlayers].
  int? _winnerIndexExcludingRemoved() {
    for (final i in finishedPlayers) {
      if (!_removedPlayerIndices.contains(i)) return i;
    }
    return null;
  }
```

- [ ] **Step 1.3: Replace winner pick at line ~142**

Current code (approximate — confirm via Step 1.1):
```dart
            winnerIndex = finishedPlayers.first;
```
Replace with:
```dart
            winnerIndex = _winnerIndexExcludingRemoved() ?? finishedPlayers.first;
```

The `?? finishedPlayers.first` fallback preserves the original behaviour when *all* finishers are removed (an edge case where someone removed the entire field; falling back to the old logic is safer than crashing).

- [ ] **Step 1.4: Replace winner pick at line ~145**

Same change as Step 1.3 — find the second `winnerIndex = finishedPlayers.first;` in the file and apply the identical replacement.

- [ ] **Step 1.5: Replace winner pick at line ~373**

Current code (approximate):
```dart
      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
```
Replace with:
```dart
      winnerIndex = _winnerIndexExcludingRemoved();
```

(The helper already returns `null` when `finishedPlayers` is empty, so the ternary is redundant.)

- [ ] **Step 1.6: Run analyzer**

```bash
cd .worktrees/removed-player-fix
flutter analyze lib/screens/cricket_game_screen.dart
```
Expected: no issues. If a `null` type mismatch surfaces, add `!` only where the surrounding logic guarantees at least one non-removed finisher (typically inside an `if (finishedPlayers.length >= players.length - 1)` block).

- [ ] **Step 1.7: Do NOT commit yet**

Commit comes after all three files + tests land together in Task 5.

---

## Task 2: X01 — helper + winner pick replacements

**Files:**
- Modify: `lib/screens/game_screen.dart` (helper + replacements at lines 506, 725, 738, 820, 836, 914, 934, 1056)

- [ ] **Step 2.1: Confirm line numbers**

```bash
cd .worktrees/removed-player-fix
grep -n "finishedPlayers\.first" lib/screens/game_screen.dart
```

Expected output: 8 lines — 506, 725, 738, 820, 836, 914, 934, 1056. If drift, use the current numbers.

- [ ] **Step 2.2: Add the helper method**

In `lib/screens/game_screen.dart`, find the section where `_removedPlayerIndices` is declared (search for `_removedPlayerIndices`). Add immediately after the field declarations:

```dart
  /// First player in [finishedPlayers] who has not been removed mid-game.
  /// Used for winner picking — a removed player must never be declared winner
  /// even if their index happens to appear first in [finishedPlayers].
  int? _winnerIndexExcludingRemoved() {
    for (final i in finishedPlayers) {
      if (!_removedPlayerIndices.contains(i)) return i;
    }
    return null;
  }
```

- [ ] **Step 2.3: Replace lines 725, 820, 914**

These three sites have the pattern:
```dart
        winnerIndex = finishedPlayers.first;
```
Replace each with:
```dart
        winnerIndex = _winnerIndexExcludingRemoved() ?? finishedPlayers.first;
```

- [ ] **Step 2.4: Replace line 1056**

Current:
```dart
      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
```
Replace with:
```dart
      winnerIndex = _winnerIndexExcludingRemoved();
```

- [ ] **Step 2.5: Replace lines 506, 738, 836, 934 (downstream `finishedPlayers.first == pi` checks)**

These sites use `finishedPlayers.first` to identify the winner for stats consumers (e.g., `sp.gamesWon++`). Line 506 looks like:

```dart
      if (finishedPlayers.isNotEmpty && finishedPlayers.first == pi) sp.gamesWon++;
```

Replace with:
```dart
      if (_winnerIndexExcludingRemoved() == pi) sp.gamesWon++;
```

(The helper returns `null` when no real winner exists, and `null == pi` is `false` — handles the empty case correctly.)

For lines 738, 836, 934, the surrounding code looks like:

```dart
      final winner = players[finishedPlayers.first];
```

Replace with:
```dart
      final winner = players[_winnerIndexExcludingRemoved() ?? finishedPlayers.first];
```

Same fallback as Step 2.3 — preserves crash-free behaviour if every finisher is removed.

- [ ] **Step 2.6: Run analyzer**

```bash
cd .worktrees/removed-player-fix
flutter analyze lib/screens/game_screen.dart
```
Expected: no issues.

- [ ] **Step 2.7: Do NOT commit yet**

---

## Task 3: ATC — helper + winner pick replacements

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart` (helper + replacements at lines 381, 424, 504, 727, 797)

- [ ] **Step 3.1: Confirm line numbers**

```bash
cd .worktrees/removed-player-fix
grep -n "finishedPlayers\.first" lib/screens/around_the_clock_game_screen.dart
```

Expected: 5 lines — 381, 424, 504, 727, 797.

- [ ] **Step 3.2: Add the helper method**

Same body as Task 1.2 and 2.2. Place it just after `_removedPlayerIndices` field declaration:

```dart
  /// First player in [finishedPlayers] who has not been removed mid-game.
  /// Used for winner picking — a removed player must never be declared winner
  /// even if their index happens to appear first in [finishedPlayers].
  int? _winnerIndexExcludingRemoved() {
    for (final i in finishedPlayers) {
      if (!_removedPlayerIndices.contains(i)) return i;
    }
    return null;
  }
```

- [ ] **Step 3.3: Replace lines 424, 504**

Both look like:
```dart
      winnerIndex = finishedPlayers.first;
```
Replace each with:
```dart
      winnerIndex = _winnerIndexExcludingRemoved() ?? finishedPlayers.first;
```

- [ ] **Step 3.4: Replace lines 381, 727**

Both look like:
```dart
      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
```
Replace each with:
```dart
      winnerIndex = _winnerIndexExcludingRemoved();
```

- [ ] **Step 3.5: Replace line 797 (downstream stats check)**

Current:
```dart
      if (finishedPlayers.isNotEmpty && finishedPlayers.first == pi) sp.gamesWon++;
```
Replace with:
```dart
      if (_winnerIndexExcludingRemoved() == pi) sp.gamesWon++;
```

- [ ] **Step 3.6: Run analyzer**

```bash
cd .worktrees/removed-player-fix
flutter analyze lib/screens/around_the_clock_game_screen.dart
```
Expected: no issues.

- [ ] **Step 3.7: Do NOT commit yet**

---

## Task 4: Regression tests — one per affected mode

**Files:**
- Create: `test/screens/removed_player_winner_test.dart`

Each test follows the same shape: mount the game screen with 3 players, drive the engine far enough that P1 can finish, remove P0 mid-game, finish P1, assert `winnerIndex == 1`.

The simplest way to drive each engine in tests is via a `@visibleForTesting` getter on the State class — exposing the underlying engine + the `_removedPlayerIndices` field. This may already exist for some screens; if not, add it.

- [ ] **Step 4.1: Expose test hooks on each game screen**

For each of `cricket_game_screen.dart`, `game_screen.dart`, `around_the_clock_game_screen.dart`, add (or confirm exists) near the top of the State class:

```dart
  @visibleForTesting
  List<int> get finishedPlayersForTest => finishedPlayers;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => _removedPlayerIndices;

  @visibleForTesting
  int? get winnerIndexForTest => winnerIndex;
```

Plus a `@visibleForTesting` method that directly invokes the remove flow and the finish flow (these typically live in `_removePlayerMidGame` and `_handleCheckout` or similar — search each file):

```dart
  @visibleForTesting
  void removePlayerForTest(int playerIndex) {
    setState(() {
      _midGamePlayerChanges = true;
      _removedPlayerIndices.add(playerIndex);
      if (!finishedPlayers.contains(playerIndex)) {
        finishedPlayers.add(playerIndex);
      }
      // Skip the dialog and any side-effects the dialog handler does
      // beyond what the bug fix covers. If the file has additional logic
      // (e.g., advancing the current player when removing the active one),
      // mirror it here. See the production _removePlayerMidGame for what
      // happens inside the Remove button's onPressed.
    });
  }
```

⚠ **Important:** When copying the body from `_removePlayerMidGame`, omit any UI-only side effects (Navigator pops, dialogs) but keep the state mutations. Cross-check against the production handler in each file.

Add `import 'package:flutter/foundation.dart';` if needed for `@visibleForTesting`.

- [ ] **Step 4.2: Write the Cricket test**

Create `test/screens/removed_player_winner_test.dart` and start with the Cricket case:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

void main() {
  testWidgets('Cricket: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: players,
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<State<CricketGameScreen>>(
        find.byType(CricketGameScreen));
    final dynamic dynState = state;

    // Remove P0 mid-game — index 0 lands in both finishedPlayers and
    // _removedPlayerIndices, mimicking the production handler.
    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'precondition: removed player must be first in finishedPlayers '
            'for the bug to surface; the helper must skip them');

    // Simulate P1 finishing — add to finishedPlayers second.
    dynState.finishedPlayersForTest.add(1);
    // Trigger the winner-pick path. The actual path differs per file —
    // for Cricket the simplest is to call the existing _checkGameOver-style
    // method via a test hook. If that's not exposed, call the helper
    // directly through a @visibleForTesting wrapper that runs the same
    // assignment as the production code at line ~142.
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
}
```

⚠ The test references `dynState.computeWinnerForTest()` — a thin wrapper around `_winnerIndexExcludingRemoved()` exposed for tests. Add this getter to the State class:

```dart
  @visibleForTesting
  int? computeWinnerForTest() => _winnerIndexExcludingRemoved();
```

This is the minimum viable test — it directly exercises the helper logic in the context where the bug surfaces. A fuller test driving real throws is preferable but significantly more code; this minimal version verifies the contract.

- [ ] **Step 4.3: Add the X01 case**

Append to the same test file:

```dart
import 'package:dart_scoring/screens/game_screen.dart';

// ... in main() body, after Cricket test:

  testWidgets('X01: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 301),
      Player(name: 'P1', score: 301),
      Player(name: 'P2', score: 301),
    ];

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: players,
        startingScore: 301,
        masterOut: 'none',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pumpAndSettle();

    final state =
        tester.state<State<GameScreen>>(find.byType(GameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    dynState.finishedPlayersForTest.add(1);
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
```

- [ ] **Step 4.4: Add the ATC case**

Append:

```dart
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';

// ... in main() body:

  testWidgets('ATC: removed mid-game player does not become winner',
      (tester) async {
    final players = [
      Player(name: 'P0', score: 0),
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: players,
        config: const AroundTheClockConfig(
          includeBull: false,
          countMultiples: false,
          reverse: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
    final dynamic dynState = state;

    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    dynState.finishedPlayersForTest.add(1);
    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
```

Verify each screen's constructor signature matches what's used in these tests. Adjust required parameters as needed by reading each constructor.

- [ ] **Step 4.5: Run the new tests**

```bash
cd .worktrees/removed-player-fix
flutter test test/screens/removed_player_winner_test.dart
```
Expected: 3 tests pass.

- [ ] **Step 4.6: Run the full test suite**

```bash
cd .worktrees/removed-player-fix
flutter test
```
Expected: all tests pass (existing + new).

---

## Task 5: Final analyzer + commit

**Files:** none (verification + commit only)

- [ ] **Step 5.1: Run analyzer over the whole worktree**

```bash
cd .worktrees/removed-player-fix
flutter analyze
```
Expected: no new issues.

- [ ] **Step 5.2: Commit**

```bash
cd .worktrees/removed-player-fix
git add lib/screens/cricket_game_screen.dart \
        lib/screens/game_screen.dart \
        lib/screens/around_the_clock_game_screen.dart \
        test/screens/removed_player_winner_test.dart
git commit -m "fix(cricket,x01,atc): removed mid-game player no longer becomes winner

Add private helper _winnerIndexExcludingRemoved() that walks finishedPlayers
and returns the first index not in _removedPlayerIndices. Replace all
finishedPlayers.first-based winner picks (and downstream stats checks that
match by index) with the helper.

Removed players continue to be added to finishedPlayers so the ~70 existing
finishedPlayers.contains(i) sites used as 'is this player still playing?'
guards stay correct. The fix is intentionally minimal — full audit of those
guards is deferred to a follow-up if QA finds post-game ranking misbehaviour.

Killer and Shanghai use different winner patterns (isEliminated array /
engine-based) and are not affected. Halve It uses highest-score; verified
no change needed.

Adds removed_player_winner_test.dart with one test per affected mode using
@visibleForTesting hooks (removePlayerForTest, computeWinnerForTest).

Spec: docs/superpowers/specs/2026-05-13-removed-player-winner-fix-design.md"
```

- [ ] **Step 5.3: Push and open PR (controller handles)**

---

## Self-review notes

**Spec coverage:**
- §Fix pattern → Tasks 1, 2, 3 ✓
- §Round-skip logic for removed players → not needed for the minimal approach; `finishedPlayers` membership is preserved so existing skip logic still works ✓
- §Halve It verification → covered as "verified, no change" in File map; no implementation task needed ✓
- §Unit/widget tests → Task 4 ✓

**Trade-off documented:** Plan goes with minimal-blast-radius approach instead of the spec's "drop finishedPlayers.add + audit 70 sites" approach. Rationale in Architecture section.

**No placeholders.** Helper body is identical across all three files (DRY at the readability level even if duplicated as code — extracting to a shared mixin is overkill for 3 sites).

**Type consistency:** Helper signature `int? _winnerIndexExcludingRemoved()` identical across all three files. Test hooks `removePlayerForTest(int)`, `computeWinnerForTest() → int?`, `finishedPlayersForTest → List<int>`, `removedPlayerIndicesForTest → Set<int>` identical across all three files.
