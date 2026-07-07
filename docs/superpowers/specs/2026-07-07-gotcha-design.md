# Gotcha Game Mode — Design Spec

**Date:** 2026-07-07
**Status:** Approved rules; awaiting visual design (DOSSEDART artboards) before implementation
**Scope:** New game mode "Gotcha" + home screen 3-column grid with coming-soon tiles for Legs and Golf

---

## 1. Overview

Gotcha is a race: every player starts at **0** and climbs to an exact **target score**. Landing your running total exactly on an opponent's total **kills** them — their score resets to 0. First player to hit the target exactly wins.

This is the first of three new modes (Gotcha → 1UP → Golf), built one at a time. Each follows the Shanghai template (own screen + config subclass, full announcer/stats/undo integration).

## 2. Rules (approved)

- All players start at 0. Target score is selectable in setup: **101 / 201 / 301 / 501**, default **301** (same button pattern as X01's 301/501/701).
- The target must be hit **exactly**. Overshooting is a **bust**: the player's score reverts to what it was at the start of the turn and the turn ends (identical semantics to X01 bust).
- **No double-out.** Any dart can finish (straight-out). No double-out toggle in v1 (YAGNI).
- **Kill (per dart):** after each individual dart, if the thrower's new total exactly equals an opponent's total, that opponent is reset to 0. If several opponents share that score, **all of them** are reset.
  - Players at 0 cannot be killed (resetting 0 to 0 is a no-op; no kill event fires).
  - Kills do not affect the thrower's own score.
  - **Kills are final even if the thrower busts later in the same turn.** Bust reverts only the thrower's score; per-dart kills already resolved stand. (Rationale: kills resolve immediately per dart; reverting them on bust would be confusing mid-drama.)
- **Win:** first player whose total equals the target exactly. Single game in v1 — no legs/sets (consistent with the other non-X01 modes).

## 3. Tips logic

Two tip types can be **visible at the same time**, in one strip area. Win tip renders first (winning beats killing).

### 3.1 Checkout tip toward the target (up to 3 darts)

- Shows an X01-style dart sequence (e.g. `T20 › T19 › D12`) when `remaining = target − score` is finishable in ≤ 3 darts.
- The existing checkout table is double-out and cannot be reused directly. New utility: **straight-out checkout** (`lib/utils/straight_out_checkout.dart` or `lib/data/`):
  - Input: remaining (1–180), darts left in turn (1–3). Output: list of dart labels, or null if not finishable.
  - Prefer fewest darts; for multi-dart routes prefer conventional big targets (T20/T19/Bull) then a clean finisher.
  - Some values are unreachable even ≤ 180 (e.g. 179, 178, 176, 175, 173, 172, 169, 166, 163) → return null, show nothing.
- Recomputed after every dart, respecting darts remaining in the current turn.

### 3.2 Kill tips (1 dart only)

- For each living opponent: `diff = opponentScore − myScore`.
- Show a kill tip **only when diff is a valid single-dart score**: 1–20 (singles), even 2–40 (doubles), multiples of 3 up to 60 (triples), 25, 50. Opponents behind you (diff ≤ 0) or further than one dart away are never shown — anything beyond one dart is noise, not a playable plan.
- Notation: simplest form. diff ≤ 20 → single (`S13`), diff 40 → `D20`, diff 57 → `T19`, diff 25 → `25`, diff 50 → `BULL`. When multiple notations exist (e.g. 18 = S18/D9/T6), show the single.
- Format: `💀 T19 → KARI · D5 → PER` (dart → player name). Multiple kill tips joined in one row; with realistic play rarely more than 1–2 at once.
- Recomputed after every dart — multi-dart kills emerge naturally (dart 1 brings you within range, tip appears for dart 2).

## 4. Screens & states (design handoff)

These are the surfaces Claude design needs to produce DOSSEDART artboards for. Visual style follows the existing DOSSEDART arcade system (spec cards in HTML are fasit); this section defines required elements/states only.

### 4.1 Home screen (modified)

- Mode grid goes from 2 to **3 columns**. Layout: X01 row (301/501/701) unchanged, then 3×3 grid:
  - Row 1: Cricket · Around the Clock · Killer
  - Row 2: Splitscore · Shanghai · **Gotcha** (active)
  - Row 3: **1UP** (coming soon; see 2026-07-07-one-up-design.md) · **Golf** (coming soon) · generic "Coming soon" cell
- Coming-soon mode tiles: same tile chrome but dimmed/disabled (not tappable), visually matching the existing coming-soon cell. They light up as each mode ships.
- `GameMode` enum gains `gotcha` now; Legs/Golf tiles are hardcoded placeholders until their modes exist (no dead enum values).

### 4.2 Setup screen

- Standard player setup (reuses `PlayerSetupScreen`) with a Gotcha target-score selector: **101 / 201 / 301 / 501**, default 301. Same chip/button pattern as X01 start-score.
- Add/remove players mid-game must be supported like all other modes.

### 4.3 In-game cockpit

DOSSEDART cockpit pattern (TopBar · player carousel · dartboard input · ActionBar), with Gotcha specifics:

- **Score counts UP**: big number is current total; secondary line shows `TO GO: <remaining>` toward the target.
- **Tip strip** (below/inside active player card, where X01 shows checkout tips): win tip (3-dart straight-out route) and kill tips (`💀 <dart> → <name>`) — both may show simultaneously, win tip first.
- **Peek/opponent cards**: show each opponent's total. A skull/danger marker on opponents currently one dart from being killed by the active player (mirrors the kill tips).
- **States to design:**
  1. Default (no tips)
  2. Win tip visible
  3. Kill tip(s) visible
  4. Win + kill tips together
  5. Bust (X01-style bust feedback)
  6. **Kill event** — the signature moment: overlay/flash on the killed player ("GOTCHA!"), their score dropping to 0
  7. Winner
- Input: reuses X01 dartboard/score input.
- Undo button: standard.

### 4.4 Post-game

- Reuses `post_game_screen` with Gotcha result data. Podium/placements by final score (winner first; others ranked by score at game end).
- Mode-specific stat rows: kills made, times killed, busts, highest turn, darts thrown.
- Post-game **Undo must work** (Shanghai post-game undo protocol is the reference implementation).

## 5. Data model & architecture

- `GameMode.gotcha` + label `'Gotcha'` + emoji (suggest 💀 or 🎯-variant; final pick with design).
- `GotchaConfig extends GameConfig { final int targetScore; }` (sealed-class pattern).
- `lib/screens/gotcha_game_screen.dart` — own screen, modeled on the Shanghai/X01 screens.
- Turn/undo model: undo stack entries must capture **kill side effects** so undoing a dart restores killed players' previous scores (undo is score correction, not game mechanics — it reverts everything, unlike bust).
- Straight-out checkout utility as in §3.1, unit-tested.

## 6. Integrations

- **GameAnnouncer / sounds:** new kill event — `assets/sounds/gotcha/kill/` with TTS fallback ("Gotcha!"). Bust/score/winner reuse existing X01/general sounds. MemeService hooks as standard (69, high scores, sequences).
- **Stats (StatsRecorder):** per-mode Gotcha stats — games, wins, kills made, times killed, busts, highest turn, avg turn. H2H and Elo recorded (competitive mode). Turn history recorded so match details (KAMPDETALJER) drill-down works.
- **Removed-player handling:** apply the removed-player-wins fix pattern from day one (result screen must handle players removed mid-game; regression test like the other 5 modes).
- **i18n:** all UI strings in English; must pass the Norwegian-string guard test (F21).
- **VideoService:** generic winner video (like Shanghai); no dedicated asset.

## 7. Edge cases

- Kill checks run only against **living, in-game** opponents (removed players excluded).
- Two+ opponents on the same score, one dart lands on it → all reset, one kill event (announce all names or "double kill").
- A player killed to 0 keeps their turn order and continues from 0.
- Bust dart itself cannot kill: if the dart takes the thrower past the target it is a bust — but a dart that lands exactly on an opponent's score is by definition ≤ target only if opponent ≤ target, which is always true; so a bust dart (total > target) can never equal an opponent's total. No conflict.
- Undo across a kill restores the killed player's score; undo across a bust restores the pre-bust state per existing X01 semantics.
- Tips recompute on undo as well.

## 8. Testing

- Unit tests: straight-out checkout utility (incl. unreachable values), kill detection (single, multi-player, at-0 no-op), bust-preserves-kills, undo-restores-kills.
- Widget/regression tests: removed-player result screen (pattern from the 5 existing modes), Norwegian-string guard coverage.
- Integration: follow existing `integration_test` scenarios pattern if practical.

## 9. Out of scope (v1)

- Double-out toggle, legs/sets, dedicated kill sound-pack recordings (TTS fallback ok), dedicated winner video, Legs & Golf modes (own specs later).

## 10. Delivery flow

1. This spec → **Claude design** produces DOSSEDART artboards for §4 (states 1–7 + home grid).
2. Artboard spec cards become fasit for the UI.
3. Implementation plan (writing-plans) → build on a `feat/gotcha` branch → tablet QA (Galaxy Tab emulator).
