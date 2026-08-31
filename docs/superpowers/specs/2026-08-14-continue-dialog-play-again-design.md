# Continue Dialog + Play Again — Design

**Date:** 2026-08-14
**Status:** Approved design, pending implementation plan

## Problem

Post-game v2 (`b4b9f56`) shows the PostGameScreen mid-game in "provisional" mode when a
player finishes but others can still play (X01, Cricket, ATC). Bjørn's feedback: the
result screen must not appear together with the continue question. Desired flow:
player finishes → ask keep-playing/end on the game screen → result screen only when
the game is actually over. Additionally: a Play Again button on the (now always final)
result screen that returns to setup with the same settings and players.

## Part A — Continue dialog (X01, Cricket, ATC)

When a player finishes and **≥2 active players remain**, show a dialog on the game
screen instead of navigating to PostGameScreen:

- Content: `★ <NAME> CHECKED OUT ★` (X01) / `FINISHED` (Cricket, ATC), placement,
  "N players can still play for the places", buttons **KEEP PLAYING** / **END GAME**.
- Tapping outside the dialog = KEEP PLAYING (safe default).
- No undo button in the dialog; a mis-entered finishing dart is fixed with the normal
  undo after KEEP PLAYING (equivalent to today's `'undo'` pop-result path).
- The dialog reappears for **every** subsequent finisher while ≥2 active remain —
  same cadence as today's provisional screen. When ≤1 active remains, the game is
  over → full result screen.
- END GAME → final PostGameScreen: final placements (unfinished players ranked by
  current standing, as today), full stats, Elo, progression chart.
- DOSSEDART track: DOSSEDART-styled dialog. Classic track: classic-styled dialog,
  following the existing exit-confirmation dialog pattern.

### PostGameScreen becomes always-final

- Remove `canContinue`/provisional mode from `post_game_screen.dart` and the CONTINUE
  button from `dossedart_post_game_actions.dart`, including the provisional branch
  (hidden stats, "game in progress" label, `showStats` plumbing where it only served
  provisional mode).
- Post-game undo (BACK) is unchanged.

## Part B — PLAY AGAIN on the result screen (all modes)

New **PLAY AGAIN** action in `DossedartPostGameActions` next to FINISH GAME. Because
PostGameScreen is always final after Part A, the button only ever appears once the
players have moved past the keep-playing question.

- Pop result `'again'`. The game screen then behaves like the FINISH GAME path first
  (record deferred stats exactly once), then `popUntil(first)` + push
  `PlayerSetupScreen` with a prefill — home remains underneath, so back from setup
  goes home.
- `PlayerSetupScreen` gains an optional prefill parameter: mode options,
  `savedPlayerId` list, `randomizeOrder`. Each game screen builds it from its widget
  params + the **roster at game end** (mid-game joiners included, removed players
  excluded). Players without a `savedPlayerId`, or whose saved entry no longer
  exists, are silently skipped.
- Setup opens with players preselected and all options set — one tap on START GAME
  for a rematch, everything still adjustable.

## Testing

- Widget tests: dialog triggers on a finisher with ≥2 active remaining; not on the
  last finisher; KEEP PLAYING resumes play; END GAME shows the final result screen.
- Regression: PLAY AGAIN records stats exactly like FINISH GAME (no double/missing
  recording); prefill mapping with mid-game join/leave.
- Update existing post-game tests where provisional mode disappears.

## Scope

- Part A: `game_screen.dart`, `cricket_game_screen.dart`,
  `around_the_clock_game_screen.dart`, post-game widgets.
- Part B: all 10 game screens (prefill building) + `player_setup_screen.dart`.
- Branch: release train (`feat/elo-seasons`).
