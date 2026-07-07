# WILDCARD Game Mode — Design Spec

**Date:** 2026-07-07
**Status:** Approved rules; awaiting visual design (DOSSEDART artboards) before implementation
**Scope:** New game mode "WILDCARD" — chaos mode. Fourth new mode, built last (Gotcha → 1UP → Golf → **WILDCARD**).

---

## 1. Overview

WILDCARD is a points race sabotaged by chaos. A visible **chaos meter** (0–10) rises and falls with how everyone throws; the higher it climbs, the more often — and the wilder — random events strike: personal throwing restrictions announced before your turn, and hidden **joker** numbers that detonate instant events when hit. Bull gives players direct control over the meter, making chaos itself a strategic resource: leaders want it low, trailers want it high.

At chaos level 0 nothing happens — it's a plain points race. That is both the "mild" setting for new players and the deterministic baseline for testing.

## 2. Base game (approved)

- **Points race over a fixed number of rounds**, selectable in setup: **5 / 10 / 15**, default 10. Highest total after the last round wins.
- A turn is 3 darts, entered after throwing (standard manual entry — physical habits unchanged).
- **Score floor is 0**: steals and curses can never take a player negative.
- Tie after the last round: highest single turn in the game wins the tiebreak; still tied → shared placement. (Kept simple — chaos already decides most games.)
- Single game, no legs/sets.

## 3. Chaos meter

