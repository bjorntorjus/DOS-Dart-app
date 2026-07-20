# Golf Game Mode — Design Spec

**Date:** 2026-07-07 · **Rules v2:** 2026-07-20
**Status:** Rules v2 approved. Artboards delivered 2026-07-20 (`DOSSEDART (9).zip`, v1-rules) — still visual fasit; behaviour deltas in `docs/design/dossedart-handoff/golf/RULES-DELTA-2026-07-20.md`. Ready for implementation planning.
**Scope:** New game mode "Golf". Third of the three new modes (Gotcha → 1UP → **Golf**).

> **Rules v2 (2026-07-20):** the v1 "last dart counts + LOCK IN" mechanic is replaced by **darts-are-strokes**: the hole ends on the first hit, and misses before the hit cost a stroke each. Rationale: at casual skill level re-throwing after a hit was almost never worth it, making LOCK IN a mandatory tap rather than a decision; the new rule rewards first-dart hits (real hole-in-one feel) and needs no extra button. The dedicated ACE overlay is also dropped (1UP QA lesson — sound/TTS carries the moment); the sudden-death overlay stays.

---

## 1. Overview

Golf plays the dartboard as a golf course: holes are the numbers 1–18 in order, and you want the **lowest** stroke total. Darts are strokes: each hole you throw until you hit the hole's number (max 3 darts) — hitting early and hitting well both pay, and a **triple on the first dart is the ACE**.

Golf is its own mode (an ATC variant was considered and rejected: turn structure, scoring direction and win condition all differ), but it reuses ATC's input components and Shanghai's round structure.

## 2. Rules (approved)

- **Course:** 18 holes = numbers 1–18 played in order. Setup option: **9 holes** (numbers 1–9), default 18. Round-based like Shanghai: every player completes hole N before anyone starts hole N+1.
- **Per hole:** up to **3 darts** at the hole's number. Only hits on that number count; everything else is a miss. **The hole ends on the first hit** (or after dart 3).
- **Stroke score = hit value + 1 per miss before the hit.** Hit values: Triple = **1** · Double = **2** · Single = **3**. All three darts miss = **6**. (Par is 3; announcer terms in §6.)
- Resulting outcome table (the full 1–6 range maps 1:1 onto golf terms):

  | Outcome | Strokes | Term |
  |---|---|---|
  | Triple, dart 1 | 1 | ACE |
  | Double dart 1 · Triple dart 2 | 2 | BIRDIE |
  | Single dart 1 · Double dart 2 · Triple dart 3 | 3 | PAR |
  | Single dart 2 · Double dart 3 | 4 | BOGEY |
  | Single dart 3 | 5 | DOUBLE BOGEY |
  | Three misses | 6 | TRIPLE BOGEY |
- **Win:** lowest total after the final hole.
- **Tie for the win → sudden death:** tied leaders play extra holes on **19, then 20, then Bull** (cycling if needed); lowest stroke on the playoff hole wins, ties among them continue. Sudden death only resolves 1st place — ties in lower placements share the placement.
- Single game, no legs/sets.

## 3. Hole flow & feedback logic

- Active player sees hole context: `HOLE 7 · PAR 3` plus a status line: before any dart `TEE OFF — THROW AT THE 7`, after a miss `LYING 1 — 2 DARTS LEFT`, after the hole ends the stroke result with its golf label (ACE/…/TRIPLE BOGEY, §6).
- No mid-hole decision: the hole ends automatically on the first hit or after dart 3. The only inputs are the S/D/T cells and MISS.
- Running leaderboard: total strokes per player, relative position (`-4` style vs. par optional for design to play with).
- All strings in English (Norwegian-string guard test applies).

## 4. Screens & states (design handoff)

Surfaces for Claude design / DOSSEDART artboards. Visual style per the arcade system; this section defines required elements/states only.

> **Designer: read `2026-07-07-new-modes-design-brief.md` first** — it defines the design/implementation split and which existing components must be reused rather than redesigned.

### 4.1 Home screen

