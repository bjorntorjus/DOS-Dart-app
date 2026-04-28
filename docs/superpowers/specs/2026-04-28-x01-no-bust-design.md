# X01 No-Bust Mode — Design Spec

**Date:** 2026-04-28
**Status:** Approved (pending plan)
**Author:** Bjørn + Claude (superpowers:brainstorming)

## Problem

Current X01 treats overshoot as a bust → score resets, turn ends. Bjørn wants a casual variant where reaching score ≤ 0 is a *finish*, and overshoot is the goal of a tiebreak race rather than a punishment.

## Goal

Add a `noBust` toggle to X01. When enabled, the player whose dart takes them to score ≤ 0 has *finished*; multiple finishers in a single round are ranked by total dart count (lower wins), then by overshoot (higher wins). Out-rule (Any / Double / Master) and Handicap continue to function unchanged when combined.

## Non-Goals

- New game mode entry on home screen — this is a toggle on existing X01.
- Refactoring `game_screen.dart` to extract an X01 engine — separate future spec (per `project_unit_testing.md` memory).
- Stats analytics dashboards for no-bust games — basic recording only; richer stats can come later.
- Sound/TTS variants specific to overshoot — reuse existing sound triggers.

## Win Rules (No-Bust Mode)

A player **finishes** when their dart takes their score to ≤ 0, AND the dart satisfies the active out-rule:

| `newScore` | masterOut='none' | masterOut='double' | masterOut='master' |
|---|---|---|---|
| `> 1` | continue turn | continue turn | continue turn |
| `== 1` | continue turn | turnEndNoBust | turnEndNoBust |
| `== 0` | finish (overshoot=0) | finish if mult==2, else turnEndNoBust | finish if mult≥2, else turnEndNoBust |
| `< 0` | finish (overshoot=`abs(newScore)`) | finish if mult==2, else turnEndNoBust | finish if mult≥2, else turnEndNoBust |

Where:
- **finish** = record `_FinishEntry`, advance to next player. Player's displayed score becomes 0.
- **turnEndNoBust** = the dart "doesn't count": player's score returns to `scoreAtStartOfTurn`, no `_FinishEntry`, advance to next player. (No bust reset, but the turn ends.)
- **continue turn** = standard X01 continuation.

**Tiebreak ranking among finishers:**
1. Lowest `totalDartsAtFinish` wins.
2. If tied on dart count → highest `overshoot` wins.
3. If still tied → shared top placement.

## Architecture

```
GameScreen (existing X01 screen, modified)
  ├── new ctor param: bool noBust
  ├── new state: List<int> _totalDartsPerPlayer
  ├── new state: List<_FinishEntry> _finishes
  ├── new helper: _ThrowOutcome _classifyThrow(...)
  ├── new helper: bool _anyoneCanBeat(_FinishEntry leader)
  └── existing PostGameScreen reused with canContinue: true
       when early termination triggers
```

No new files. Toggle wired through:
- `lib/screens/player_setup_screen.dart` — new `bool _noBust = false` state, toggle in X01 options card.
- `lib/screens/game_screen.dart` — accept `noBust`, branch logic in throw handler.

## Components

### `_ThrowOutcome` enum (file-private to game_screen.dart)
```dart
enum _ThrowOutcome { continueTurn, finish, turnEndNoBust, bust }
```

`bust` is only used in standard (non-no-bust) mode. In no-bust mode, the classifier never returns `bust` — it returns `turnEndNoBust` instead.

### `_FinishEntry` (file-private)
```dart
class _FinishEntry {
  final int playerIndex;
  final int totalDartsAtFinish; // game-wide dart count for that player
  final int overshoot;          // 0 if exact-out, else abs(newScore)
  final int turnId;
}
```

### `_classifyThrow` helper
Pure function; takes `newScore`, `multiplier`, `masterOut`, `noBust` → returns `_ThrowOutcome`.

This isolates the rule logic from the rest of the throw handler so it can be tested or extracted later when the engine refactor happens.

### `_anyoneCanBeat` helper
Conservative beat-check; takes the current leader's `_FinishEntry` and returns `true` if any remaining player (those who haven't thrown all 3 darts this round AND aren't already finished) could possibly beat the leader given their current score and remaining darts in this round.

Maximum-achievable bounds:
- Per non-final dart: 60 points (T20).
- Per final dart in `'none'`: 60 (T20).
- Per final dart in `'double'`: 50 (D-Bull, the highest double).
- Per final dart in `'master'`: 60 (T20, highest master-eligible).

Pn could-beat condition (any of):
- Can reach ≤0 with valid out-pil in `K < leader.totalDartsAtFinish - dartsAlreadyUsed` darts (lower dart-count).
- Can reach ≤0 with valid out-pil using exactly `K = leader.totalDartsAtFinish - dartsAlreadyUsed` darts AND maximum reachable overshoot ≥ leader.overshoot + 1 (same dart-count, higher overshoot).

If neither holds for any remaining player, return `false` → trigger early-termination flow.

## Data Flow (no-bust mode)

