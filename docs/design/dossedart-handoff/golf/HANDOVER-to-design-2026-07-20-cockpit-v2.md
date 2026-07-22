# Golf cockpit v2 — tablet-QA feedback round (2026-07-20)

**To:** Claude design (DOSSEDART track)
**From:** implementation, after the first Galaxy Tab QA pass of the shipped v1 cockpit (build 1.16.0+40)
**Scope:** ONE screen — the Golf in-game cockpit layout. Everything else from the 2026-07-20 handoff
(home tile, setup, post-game, score-sheet modal, sudden-death flow) works and is approved as built.

---

## QA findings (verbatim from the tablet session)

1. **Poor use of space overall.** Golf's input is only three cells (S/D/T) — unlike the X01/ATC
   cockpits there is no dartboard eating the middle of the screen, yet the v1 layout distributes
   space as if there were. There is a LOT of empty room to work with.
2. **Hard to see what to throw at.** The current hole/target number only reads clearly inside the
   input cells themselves (`S7 / D7 / T7`). The hole context in the active-card header is too small
   to function as the "aim here" signal from throwing distance.
3. **Hard to see what opponents have.** The v1 implementation translated the artboard's standalone
   leaderboard block into a compact opponents strip inside the active card (sibling precedent from
   1UP, where vertical space was scarce). On the tablet this strip is too small to read. **The
   original artboard's standalone leaderboard was the right call for Golf — implementation concedes
   this one.** Free rein to bring it back, bigger.
4. **The 1–18 scorecard strip at the bottom is near-impossible to read.** Cell size and term-colour
   fills don't survive real distance/glare. Rethink: bigger cells, fewer visible holes (window around
   the current hole?), or drop the always-on strip and lean on the expandable sheet — your call.

## What this round is — and is not

- **Pure cockpit-layout round.** Rules v2 (`golf-design.md` §2 + `RULES-DELTA-2026-07-20.md`) are
  implemented, reviewed and test-pinned. No rule/state/flow changes will be accepted in this round.
- The **states** remain exactly the shipped set: tee-off, mid-hole (`LYING n — m DARTS LEFT`),
  hole-result display (1s window, finishing player shown), between holes, sudden death (overlay on
  start; PLAYOFF top-bar; Bull = two cells), winner = post-game only.
- **Component APIs may change freely** — the Flutter widgets are ours to rewrite against new
  artboards (`DossedartGolfActiveCard`, `GolfInputCells`, `GolfScorecardStrip` are golf-only and
  carry no cross-mode dependents). The score-sheet modal (`GFScoreSheet`) is approved as-is.

## Fixed constraints (unchanged from the original brief)

- 820 × 1180 portrait tablet frame; DOSSEDART chrome reused verbatim: CrtFrame + scanlines, TopBar
  (`◀ EXIT · ⛳ GOLF · HOLE n/18` / `PLAYOFF`), standard 3-action ActionBar (`UNDO · MISS · MENU`).
- Tokens only (Golf brand = existing `green`; term colours: ACE cyan · BIRDIE green · PAR phosphor ·
  BOGEY orange · DBL/TRPL BOGEY red). `Press Start 2P` / `VT323`. No border-radius.
- No LOCK IN, no ACE overlay, no winner overlay (RULES-DELTA + 1UP QA lessons stand).
- Terminology locked: HOLE, PAR, LYING n, ACE…TRIPLE BOGEY, SUDDEN DEATH/PLAYOFF, TEE OFF.
- All UI strings English.

## Direction hints (suggestions, not requirements)

The freed space budget is roughly the whole middle band of the frame. Candidates worth exploring:

- A **hero target block**: hole number huge (readable from the oche) + `PAR 3` + the LYING line —
  "what do I throw at" should be answerable at a glance from 2.4 m.
- A **full-width standalone leaderboard** (artboard v1 shape, scaled up): every player's total +
  vs-par + done-this-hole state readable from distance; active player highlighted.
- The **input cells can afford to be much taller** — they are also the only tap targets.
- Scorecard presence: a windowed strip (e.g. previous/current/next 5 holes, larger cells) or
  sheet-only with a prominent `SCORECARD` affordance.

## Deliverable

Same bundle format as before: artboards for the cockpit states (1–7 above; state 8/winner = post-game
is unchanged and needs no artboard), spec cards as fasit, JSX prototype optional. The spec cards in
the returned bundle will be treated as visual fasit; `golf-design.md` rules v2 stays behaviour fasit.
