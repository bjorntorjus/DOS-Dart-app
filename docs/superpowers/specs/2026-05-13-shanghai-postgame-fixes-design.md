# Shanghai post-game Undo + instant-Shanghai trigger — design

**Date:** 2026-05-13
**Target branch:** `fix/shanghai-postgame-undo-and-instant-trigger` (worktree `.worktrees/shanghai-fixes`, branched from `main`)

## Problem

Two issues in `lib/screens/shanghai_game_screen.dart`:

1. **Post-game Undo resets the game.** When a Shanghai match ends, `_onGameEnd` calls `Navigator.pushReplacement(...)` to show `PostGameScreen` (removing `ShanghaiGameScreen` from the stack) and runs `await _updateStats(ranking)` *before* showing the post-game screen. If the user taps Undo on the post-game screen, the returned `'undo'` action pops out of the game flow entirely (no game-screen left under it), and stats have already been recorded — so even fixing the navigation alone would leave Elo/StatsRecorder/PlayerStorage out of sync.
2. **No celebration trigger.** Shanghai has no video/meme on game-end winner or on instant Shanghai (S+D+T on the same target in one turn — a rare and spectacular event). Other game modes have winner video on game-end.

## Goals

- Post-game Undo returns to `ShanghaiGameScreen` with the last action rolled back, no stats persisted.
- `_updateStats(ranking)` only runs after the user confirms Finish Game on the post-game screen.
- Game-end fires `VideoService.showRandomFromFolder('winner')` to match other modes.
- Instant-Shanghai (`engine.isInstantShanghai == true`) fires the same `'winner'` video PLUS a high-priority TTS announcement `"INSTANT SHANGHAI!"`.

## Non-goals

- New dedicated video folder for instant Shanghai (reuses existing `winner` folder per scope discussion).
- High-round trigger (turn ≥ 100 in round 12+) mentioned in memo — deferred.
- Touching other game screens.

## Design

### 1. Navigation + stats flow

Replace the current `_onGameEnd` body to mirror X01's `game_screen.dart` push-and-await pattern:

```dart
Future<void> _onGameEnd(List<int> ranking) async {
  // Fire celebration BEFORE showing post-game.
  await _fireWinnerCelebration();

  final action = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => PostGameScreen(
        players: players,
        ranking: ranking,
        // ...other args as today
      ),
    ),
  );

  if (!mounted) return;

  if (action == 'undo') {
    setState(() => engine.undo());
    return;
  }

  // 'home' or null (back-button) — persist stats, then leave the screen.
  await _updateStats(ranking);
  if (!mounted) return;
  Navigator.pop(context);
}
```

`_updateStats(ranking)` keeps its current body but is no longer called inside `_onGameEnd` before navigation — it moves to the action handler.

### 2. Winner celebration

New private method:

```dart
Future<void> _fireWinnerCelebration() async {
  if (engine.isInstantShanghai) {
    // High-priority announcement; cancel queued TTS so this lands immediately.
    await GameAnnouncer.instance.cancelAndSpeak('INSTANT SHANGHAI!');
  }
  await VideoService.instance.showRandomFromFolder('winner');
}
```

`GameAnnouncer.cancelAndSpeak(...)` may need to be added to `lib/services/game_announcer.dart` if it doesn't already exist (verify during implementation — if it does, use it; if not, add a thin wrapper around `TtsService` that clears the queue first). The plan task list will check this.

`VideoService.showRandomFromFolder('winner')` is the same call other modes use. If the folder is empty or the asset is missing, `VideoService` already silently no-ops — no extra guard needed.

### 3. `engine.undo()` invariants

Per memo, `engine.undo()` already restores `gameOver`, `winnerIndex`, and `isInstantShanghai`. Verify during implementation by reading `lib/services/shanghai_engine.dart` — if any of those don't reset, fix in the same PR.

## Verification

### Widget test

`test/screens/shanghai_postgame_undo_test.dart`:

1. Pump `ShanghaiGameScreen` with 2 players.
2. Drive engine to game-over (call the public API that advances throws, or mock the engine to fast-forward).
3. Assert `PostGameScreen` is in the tree.
4. Tap the Undo button on `PostGameScreen` (find by text `'UNDO'` or the equivalent).
5. Assert:
   - `ShanghaiGameScreen` is back in the tree
   - `engine.gameOver == false`
   - `StatsRecorder.instance.gamesRecorded` (or equivalent counter) has not incremented since before the action
6. Tap the Finish button.
7. Assert:
   - Stats counter has incremented now
   - `Navigator.pop` was called (screen leaves)

If `StatsRecorder` doesn't expose a counter for tests, use an injected/spy stats recorder or check the underlying `SharedPreferences` keys.

### Manual

- Play a Shanghai match to instant-Shanghai (S+D+T on round 1) → verify: `INSTANT SHANGHAI!` TTS, winner video plays
- Play to last-round game-end → verify: winner video plays
- On post-game, tap Undo → verify: back in Shanghai screen, last throw rolled back, stats unchanged
- Tap Finish → verify: stats persisted, returned to home

## Out of scope

- High-round (≥100) trigger
- Dedicated `instant_shanghai` video folder
- Similar `pushReplacement`-pattern audit in other game screens (Halve It etc.) — flagged for a follow-up if QA finds them

## Commit plan

Single commit on `fix/shanghai-postgame-undo-and-instant-trigger`:

```
fix(shanghai): post-game Undo restores game state; add winner + instant-Shanghai triggers

- Switch _onGameEnd to Navigator.push + await pattern (matches X01)
- Move _updateStats out of _onGameEnd into post-Finish action handler
- Add VideoService.showRandomFromFolder('winner') on game-end
- Add high-priority "INSTANT SHANGHAI!" TTS + winner video on engine.isInstantShanghai
- Widget test: post-game Undo returns to game with state intact and no stats persisted
```
