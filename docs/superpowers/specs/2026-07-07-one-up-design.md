# 1UP Game Mode — Design Spec

**Date:** 2026-07-07
**Status:** Approved rules; awaiting visual design (DOSSEDART artboards) before implementation
**Scope:** New game mode "1UP" (working name during brainstorm: "Legs"). Second of the three new modes (Gotcha → **1UP** → Golf).

---

## 1. Overview

1UP is a pressure game about lives. Each turn you must **beat the previous thrower's 3-dart total** — one-up them — or lose a life. Run out of lives and you're eliminated; last one standing wins.

The name is an arcade reference (1UP = extra life) and fits the DOSSEDART theme. "Legs" (the traditional name) was rejected because it collides with X01 legs/sets terminology in the cockpit.

## 2. Rules (approved)

- Every player starts with **3 lives** (selectable **3 / 5** in setup, default 3). Lives shown as arcade pips/hearts.
- The first player of the game throws **free** — no target — and their 3-dart total sets the target.
- Each subsequent player must **strictly beat** the target. **Tie = fail.**
- A turn is always **3 darts** — even after you've beaten the target, remaining darts count, because your total becomes the next target (you want it high).
- **Beat the previous throw** variant: the target is always the **last actual 3-dart total thrown**, success or fail.
  - Beat it → your total is the new target.
  - Fail → you lose a life, **and your (lower) total still becomes the new target.** Self-correcting: after a weak round the bar drops, so the game can never deadlock on an unbeatable number. Sandbagging is impossible — failing costs you a life.
  - (The "standing target" variant — target stays until beaten — was considered and rejected for v1: risks a death spiral where everyone bleeds lives against one huge number.)
- **0 lives → eliminated.** Elimination order determines placements (as in Killer). An eliminated player's final throw remains the target for the next player.
- **Win:** last player alive. Single game, no legs/sets.

## 3. In-turn feedback logic

- Active player always sees the target: **`BEAT 87`**.
- After each dart, show what's still needed: `NEED 45 MORE` (`target − turnTotal + 1`).
- **SAFE state:** the moment `turnTotal > target`, flip to a success state (`SAFE — NEW TARGET: 92…`) while the remaining darts pad the new target.
- **CAN'T-BEAT state:** when the needed amount exceeds the max possible with the darts left (60/dart), flip to a danger state (`CAN'T BEAT — LIFE AT RISK`). The player still throws all 3 darts (their total sets the next target).
- All strings in English (Norwegian-string guard test applies).

## 4. Screens & states (design handoff)

Surfaces for Claude design / DOSSEDART artboards. Visual style per the existing arcade system; this section defines required elements/states only.

> **Designer: read `2026-07-07-new-modes-design-brief.md` first** — it defines the design/implementation split and which existing components must be reused rather than redesigned.

### 4.1 Home screen

- The "Legs" coming-soon tile from the Gotcha spec is named **1UP** (dimmed/disabled until shipped, then lights up). Grid layout otherwise as specced in the Gotcha design (3×3).

### 4.2 Setup screen

- Standard player setup (reuses `PlayerSetupScreen`) + **lives selector: 3 / 5** (chip pattern like other mode options).
- Add/remove players mid-game supported: an added player enters the rotation with full lives; a removed player's last throw stands as target if it was current.

### 4.3 In-game cockpit

DOSSEDART cockpit pattern (TopBar · player carousel · dartboard input · ActionBar), with 1UP specifics:

- **Active card:** big `BEAT <target>` as the primary number; running `turnTotal` + `NEED <n> MORE` line; dart counter as usual.
- **All player cards:** life pips (filled/empty hearts), dimmed/eliminated styling for dead players.
- **States to design:**
  1. Free opening throw (first turn of the game — no target, e.g. `SET THE TARGET`)
  2. Default (`BEAT 87` + `NEED n MORE`)
  3. SAFE (target beaten mid-turn, building new target)
  4. CAN'T-BEAT (needed > max possible with darts left)
  5. Life lost (pip breaking — the signature moment)
  6. Last life (persistent danger styling on that player's card)
  7. Elimination
  8. Winner
- Input: reuses X01 dartboard/score input.

### 4.4 Post-game

- Reuses `post_game_screen`. Placements by elimination order (winner first, then reverse elimination order).
- Mode-specific stat rows: highest turn, targets set, lives lost, turns survived, times saved on last dart (nice-to-have).
- Post-game **Undo must work** (Shanghai post-game undo protocol is the reference).

## 5. Data model & architecture

- `GameMode.oneUp`, label `'1UP'`, emoji (suggest ❤️ or 🕹️; final pick with design).
- `OneUpConfig extends GameConfig { final int lives; }` (sealed-class pattern).
- `lib/screens/one_up_game_screen.dart` — own screen, Shanghai template.
- Game state: per-player lives, alive/eliminated, current target, whose throw set it. Undo stack entries capture life loss, target changes, and eliminations so undo restores everything.

## 6. Integrations

- **GameAnnouncer / sounds:** `assets/sounds/one_up/` — events: target beaten ("beat that!"), life lost, last life, elimination, big target set (≥ 100), winner. TTS fallback for all; dedicated recordings optional later. MemeService hooks as standard.
- **Stats (StatsRecorder):** games, wins, highest turn, avg turn, lives lost, eliminations dealt (players who died failing to beat *your* target — optional if cheap), placements. H2H + Elo recorded. Turn history for match-details drill-down.
- **Removed-player handling:** removed-player-wins fix pattern from day one + regression test.
- **VideoService:** generic winner video.

## 7. Edge cases

- Turn 1 has no target: no fail possible, total simply sets the bar.
- Tie = fail (strictly greater required).
- Eliminated players are skipped in rotation; their last throw can still be the standing target.
- Undo across a life loss restores the life; undo across an elimination revives the player; target rolls back with the throw history.
- Removing the player whose throw is the current target does not change the target (it is just a number).
- 2-player endgame works unchanged: alternate beating each other until one runs dry.
- Score 0 turn (three misses): next player must beat 0 → any score ≥ 1 succeeds.

## 8. Testing

- Unit tests (engine-style, like `ShanghaiGameEngine`): target progression, tie = fail, fail sets new (lower) target, life loss, elimination + placement order, free opening throw, undo restoring lives/target/eliminations, all-miss turn.
- Widget/regression: removed-player result screen, Norwegian-string guard.

## 9. Out of scope (v1)

- Standing-target variant (possible future toggle), teams, sudden-death tiebreakers, dedicated sound-pack recordings, dedicated winner video.

## 10. Delivery flow

1. This spec → **Claude design** produces DOSSEDART artboards for §4 (states 1–8 + tile).
2. Artboard spec cards are fasit for the UI.
3. Implementation plan (writing-plans) → build on a `feat/one-up` branch → tablet QA (Galaxy Tab emulator).
4. Builds **after** Gotcha ships (order: Gotcha → 1UP → Golf).
