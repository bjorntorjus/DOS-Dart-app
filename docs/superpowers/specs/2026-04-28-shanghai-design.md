# Shanghai Game Mode — Design Spec

**Date:** 2026-04-28
**Status:** Approved (pending plan)
**Author:** Bjørn + Claude (superpowers:brainstorming)

## Problem

The Dart Scoring App currently supports five game modes: X01, Cricket, Around the Clock, Killer, Halve It. Shanghai is a popular pub-style mode that fits the app's existing patterns and is missing from the lineup.

## Goal

Add a fully-functional Shanghai game mode following the same architecture as existing modes (own screen + config subclass + integration with existing services).

## Game Rules (Classic Shanghai)

- **Round-based**: target sequence runs `1, 2, ..., N` where N is configurable (7 / 9 / 20).
- **Each round** all players throw 3 darts at the round's target number.
- **Scoring**: Single = `1×target`, Double = `2×target`, Triple = `3×target`. Misses (or hits on other numbers) score 0.
- **Instant win ("Shanghai")**: hit Single + Double + Triple of the round's target in the same turn → immediate win.
- **Final win**: if no instant Shanghai by end of last round, highest cumulative score wins.
- **Direction**: ascending (1 → N), fixed.

## Non-Goals

- Bull round (no demand; can be added later)
- Random target sequence (no demand)
- Reverse direction (20 → 1)
- Mid-turn instant-Shanghai detection — we check only after the third dart, matching pub convention.

## Architecture

```
GameMode.shanghai            (new enum value in lib/models/game_mode.dart)
ShanghaiConfig               (new sealed-class subclass in lib/models/game_config.dart)
ShanghaiGameScreen           (new screen in lib/screens/shanghai_game_screen.dart)
                             ├── uses GameLogger (existing, gated by LogMode)
                             ├── uses GameAnnouncer (existing)
                             ├── uses SoundService (existing)
                             ├── uses TtsService (existing)
                             ├── uses BatterySampler (existing)
                             └── uses StatsRecorder (existing)
player_setup_screen.dart     (extend mode-options to show 1–7 / 1–9 / 1–20 selector)
home_screen.dart             (add Shanghai entry to mode list)
```

## Components

### `lib/models/game_mode.dart` (modify)

Add enum value and label:

```dart
enum GameMode {
  x01,
  cricket,
  aroundTheClock,
  killer,
  halveIt,
  shanghai,
}
```

In the label extension, add `case GameMode.shanghai: return 'Shanghai';`

### `lib/models/game_config.dart` (modify)

```dart
class ShanghaiConfig extends GameConfig {
  final int targetEnd; // 7, 9, or 20 — sequence is 1..targetEnd
  const ShanghaiConfig({this.targetEnd = 7})
      : super(GameMode.shanghai);
}
```

### `lib/screens/shanghai_game_screen.dart` (new)

State fields:

```dart
List<Player> players;
ShanghaiConfig config;
int currentRound;             // 0-indexed; target = currentRound + 1
int currentPlayerIndex;
int dartNumber;               // 0..2 within turn
List<int> totalScores;        // per player, cumulative; growable
Set<HitType> currentTurnHits; // for instant-Shanghai detection
List<UndoEntry> undoStack;
List<int> finishedPlayers;    // empty until game-end ranking
bool gameOver;
```

Helper enum (file-private):

```dart
enum HitType { single, double, triple, miss }
```

UI layout follows the Halve It pattern:
- Top: round indicator ("Round 3 of 7 — target: 3"), per-player score column with active highlight.
- Middle: current player's accumulated S/D/T tracker for the turn (visual hint of instant-Shanghai progress).
- Bottom: 4 large buttons — `Single`, `Double`, `Triple`, `Miss`.
- Existing inline buttons: undo, exit, post-game transitions follow Halve It / ATC patterns.

### `lib/screens/player_setup_screen.dart` (modify)