- The **Golf** coming-soon tile (per the Gotcha spec's 3×3 grid) lights up when Golf ships. Suggested emoji ⛳ (final pick with design).

### 4.2 Setup screen

- Standard player setup (reuses `PlayerSetupScreen`) + **course selector: 9 / 18 holes** (chip pattern, default 18).
- Add/remove players mid-game supported: an added player joins at the current hole, with every earlier hole recorded as par (3) on their scorecard. A removed player's scorecard is kept for the result screen (removed-player pattern).

### 4.3 In-game cockpit

DOSSEDART cockpit pattern (TopBar · player carousel · dartboard input · ActionBar), with Golf specifics:

- **Active card:** hole number + par, darts thrown this hole, status line (`LYING 1 — 2 DARTS LEFT`), total strokes big.
- **ActionBar:** standard three actions — `UNDO · MISS · MENU` — identical to the other DOSSEDART cockpits. (Rules v1's LOCK IN button is dropped; artboards showing it are superseded.)
- **Scorecard:** hole-by-hole grid per player (the golf feel) — reachable from the cockpit (inline strip, expandable sheet, or menu; design decides).
- **States (artboard states 2 «mid-hole decision» and 4 «locked in» are superseded — see RULES-DELTA):**
  1. Hole start (no darts thrown, `TEE OFF`)
  2. Mid-hole (1–2 misses, `LYING n — m DARTS LEFT`)
  3. Hole done on a hit (stroke result + golf term; ACE via sound/TTS, no overlay)
  4. Hole done on three misses (TRIPLE BOGEY — 6 strokes, red frame)
  5. Between holes / round transition (all players done with hole N)
  6. Sudden death (playoff hole on 19/20/Bull, tied leaders only)
  7. Winner — **the post-game screen is the sole winner surface** (1UP QA lesson 2026-07-16: its dedicated winner overlay was designed, then dropped). Post-game podium content only, no in-cockpit winner overlay.

- **Moment overlays:** **sudden death start only** — tap-to-dismiss AND 1s auto-dismiss, per the 1UP QA convention. The ACE overlay from the artboards is dropped (sound/TTS carries the celebration).
- Input: reuses ATC's target-zone input (S/D/T on the hole's number + miss).

### 4.4 Post-game

- Reuses `post_game_screen`. Placements by total strokes ascending (lowest wins); sudden-death result decides 1st on ties, lower ties share placement.
- Mode-specific stat rows: total strokes, vs. par, aces, bogeys (4+), best hole, first-dart hit rate.
- Full scorecard visible in post-game / match details.
- Post-game **Undo must work** (Shanghai post-game undo protocol is the reference).

## 5. Data model & architecture

- `GameMode.golf`, label `'Golf'`, emoji ⛳ (final with design).
- `GolfConfig extends GameConfig { final int holes; }` (9 or 18; sealed-class pattern).
- `lib/screens/golf_game_screen.dart` — own screen, Shanghai template for round structure.
- Game state: per-player scorecard (stroke per hole), current hole, misses this hole. Undo stack entries cover darts and hole/round transitions so undo can cross hole boundaries (a hit both scores and ends the hole — one undo entry reverses both).

## 6. Integrations

- **GameAnnouncer / sounds:** `assets/sounds/golf/` — hole results by golf term: **ACE** (1), **BIRDIE** (2), **PAR** (3), **BOGEY** (4), **DOUBLE BOGEY** (5), **TRIPLE BOGEY** (6), plus sudden death start and winner. TTS fallback for all; dedicated recordings optional later. MemeService hooks as standard.
- **TTS (rev 2026-07-20b, playtest feedback — Golf deviates deliberately from the cross-mode staples):** NO per-dart value callout (`announceThrow` dropped — dart points are meaningless in golf and made three utterances per hole; documented override of the 1UP-lesson staple). Speak only: the **hole-result term** (`'Hole in one!'` for stroke 1 — never 'Ace' aloud; `'Triple bogey.'` for 6; else `'<term>!'`), then the **next player WITH their target** (`announceNextPlayer('<name>, hole <n>')`, in sudden death `'<name>, <19|20|bull>'`) — players care about what to throw at, so the target rides every handoff. `playoffContinued` says only `'Still tied!'` (target comes via the next-player line). Undo speaks **'Back'**; winner via `announceWinner`. Misses are TTS-silent (the miss sound effect covers them). All gated by the standard TTS category settings.
- **Stats (StatsRecorder):** games, wins, aces, avg strokes per hole (comparable across 9/18-hole games), best round (per course length), first-dart hit rate. H2H + Elo recorded. Scorecard/turn history for match-details drill-down.
- **Removed-player handling:** removed-player-wins fix pattern from day one + regression test.
- **VideoService:** generic winner video.

## 7. Edge cases

- A hit always ends the hole — there is no way to throw again for a better score (no gamble in rules v2).
- Three misses = 6 strokes (TRIPLE BOGEY): strictly worse than the worst hit (single on dart 3 = 5), so the last dart always matters.
- Sudden death cycles 19 → 20 → Bull → 19 → … until one leader is lowest. Playoff strokes do not change the recorded round total; they only decide 1st.
- Bull playoff hole: no triple exists — outer bull = Single (3), inner bull = Double (2); best possible is a first-dart BIRDIE. Fine, since playoff strokes are only compared among the tied leaders.
- Undo across a hole/round transition restores the previous hole; undoing a hit reopens the hole with prior misses intact.
- Inner vs. outer single both count as Single = 3 in v1 (the input distinguishes them, scoring does not).
- 2-player and 5+-player games work unchanged (round-based, no interaction between players' holes).

## 8. Testing

- Unit tests (engine-style): the full outcome table (all hit-value × dart-number combinations + three misses = 6), hole ends on first hit, hole auto-end on dart 3, 9 vs. 18 holes, tie detection + sudden-death resolution (incl. Bull hit values), undo across hits and hole transitions, placement order.
- Widget/regression: removed-player result screen, Norwegian-string guard.

## 9. Out of scope (v1)

- Inner/outer single distinction in scoring, handicaps, match-play scoring (hole-by-hole points), team play, dedicated sound-pack recordings, dedicated winner video.

## 10. Delivery flow

1. ~~This spec → **Claude design** produces DOSSEDART artboards~~ — **done 2026-07-20** (`docs/design/dossedart-handoff/golf/`, built against rules v1).
2. Artboard spec cards are fasit for the **visuals**; this spec (rules v2) is fasit for **behaviour**. Deltas vs. the artboards are catalogued in `RULES-DELTA-2026-07-20.md` in the handoff folder — no new design round needed (all deltas are removals or text-level tweaks of existing components).
3. Implementation plan (writing-plans) → build on a `feat/golf` branch → tablet QA (Galaxy Tab emulator).
4. Builds **last** of the three (order: Gotcha → 1UP → Golf).