```
Per dart (after newScore computed):

outcome = _classifyThrow(newScore, multiplier, masterOut, noBust=true)

switch outcome:
  case continueTurn:
    player.score = newScore
    dartsInTurn++
    _totalDartsPerPlayer[currentPlayerIndex]++

  case finish:
    push _FinishEntry { playerIndex, totalDarts (after this dart),
                        overshoot=max(0,-newScore), turnId }
    player.score = 0   // displayed
    _totalDartsPerPlayer[currentPlayerIndex]++
    isTurnEnd = true
    if not _anyoneCanBeat(leader = currentLeader(_finishes)):
      → trigger early-termination flow (see below)
    else:
      _advancePlayer()

  case turnEndNoBust:
    player.score = scoreAtStartOfTurn (no change)
    _totalDartsPerPlayer[currentPlayerIndex]++  // dart still thrown
    isTurnEnd = true
    _advancePlayer()
```

**Round-end resolution (no-bust mode):**
When the last player in a round completes their turn, if `_finishes` is non-empty, call `_resolveFinishes()` → rank by (dartCount asc, overshoot desc) → present `PostGameScreen` with normal ranking (no `canContinue` since round is over).

**Early-termination flow:**
When `_anyoneCanBeat` returns false mid-round:
1. Compute current ranking from `_finishes`.
2. Build `GameResult` with `canContinue: true`.
3. Push `PostGameScreen`. Await result:
   - `'home'` (Finish Game) → record stats, navigate to home.
   - `'continue'` → pop back, resume current round; remaining players throw their remaining darts. Any new finish updates ranking but top placement is preserved (since beat-check was conservative — by construction nobody can pass the leader).
   - `'undo'` → pop back, undo the finishing throw.

## Edge Cases

| Case | Behavior |
|---|---|
| Player finishes on dart 1 of 3 | dart 2 and 3 NOT thrown; turn ends. `totalDartsAtFinish` reflects exact count. |
| Two players finish in same round, equal dart count, equal overshoot | Both share top placement; `PostGameScreen` displays tie. |
| Two players finish in different rounds | Earlier finish wins (lower dart count). Beat-check should have handled this — only happens if beat-check said "yes someone can beat" and they did. |
| Player reaches `newScore == 1` in DO/Master mode | turnEndNoBust — score unchanged, turn ends. |
| Player attempts overshoot with wrong out-pil in DO mode | turnEndNoBust — dart "doesn't count" but turn ends. |
| Mid-game player add | New player starts with full score and `_totalDartsPerPlayer = 0`. |
| Mid-game player remove | Remove their entry from `_totalDartsPerPlayer` and any `_FinishEntry`s. |
| Undo a finish | Pop from `_finishes`, decrement `_totalDartsPerPlayer`, restore score. Existing undo-stack pattern extended. |
| Handicap | Affects starting score only, identical to standard X01. No-bust logic operates on the (possibly handicapped) score. |
| Continue chosen after early-termination | Resume mid-round. Beat-check guarantees no upset; remaining throws are cosmetic. |

## Logging

- Existing `logThrow` calls used unchanged for normal throws.
- For `finish` outcomes: log via `logFinish` with extra payload `'overshoot=$overshoot darts=$totalDarts'`.
- For `turnEndNoBust`: log via `logThrow` with `extra: 'NO_BUST_TURN_END'` so it's distinguishable from regular busts in the audit trail.
- `logGameStart` config payload includes `'noBust': true` when toggle is on.

## Stats

`StatsRecorder.recordGame` extra payload includes:
- `noBust: true`
- `finishes: [{playerIndex, totalDarts, overshoot}, ...]`

This keeps the existing stats system untouched while making no-bust games filterable later if richer analytics are wanted.

## UI

- Player setup: new `SwitchListTile` "No-bust mode" inside X01 options card, below the existing Handicap toggle. Subtitle: "Going over score = finish; biggest overshoot wins ties."
- Game screen AppBar title: existing pattern shows e.g. "501 - Free-Out". When no-bust is on, append " (No-Bust)" → "501 - Free-Out (No-Bust)".
- No new dialogs; reuse `PostGameScreen` with `canContinue: true` for early-termination.
- No new icons or color changes.

## Testing

This spec does NOT include unit tests for the new logic, because:
1. The X01 logic still lives inline in the 1500-line screen file (no engine extracted yet).
2. Adding tests would require either Flutter widget tests (heavy) or extracting the helpers (out-of-scope refactor).

The two new helpers (`_classifyThrow` and `_anyoneCanBeat`) are written as pure top-level functions where possible, so when the X01 engine refactor happens (planned per memory), they can be tested without further changes.

Manual test plan:
- Short 101 game with 2 players, no-bust + Free-Out → confirm overshoot wins.
- Short 101 game with 2 players, no-bust + Double-out → confirm wrong-out at score 0 ends turn without reset.
- Game where one player finishes but other could still beat → confirm round continues normally.
- Game where one player finishes uncatchably → confirm `PostGameScreen` appears mid-round with Continue/Finish.

## Out of Scope (Future Work)

- X01 engine extraction (will make no-bust + tests trivial).
- Combining no-bust with new "race to bust" stat tracking (e.g., highest single-game overshoot).
- Sound/TTS variant for overshoot finish vs. exact finish.