Add Shanghai-specific options block in `_buildModeOptions()` — three-way radio for `targetEnd`:
- "1–7 (short)" → `targetEnd = 7`
- "1–9 (medium)" → `targetEnd = 9`
- "1–20 (long)" → `targetEnd = 20`

Default to 7. Field on state: `int _shanghaiTargetEnd = 7;`

### `lib/screens/home_screen.dart` (modify)

Add Shanghai card to the mode selector grid following the existing visual pattern. Choose an icon that fits (e.g., `Icons.star` or `Icons.flash_on`).

## Data Flow (per dart)

```
User taps [Single | Double | Triple | Miss]
  ↓
hitType registered
  ↓
multiplier = {single:1, double:2, triple:3, miss:0}[hitType]
target = currentRound + 1
points = multiplier * target
totalScores[currentPlayerIndex] += points
  ↓
if hitType != miss: currentTurnHits.add(hitType)
  ↓
push UndoEntry{round, player, dart, hitType, pointsDelta} to undoStack
  ↓
GameLogger.logThrow(...)
SoundService.play(...) — reuse existing hit/miss sounds
TtsService.speak(...) if enabled
  ↓
dartNumber++
  ↓
if dartNumber == 3:
  if {single, double, triple} ⊆ currentTurnHits:
    → INSTANT WIN: gameOver = true, winner = currentPlayer
  else:
    advance to next player; dartNumber = 0; currentTurnHits.clear()
    if all players have thrown this round:
      currentRound++
      if currentRound == config.targetEnd:
        → GAME END (rank by totalScores; tie possible)
```

## Edge Cases

| Case | Handling |
|------|----------|
| Undo across round boundary | UndoEntry includes round + player + dart; rolls back fully including currentTurnHits restoration |
| Mid-game player add | New player joins with score 0, starts in next round (not mid-turn). Simpler than Cricket newcomer logic. |
| Mid-game player remove | Remove from players list, adjust currentPlayerIndex if needed, continue |
| Tied final score | Display tie in post-game; no sudden death. Rare enough not to warrant extra rules. |
| Player gets Shanghai but is not last to throw the round | Game ends immediately; remaining players don't throw. |
| Instant Shanghai with last dart bringing them to S+D+T exactly | Standard: detect after 3rd dart; this case is the most common Shanghai. |

## Logging

`GameLogger.logGameStart` config payload includes `targetEnd`. Per-throw events use existing `logThrow`. New game-end log includes whether the win was a Shanghai (instant) or score-based.

## Testing

Unit tests for `ShanghaiGameEngine` (pure rules function, no UI):

- Score accumulation: S/D/T on each target value 1..20 produces correct points.
- Miss produces 0 points and does NOT add to currentTurnHits.
- Instant Shanghai detected when {Single, Double, Triple} all hit in same turn (test all 6 permutations).
- NOT instant Shanghai when only 2 of 3 types hit.
- NOT instant Shanghai when 3 hits all of same type (e.g., 3× Single).
- Game ends correctly after last round; high-score wins.
- Tie detection when two players share top score.
- Undo restores currentTurnHits, totalScores, and player/dart pointers correctly.

Tests follow the same pattern planned for X01/Cricket/ATC engines (per existing memory).

## Stats Integration

`StatsRecorder` records:
- Win (with mode = shanghai)
- Final cumulative score
- Whether the win was instant-Shanghai (new boolean field, defaults to false for non-Shanghai modes — or stored in mode-specific stats as preferred)

Match the existing per-mode stats pattern; do not introduce a new top-level stats system.

## UI Style

Match existing modes' visual language:
- Dark theme green primary (#43A047), red secondary (#E53935)
- Per-player score column with active-thrower highlight
- Inline action buttons consistent with Cricket/Halve It

## Out of Scope (Future Work)

- Bull bonus round
- Random target sequence
- Reverse direction
- Per-player handicap (handicap_scale system exists; could be wired in later if requested)