- Range **0–10**, always **visible to all players** in the cockpit (big and dramatic — it is the mode's centerpiece).
- Setup: starting level — **Mild (2) / Spicy (5) / Total chaos (8)**, default Spicy.
- **Movement:**
  - Triple hit: **+1**
  - True miss (MISS button / off the board): **−1**. A dart on a *dimmed* segment scores 0 but is **not** a meter-miss (no double punishment).
  - Joker hit: **+2**
  - **Bull control:** single bull = 25 points **+ thrower chooses ±1**; double bull = 50 points **+ thrower chooses ±3**. Up/down dialog appears on entry. This is the strategic lever — leaders aim bull to calm the game, trailers to ignite it.
- The level drives **event frequency** and **severity pool** (§6). Starting tuning values (adjust after playtesting):

| Chaos level | Turn-modifier chance | Jokers on board | Severity pool |
|---|---|---|---|
| 0 | 0% | 0 | — |
| 1–2 | 10% | 1 | mild |
| 3–4 | 25% | 1 | mild |
| 5–6 | 45% | 1 | mild + medium |
| 7–8 | 70% | 1–2 | mild + medium + wild |
| 9–10 | 100% | 2 | all, wild weighted up |

## 4. Turn-modifiers (personal, announced before the throw)

A modifier applies to **one thrower, one turn**, and is announced (TTS + overlay) **before** they throw — everyone hears it, one player suffers it. Never mid-round rule changes for players who already threw (fairness). Rolled at turn start per the frequency table.

| Modifier | Effect | Severity |
|---|---|---|
| ONLY EVENS / ONLY ODDS | Only matching numbers score | mild |
| ONLY BLACK / ONLY WHITE | Only matching segments score | mild |
| DIVIDE BY THREE | Only numbers divisible by 3 score | mild |
| UPPER / LOWER / LEFT / RIGHT HALF | Only that half of the board scores | mild |
| EVERYTHING ×2 | Turn total doubled | mild |
| GOLDEN DART | Last dart counts ×3 | mild |
| HOLY TRINITY | Exactly 26 this turn → +100 bonus (20-5-1, the classic) | mild |
| BULL'S FORTUNE | Bull worth 100 this turn | medium |
| BULL'S CURSE | Bull drains 100 this turn | medium |
| DOUBLE TROUBLE | Doubles score triple, triples score **zero** | medium |
| THE WINDOW | See below | medium |

**THE WINDOW (dynamic):** bounds are randomized on every activation — high (e.g. 80–120), mid (e.g. 40–60), or absurdly low (e.g. 3–9; the theoretical floor with 3 hits is 3 × S1). Higher chaos skews toward narrower/weirder windows. **All 3 darts must hit the board** — a true miss voids the turn (prevents cheesing a low window by deliberately missing). Land the total inside the window → score a flat **100 (WINDOW PRIZE)**; outside → 0. Flat prize keeps every window worth the same — the low ones are just harder and funnier.

## 5. Jokers & instant events

- Each round, **1–2 hidden joker numbers** (from 1–20; count per chaos table) are secretly assigned. Players never see them.
- Hitting a joker (at entry): the dart scores per current rules (0 if dimmed — **jokers trigger on dimmed segments too**), the joker is revealed with drama, meter +2, and a random **instant event** fires from the active severity pool. The joker number then re-rolls.

| Event | Effect | Severity |
|---|---|---|
| CHAOS SURGE | Meter +3 immediately | mild |
| SCORE SWAP | Swap totals with a random player | medium |
| ROBIN HOOD | Steal 50 from the leader | medium |
| GIFT | The rest of this turn's points go to the player in last place | medium |
| FREEZE | The current leader scores 0 next round | medium |
| CURSED NUMBER | A new hidden number scores **negative** (−segment value) until someone hits it or the game ends | medium |
| DOUBLE JEOPARDY | Two jokers on the board next round | wild |
| CUT! | The round ends immediately — players who haven't thrown lose their turn | wild |
| REWIND | The entire round's scores are wiped; the round restarts from the first player | wild |

## 6. Input: dartboard with live dimming

- Reuses the **DOSSEDART dartboard** from the X01 cockpit.
- During a restriction modifier, non-scoring segments are **dimmed live** (ONLY EVENS → odd segments dark; UPPER HALF → lower half dark). The board doubles as the visual rulebook for the active modifier.
- **Every segment is always tappable** — darts land where they land and must be registerable. A dimmed hit scores 0 points but is fully "alive": jokers and cursed numbers trigger, bull dialog appears, and it is not a meter-miss.
- 4×5 grid input variant: **deferred to v1.1** (must replicate the dim states; dartboard is where the modifier visualization shines).

## 7. Screens & states (design handoff)

Surfaces for Claude design / DOSSEDART artboards. Arcade style per the existing system; required elements/states only.

### 7.1 Home screen

- WILDCARD takes the **ninth cell** (the generic "coming soon" cell), completing the 3×3 grid. Shown as a dimmed coming-soon tile until it ships. Suggested emoji 🃏 (final with design). A future tenth mode grows the grid to a fourth row with a new coming-soon cell.

### 7.2 Setup screen

- Standard player setup + **rounds selector (5/10/15)** + **starting chaos (Mild/Spicy/Total chaos)**.
- Add/remove mid-game supported; an added player joins with 0 points at the current round.

### 7.3 In-game cockpit

DOSSEDART cockpit pattern, with WILDCARD specifics:

- **Chaos meter** — persistent, prominent, animated as it moves (the centerpiece).
- **Active card:** turn total + running game total; active modifier badge when one applies.
- **States to design:**
  1. Default (no modifier, meter idle)
  2. Modifier announcement (pre-turn overlay/interstitial — the "oh no" moment)
  3. Active restriction (modifier badge + dimmed board)
  4. THE WINDOW (bounds displayed, e.g. `WINDOW: 3–9 · ALL DARTS MUST SCORE`)
  5. Bull choice dialog (chaos up/down, ±1 / ±3)
  6. Joker reveal (hidden number detonates — signature moment)
  7. Instant event resolution (swap/steal/freeze feedback)
  8. CUT! (round guillotined)
  9. REWIND (round rewinding — deserves a real animation)
  10. Meter at max (9–10: permanent danger styling)
  11. Winner
- Input: dartboard with dim states (§6).

### 7.4 Post-game

- Reuses `post_game_screen`. Placements by final total (tiebreak §2).
- Mode-specific stat rows: jokers hit, window prizes, chaos peak, points stolen/gifted, highest turn.
- Post-game **Undo must work** (Shanghai post-game undo protocol is the reference).

## 8. Data model & architecture

- `GameMode.wildcard`, label `'WILDCARD'`, emoji 🃏 (final with design).
- `WildcardConfig extends GameConfig { final int rounds; final int startingChaos; }` (sealed-class pattern).
- `lib/screens/wildcard_game_screen.dart` — thin UI over a **pure game engine**:
- **`WildcardGameEngine`** (the `ShanghaiGameEngine` pattern — this mode is where engine extraction pays off most):
  - All rules/meter/event logic UI-free; the screen renders engine state.
  - **Injected seeded RNG** — never raw `Random` in the engine (F18 lesson). Every test is deterministic: "with seed X, joker lands on 14 in round 3."
  - **Data-driven event definitions**: each modifier/event is a definition with eligibility (severity tier, chaos gate) + effect hook — unit-testable in isolation.
  - Event-sourced history: meter changes, swaps, CUT!, REWIND are entries on the undo stack. Undo across any event (including REWIND itself) restores the prior state.
- Dev-only override to force a specific event, for manual QA on the tablet.

## 9. Integrations

- **GameAnnouncer / TTS:** the mode's backbone — modifier announcements pre-turn, joker reveals, WINDOW PRIZE, CUT!/REWIND drama. `assets/sounds/wildcard/`; TTS fallback for everything, dedicated recordings later. MemeService hooks as standard.
- **Stats (StatsRecorder):** games, wins, jokers hit, window prizes, chaos peak, highest turn, points stolen. H2H recorded. **No Elo in v1** — flagged decision: outcomes are deliberately luck-heavy, and rating swings from coin-flip events would pollute ratings earned in the skill modes. Revisit if it feels wrong.
- **Removed-player handling:** removed-player-wins fix pattern + regression test. Events referencing "the leader"/"last place" resolve against players still in the game.
- **VideoService:** generic winner video.

## 10. Edge cases

- Modifier + joker stack: a dimmed dart can still trigger a joker (scores 0, event fires).
- SCORE SWAP/ROBIN HOOD with score floor: steals cap at what the victim has (floor 0).
- FREEZE on a player who gets removed: effect dissolves.
- CUT! as the last event of the final round: game ends, totals stand.
- REWIND on round 1: round restarts from zero scores for everyone.
- Two jokers cannot share a number; joker re-roll excludes the number just hit.
- Bull dialog during BULL'S CURSE: the −100 applies AND the chaos choice still happens (bull control is unconditional).
- Meter clamps at 0 and 10; changes beyond the clamp are discarded.
- Undo re-hides revealed jokers and restores the meter, swapped scores, and rewound rounds.

## 11. Testing

- Engine unit tests with seeded RNG: meter arithmetic + clamping, per-modifier scoring (one test per definition), window generation/validation (incl. all-darts-must-hit voiding), joker assignment/reveal/re-roll, each instant event (incl. CUT! turn-skipping and REWIND state restore), undo across every event type, chaos-0 baseline (= plain points race, zero events over any seed).
- Widget/regression: removed-player result screen, Norwegian-string guard, bull-choice dialog flow.
- Tuning values in §3 are starting points — expect a playtest round before locking them.

## 12. Out of scope (v1)

- 4×5 grid input (v1.1 candidate), ROUND CHAOS variants (modifiers hitting all players simultaneously), Elo, custom event packs, dedicated sound recordings, dedicated winner video.

## 13. Delivery flow

1. This spec → **Claude design** produces DOSSEDART artboards for §7 (11 states + tile + meter).
2. Artboard spec cards are fasit for the UI.
3. Implementation plan (writing-plans) → build on a `feat/wildcard` branch → tablet QA (Galaxy Tab emulator).
4. Builds **last** of the four (order: Gotcha → 1UP → Golf → WILDCARD) — it is the most complex and benefits from the engine/test patterns maturing first.
