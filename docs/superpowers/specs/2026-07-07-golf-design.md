# Golf Game Mode — Design Spec

**Date:** 2026-07-07
**Status:** Approved rules; awaiting visual design (DOSSEDART artboards) before implementation
**Scope:** New game mode "Golf". Third of the three new modes (Gotcha → 1UP → **Golf**).

---

## 1. Overview

Golf plays the dartboard as a golf course: holes are the numbers 1–18 in order, and you want the **lowest** stroke total. Each hole is a press-your-luck moment — the **last dart thrown counts**, so after a decent hit you either **LOCK IN** your strokes or risk another dart for better.

Golf is its own mode (an ATC variant was considered and rejected: turn structure, scoring direction and win condition all differ), but it reuses ATC's input components and Shanghai's round structure.

## 2. Rules (approved)

- **Course:** 18 holes = numbers 1–18 played in order. Setup option: **9 holes** (numbers 1–9), default 18. Round-based like Shanghai: every player completes hole N before anyone starts hole N+1.
- **Per hole:** up to **3 darts** at the hole's number. Only hits on that number count; everything else is a miss.
- **Stroke values:** Triple = **1** · Double = **2** · Single = **3** · Miss = **5**. (Par is 3; announcer terms in §6.)
- **Last dart counts:** your stroke for the hole is whatever the **last thrown dart** scored — including a miss. After dart 1 or 2 you may **LOCK IN** to end the hole and keep your current stroke; after dart 3 the hole ends automatically. You must throw at least one dart per hole (no locking in at 0 darts).
- **Win:** lowest total after the final hole.
- **Tie for the win → sudden death:** tied leaders play extra holes on **19, then 20, then Bull** (cycling if needed); lowest stroke on the playoff hole wins, ties among them continue. Sudden death only resolves 1st place — ties in lower placements share the placement.
- Single game, no legs/sets.

## 3. Hole flow & feedback logic

- Active player sees hole context: `HOLE 7 · PAR 3` plus current lie after each dart: `LYING 3 — LOCK IN OR RISK?`.
- **LOCK IN** is enabled after dart 1 and 2, disabled before the first dart, irrelevant after dart 3 (hole auto-completes).
- Decision feedback: after locking in or finishing, show the stroke result with its golf label (ACE/BIRDIE/PAR/BOGEY, §6).
- Running leaderboard: total strokes per player, relative position (`-4` style vs. par optional for design to play with).
- All strings in English (Norwegian-string guard test applies).

## 4. Screens & states (design handoff)

Surfaces for Claude design / DOSSEDART artboards. Visual style per the arcade system; this section defines required elements/states only.

### 4.1 Home screen

- The **Golf** coming-soon tile (per the Gotcha spec's 3×3 grid) lights up when Golf ships. Suggested emoji ⛳ (final pick with design).

### 4.2 Setup screen

- Standard player setup (reuses `PlayerSetupScreen`) + **course selector: 9 / 18 holes** (chip pattern, default 18).
- Add/remove players mid-game supported: an added player joins at the current hole, with every earlier hole recorded as par (3) on their scorecard. A removed player's scorecard is kept for the result screen (removed-player pattern).

### 4.3 In-game cockpit

DOSSEDART cockpit pattern (TopBar · player carousel · dartboard input · ActionBar), with Golf specifics:

- **Active card:** hole number + par, darts thrown this hole, current lie (`LYING 2`), total strokes big.
- **ActionBar:** the **LOCK IN** button — new interaction, does not exist in other modes. Placed alongside UNDO/MISS/MENU; design decides arrangement.
- **Scorecard:** hole-by-hole grid per player (the golf feel) — reachable from the cockpit (inline strip, expandable sheet, or menu; design decides).
- **States to design:**
  1. Hole start (no darts thrown, LOCK IN disabled)
  2. Mid-hole decision (lie shown, LOCK IN enabled — the signature moment)
  3. ACE (triple hit — stroke 1, celebration)
  4. Locked in (stroke kept, hole done)
  5. Bogey (hole ends on a miss — stroke 5)
  6. Between holes / round transition (all players done with hole N)
  7. Sudden death (playoff hole on 19/20/Bull, tied leaders only)
  8. Winner
- Input: reuses ATC's target-zone input (S/D/T on the hole's number + miss).

### 4.4 Post-game

- Reuses `post_game_screen`. Placements by total strokes ascending (lowest wins); sudden-death result decides 1st on ties, lower ties share placement.
- Mode-specific stat rows: total strokes, vs. par, aces, bogeys, lock-in count, best hole.
- Full scorecard visible in post-game / match details.
- Post-game **Undo must work** (Shanghai post-game undo protocol is the reference).

## 5. Data model & architecture

- `GameMode.golf`, label `'Golf'`, emoji ⛳ (final with design).
- `GolfConfig extends GameConfig { final int holes; }` (9 or 18; sealed-class pattern).
- `lib/screens/golf_game_screen.dart` — own screen, Shanghai template for round structure.
- Game state: per-player scorecard (stroke per hole), current hole, darts thrown in hole, locked-in flag. Undo stack entries cover darts, lock-ins, and hole/round transitions so undo can cross hole boundaries.

## 6. Integrations

- **GameAnnouncer / sounds:** `assets/sounds/golf/` — events with golf terminology: **ACE** (triple, stroke 1), **BIRDIE** (double, stroke 2), **PAR** (single, stroke 3), **BOGEY** (miss, stroke 5), locked in, sudden death start, winner. TTS fallback for all; dedicated recordings optional later. MemeService hooks as standard.
- **Stats (StatsRecorder):** games, wins, aces, avg strokes per hole (comparable across 9/18-hole games), best round (per course length), lock-in rate. H2H + Elo recorded. Scorecard/turn history for match-details drill-down.
- **Removed-player handling:** removed-player-wins fix pattern from day one + regression test.
- **VideoService:** generic winner video.

## 7. Edge cases

- Lock-in before any dart is impossible (button disabled).
- Dart 3 always ends the hole; its result counts even after two good darts (risking dart 3 after a double is allowed — that's the gamble).
- Miss on the last thrown dart = stroke 5 regardless of earlier hits that turn.
- Sudden death cycles 19 → 20 → Bull → 19 → … until one leader is lowest. Playoff strokes do not change the recorded round total; they only decide 1st.
- Undo across a lock-in restores the mid-hole state; undo across a hole/round transition restores the previous hole.
- Inner vs. outer single both count as Single = 3 in v1 (the input distinguishes them, scoring does not).
- 2-player and 5+-player games work unchanged (round-based, no interaction between players' holes).

## 8. Testing

- Unit tests (engine-style): stroke values, last-dart-counts (incl. miss after hit), lock-in legality, hole auto-end on dart 3, 9 vs. 18 holes, tie detection + sudden-death resolution, undo across lock-in and hole transitions, placement order.
- Widget/regression: removed-player result screen, Norwegian-string guard.

## 9. Out of scope (v1)

- Inner/outer single distinction in scoring, handicaps, match-play scoring (hole-by-hole points), team play, dedicated sound-pack recordings, dedicated winner video.

## 10. Delivery flow

1. This spec → **Claude design** produces DOSSEDART artboards for §4 (states 1–8 + tile + scorecard).
2. Artboard spec cards are fasit for the UI.
3. Implementation plan (writing-plans) → build on a `feat/golf` branch → tablet QA (Galaxy Tab emulator).
4. Builds **last** of the three (order: Gotcha → 1UP → Golf).
