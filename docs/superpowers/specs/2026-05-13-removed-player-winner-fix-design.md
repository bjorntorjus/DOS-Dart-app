# Removed mid-game player can win — design

**Date:** 2026-05-13
**Target branch:** `fix/removed-player-winner-index` (worktree `.worktrees/removed-player-fix`, branched from `main`)

## Problem

When a player is removed mid-game in Cricket, X01, or Around the Clock, their `playerIndex` is appended to both `_removedPlayerIndices` AND `finishedPlayers`. The winner is then computed as `winnerIndex = finishedPlayers.first` — so if a removed player's index landed first in the list, they are incorrectly declared the winner. Bug discovered 2026-05-12 in Cricket.

Affected files (verified on `main` 2026-05-13):

- `lib/screens/cricket_game_screen.dart` — remove handler at line 1230 (`_removedPlayerIndices.add`) + 1235 (`finishedPlayers.add`); winner picks at 142, 145, 373
- `lib/screens/game_screen.dart` (X01) — remove handler at 1877 + 1884; winner picks at 725, 820, 914, 1056
- `lib/screens/around_the_clock_game_screen.dart` — remove handler at 1354 + 1359; winner picks at 381, 424, 504, 727

Not affected:

- **Killer** — already filters via `isEliminated` + `!_removedPlayerIndices.contains(i)` checks
- **Halve It / Splitscore** (`halve_it_game_screen.dart:1197`) — uses highest score for winner, not `finishedPlayers.first`. Verified during implementation by reading the file's winner-picking logic; if confirmed, no change. If touching `_removedPlayerIndices` still affects an "all-finished" condition, fix in this PR.
- **Shanghai** — different winner pattern entirely (engine-based). Verified during implementation; no expected change.

## Goals

- Removed players are never declared the winner.
- `winnerIndex = finishedPlayers.first` becomes correct by construction (removed players are not in `finishedPlayers` at all).
- "All players finished" detection still works after the change.

## Non-goals

- Refactoring the mid-game-remove UI or storage
- Touching Killer or Shanghai
- Cleaning up the unrelated "winner picks" code paths beyond what the bug requires

## Design

### Fix pattern (applied to all three game screens)

**Remove handler** — drop the `finishedPlayers.add(playerIndex)` line. Keep `_removedPlayerIndices.add(playerIndex)`. The removed player is tracked in `_removedPlayerIndices` only.

Before (Cricket example, line 1230-1235):
```dart
_removedPlayerIndices.add(playerIndex);
// ...
finishedPlayers.add(playerIndex);   // ← drop this
```

After:
```dart
_removedPlayerIndices.add(playerIndex);
// ...
```

**"All finished" checks** — every comparison like `finishedPlayers.length >= players.length - 1` (or any variant using `finishedPlayers.length` as a stop condition) must include removed players in the count:

```dart
finishedPlayers.length + _removedPlayerIndices.length >= players.length - 1
```

The implementation plan will enumerate every site per file via grep (search for `finishedPlayers.length` plus the `length` of `players` or `activePlayers`), update them, and add a code comment on the first one explaining the invariant.

**Winner picks** — `winnerIndex = finishedPlayers.first` and `players[finishedPlayers.first]` stay as-is. They are correct once removed players are out of `finishedPlayers`.

### Round-skip logic for removed players

Removing a player from `finishedPlayers` may affect round-loop skip logic that historically piggybacked on the finished-list to skip removed players' turns. Each game-screen must instead check `_removedPlayerIndices.contains(i)` explicitly when iterating active players.

The plan task list will:
1. Grep each file for places that iterate `players` and check `!finishedPlayers.contains(i)` as a skip condition
2. Add `&& !_removedPlayerIndices.contains(i)` where the intent was "skip players no longer playing"
3. Leave alone the `finishedPlayers.contains(i)` checks whose intent is "skip players who already won"

### Halve It verification

Read `halve_it_game_screen.dart` winner-picking logic during implementation. Two possibilities:

- **Halve It computes winner as `players.indexOf(highestScorePlayer)` ignoring `finishedPlayers`** — no fix needed beyond verifying.
- **Halve It uses `finishedPlayers` indirectly** (e.g., for round termination) — apply the same `length + _removedPlayerIndices.length` fix to those checks.

Document the finding in the PR description.

## Verification

### Unit/widget tests

Three tests, one per affected mode. New file: `test/screens/removed_player_winner_test.dart`.

Each test:
1. Construct the game screen with 3 players (P0, P1, P2).
2. Drive the game far enough that the mid-game remove UI is reachable (or invoke the remove handler directly through a test helper if exposed).
3. Remove P0 mid-game.
4. Drive P1 to win.
5. Assert `winnerIndex == 1` and `players[winnerIndex].name == 'P1'`.
6. Assert removed `_removedPlayerIndices == [0]` and `finishedPlayers` does NOT contain `0`.

Cricket-specific: must reach the all-finished state from `winnerIndex` site at line 142/145.
X01-specific: must reach checkout at line 820 site (or 914 for sudden-death variant).
ATC-specific: must hit `winnerIndex = finishedPlayers.first` at line 424 or 504.

If invoking the remove handler from a test requires UI tapping through a dialog, use `WidgetTester.tap` on the menu item. If it requires private-state access that tests can't reach, expose a `@visibleForTesting` setter or factor the handler into a testable helper.

### Manual

- 3-player Cricket: remove P0 mid-game, let P1 finish first → assert P1 is shown as winner on post-game.
- Same for X01 and ATC.

## Out of scope

- Killer (already correct)
- Shanghai (different pattern)
- Stats-recording side effects beyond the `winnerIndex` consumer chain — the bug only affects who the winner is; downstream stats see the corrected value.

## Commit plan

Single commit on `fix/removed-player-winner-index`:

```
fix(cricket,x01,atc): removed mid-game player no longer becomes winner

Drop finishedPlayers.add(playerIndex) in remove handlers — removed players
are tracked only in _removedPlayerIndices. Update "all finished" checks to
include _removedPlayerIndices.length so game-end detection still works.

- Cricket: remove handler + 3 winner-pick sites + N all-finished checks
- X01:     remove handler + 4 winner-pick sites + N all-finished checks
- ATC:     remove handler + 4 winner-pick sites + N all-finished checks
- Halve It: verified winner-picking is score-based; no change OR <fix details>

Adds removed_player_winner_test.dart with one test per affected mode.
```
