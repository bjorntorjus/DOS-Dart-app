# 1UP Game Mode — Design Spec

**Date:** 2026-07-07 (revised 2026-07-16)
**Status:** Approved rules; awaiting visual design (DOSSEDART artboards) before implementation
**Scope:** New game mode "1UP" (working name during brainstorm: "Legs"). Second of the three new modes (Gotcha → **1UP** → Golf).

> **Revision 2026-07-16:** Added a second game variant (**BEAT THE BEST**, round-based with reset), a random-order toggle, a 1-lives option, and changed the tie rule: **tie = success** (was: tie = fail). Round events parked as v2.

---

## 1. Overview

1UP is a pressure game about lives. Each turn you must **match or beat a target** — one-up the competition — or lose a life. Run out of lives and you're eliminated; last one standing wins.

The name is an arcade reference (1UP = extra life) and fits the DOSSEDART theme. "Legs" (the traditional name) was rejected because it collides with X01 legs/sets terminology in the cockpit.

## 2. Rules (approved)

### 2.1 Common rules (both variants)

- Every player starts with **3 lives** (selectable **1 / 3 / 5** in setup, default 3; 1 = sudden death). Lives shown as arcade pips/hearts.
- A turn is always **3 darts** — even after you've secured the target, remaining darts count, because your total can become the next target (you want it high).
- **Tie = success.** A player whose 3-dart total **equals or beats** the target is safe (`turnTotal >= target`). Only a strictly lower total costs a life.
- **0 lives → eliminated.** Elimination order determines placements (as in Killer).
- **Win:** last player alive. Single game, no legs/sets.

### 2.2 Variant: BEAT THE LAST (default)

- The target is always the **last actual 3-dart total thrown**, success or fail. Continuous through the whole game — no per-round reset.
- The first player of the game throws **free** — no target — and their 3-dart total sets the target.
- Match or beat the target → your total is the new target (a tie leaves the number unchanged).
- Fail → you lose a life, **and your (lower) total still becomes the new target.** Self-correcting: after a weak round the bar drops, so the game can never deadlock on an unbeatable number. Sandbagging is impossible — failing costs you a life.
- An eliminated player's final throw remains the target for the next player.

### 2.3 Variant: BEAT THE BEST

- **Round-based.** The target resets every round: the first thrower of the round throws **free** and their total sets the round target.
- Every subsequent player in the round must **match or beat the highest total thrown so far in the round**. Beat it → your total is the new round max. Tie → safe, max unchanged.
- Fail → lose a life; **the round max never drops** (a failing total is by definition below it). One monster throw can cost several players a life in the same round — but never across rounds, so a big number dies with the round.
- **Starter rotation:** with random order OFF, the round starter rotates round-robin (round 1 starts P1, round 2 P2, …) so the free throw doesn't always fall to the same player. Random order ON overrides this.

### 2.4 Random order (toggle, both variants)

- Setup toggle **Random order** (default off): shuffles the rotation of alive players at the start of each round.
- In BEAT THE LAST a "round" is one full rotation cycle; the target carries across the shuffle unchanged.
- The shuffled order is part of game state (captured by undo).

## 3. In-turn feedback logic

- Active player always sees the target: **`BEAT 87`**.
- After each dart, show what's still needed: `NEED 45 MORE` (`target − turnTotal`; tie counts, so no +1).
- **SAFE state:** the moment `turnTotal >= target`, flip to a success state (`SAFE — NEW TARGET: 92…`) while the remaining darts pad the new target. (In BEAT THE BEST, a tie shows SAFE with the max unchanged.)
- **CAN'T-BEAT state:** when the needed amount exceeds the max possible with the darts left (60/dart), flip to a danger state (`CAN'T BEAT — LIFE AT RISK`). The player still throws all 3 darts: in BEAT THE LAST their total sets the next target; in BEAT THE BEST the total can no longer affect the round max, but the darts are thrown for consistency and stats.
- **Free throw state** (`SET THE TARGET`): first turn of the game in BEAT THE LAST; first turn of **every round** in BEAT THE BEST.
- All strings in English (Norwegian-string guard test applies).

## 4. Screens & states (design handoff)

Surfaces for Claude design / DOSSEDART artboards. Visual style per the existing arcade system; this section defines required elements/states only.

> **Designer: read `2026-07-07-new-modes-design-brief.md` first** — it defines the design/implementation split and which existing components must be reused rather than redesigned.

### 4.1 Home screen

- The "Legs" coming-soon tile from the Gotcha spec is named **1UP** (dimmed/disabled until shipped, then lights up). Grid layout otherwise as specced in the Gotcha design (3×3).

### 4.2 Setup screen

- Standard player setup (reuses `PlayerSetupScreen`) + mode options (chip pattern like other modes):
  - **Lives:** chips **1 / 3 / 5**, default 3.
  - **Variant:** chips **BEAT THE LAST / BEAT THE BEST**, default BEAT THE LAST.
  - **Random order:** on/off toggle, default off.
- Add/remove players mid-game supported: an added player enters the rotation from the next round with full lives; a removed player's last throw stands as target if it was current.

### 4.3 In-game cockpit

DOSSEDART cockpit pattern (TopBar · player carousel · dartboard input · ActionBar), with 1UP specifics:

- **Active card:** big `BEAT <target>` as the primary number; running `turnTotal` + `NEED <n> MORE` line; dart counter as usual.
- **All player cards:** life pips (filled/empty hearts), dimmed/eliminated styling for dead players.
- **States to design:**
  1. Free throw (`SET THE TARGET`) — game start (BEAT THE LAST) / every round start (BEAT THE BEST)
  2. Default (`BEAT 87` + `NEED n MORE`)
  3. SAFE (target matched or beaten mid-turn, building new target)
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
- `OneUpConfig extends GameConfig { final int lives; final OneUpVariant variant; final bool randomOrder; }` (sealed-class pattern).
- `enum OneUpVariant { beatTheLast, beatTheBest }`.
- `lib/screens/one_up_game_screen.dart` — own screen, Shanghai template.
- Game state: per-player lives, alive/eliminated, current target (BEAT THE LAST) / round max + round starter index (BEAT THE BEST), whose throw set it, current rotation order (for random order). Undo stack entries capture life loss, target/round-max changes, eliminations, and rotation order so undo restores everything.

## 6. Integrations

- **GameAnnouncer / sounds:** `assets/sounds/one_up/` — events: target beaten ("beat that!"), life lost, last life, elimination, big target set (≥ 100), winner. TTS fallback for all; dedicated recordings optional later. MemeService hooks as standard.
- **Stats (StatsRecorder):** games, wins, highest turn, avg turn, lives lost, eliminations dealt (players who died failing to beat *your* target — optional if cheap), placements. H2H + Elo recorded. Turn history for match-details drill-down.
- **Removed-player handling:** removed-player-wins fix pattern from day one + regression test.
- **VideoService:** generic winner video.

## 7. Edge cases

- Free throws (game start / round start in BEAT THE BEST) have no target: no fail possible, total simply sets the bar.
- **Tie = success** (equal total is safe; the target number is unchanged by a tie).
- **Target 0 cannot be failed:** after a free throw of 0 (three misses), any total ≥ 0 succeeds — nobody can lose a life against a 0 target. (In BEAT THE BEST that means a 0 opening makes the whole round risk-free until someone raises the max.)
- Eliminated players are skipped in rotation; in BEAT THE LAST their last throw can still be the standing target; in BEAT THE BEST their throw still counts toward the round max.
- A player eliminated mid-round leaving only 1 alive → winner immediately.
- Undo across a life loss restores the life; undo across an elimination revives the player; target/round max and rotation order (including shuffles) roll back with the throw history.
- Removing the player whose throw is the current target does not change the target (it is just a number).
- 2-player endgame works unchanged: alternate beating each other until one runs dry.
- BEAT THE BEST starter rotation skips eliminated players; the starter index advances even if that round's starter is later eliminated.

## 8. Testing

- Unit tests (engine-style, like `ShanghaiGameEngine`): target progression, **tie = success**, fail sets new (lower) target (BEAT THE LAST), round reset + running max + fail never lowers max (BEAT THE BEST), starter rotation, random-order shuffle captured by undo, life loss, elimination + placement order, free opening throw, undo restoring lives/target/eliminations, all-miss turn (0 target can't be failed).
- Widget/regression: removed-player result screen, Norwegian-string guard.

## 9. Out of scope (v1)

- **Round events (v2 sketch):** a setup toggle that adds announced per-round modifiers ("only white beds score", "only left half", "doubles count double", …). Announced at round start, applies to every player in the round. Fits BEAT THE BEST's round structure naturally; needs event design + reveal UI. Parked so v1 stays clean — turn modifiers are WILDCARD's domain until playtesting says otherwise.
- Cross-round standing target (the "target stays until beaten with no round reset" variant — rejected for death-spiral risk; BEAT THE BEST is the round-scoped version of the idea).
- Teams, sudden-death tiebreakers, dedicated sound-pack recordings, dedicated winner video.

## 10. Delivery flow

1. This spec → **Claude design** produces DOSSEDART artboards for §4 (states 1–8 + tile + setup options). **Note:** the DOSSEDART accent palette (7 tokens) is full — palette extension must be designed before/with the 1UP handoff.
2. Artboard spec cards are fasit for the UI.
3. Implementation plan (writing-plans) → build on a `feat/one-up` branch → tablet QA (Galaxy Tab emulator).
4. Builds **after** Gotcha ships (order: Gotcha → 1UP → Golf).
