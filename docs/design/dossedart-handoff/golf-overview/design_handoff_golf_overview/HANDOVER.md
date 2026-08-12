# HANDOVER — Golf overview (mode round 4) · 2026-07-22

**From:** Claude design (DOSSEDART track)
**Responds to:** `HANDOVER-to-design-2026-07-22-golf-overview-brief.md` + grammar sheet (header/accents/always-rendered only — free-rein round)
**Artboard:** `DOSSEDART golf overview round.html` (canvas: v2 vs v3 side-by-side ×3 states, 6 stress states, fasit)
**Baseline:** cockpit v2 (tablet-QA-passed 2026-07-20). This is an **evolution, not a rethink** — the v2 skeleton (hero · leaderboard · strip · console) stands; deltas below are KISS-refinements from two user iterations.

## Decision

**v3 (KISS)** — user-approved after two iterations. North star from v2 kept: only the
console glows and registers; everything else is a flat readout. New on top: **all
registration now lives in the console** (S/D/T + ✗ MISS), and the hero is one line —
name + the hole number.

## Fasit

```
ZONE BUDGET @ 820×1180 (rule 2 — nothing grows in-game):
TOPBAR 64 · [14] · HERO 244 · [12] · LEADERBOARD 34+56×min(n,5) ·
[12] · STRIP/CHAIN 96 · [flex] · CONSOLE 220 · ACTIONBAR band 100
```

- **D1 · Hero (244px):** rule-4 header (photo avatar 56, name curve 18/15/12/10, accent
  pips + `DART n/3`) with the **hole number 120px GREEN beside the name** (label
  `HOLE · PAR 3`; `PLAYOFF` in playoff — no PAR there). Name truncates (minWidth 0),
  number is flexShrink 0 — a long name can never push the hole. TOTAL removed from the
  hero; the leaderboard owns totals.
- **D2 · Dart chips (P2 misses stack):** three always-rendered 36px chips in the status
  plate show per-dart history (`S7`/`D7`/`✗` in term colour, `·` = unthrown). A wash
  reads as ✗ ✗ ✗. No ladder, no prose.
- **D3 · Status plate (56px, always rendered):** tee-off (neutral, `LAST DART COUNTS`) ·
  `LYING n` + term + `m DARTS LEFT` (mid) · filled term-coloured plate with `NEXT ▸` +
  1s progress bar (hole result). Hero frame = player accent, **never flips** — identity
  and state don't share a channel.
- **D4 · No auto-spacer; chain in the strip zone:** playoff does NOT hide the strip —
  the same 96px zone shows the sudden-death chain `19 → 20 → BULL` (`✓ TIED` / `▶ NOW`).
- **D5 · Leaderboard (v2 density):** 56px rows, no stretched air. Max 5 visible rows
  (314px), then vertical scroll + `▼ n PLAYERS · SCROLL` header hint (6th row visibly
  cut as affordance). Player count is game-constant, so height is game-constant.
  No THROWING column (the hero says who throws; accent bar + tint mark the row).
  Score is the hero: TOTAL 24px + coloured ±par 15px (`10 +1` / `8 −1`).
  Columns: rank · accent dot · name (mid-trunc >16) · this-hole chip · score.
- **D6 · YOUR CARD:** all 18 holes, 72px cells, horizontal swipe in the 96px zone;
  auto-centers the current hole (clamped at the ends). `‹ SWIPE ›` hint; `SCORECARD ▸`
  (full sheet) kept.
- **Cut (KISS):** hero TOTAL, THROWING column, `REGISTERS YOUR STROKE`, the console
  miss-caption, H-prefix on chips.

## PROPOSALS (need sign-off, standard protocol)

1. **✗ MISS lifted into the console** as the fourth cell (red, `MISS · 5 STROKES`;
   playoff `NO SCORE`; two-target cells + ✗ = three cells on BULL). Rationale: MISS is
   the second-most-used action; all registration on ONE glowing surface. The ActionBar
   is approved chrome and untouched in the mockup — implementation decides whether its
   ✗ MISS goes or stays as a duplicate.
2. **Hole number 120px** (was ~130 in v2, QA round-1 finding). Verify oche legibility
   in the next tablet pass; bumping back to 130 fits the 244px hero if needed.

## Stress states (all on the artboard)

First dart hole 1 (nothing collapses) · 6 players (scroll, 6th row cut) · long name
24 chars («Alexander the boss bitch»: header curve 10px, board mid-trunc 16) · hole 18
wash (✗ ✗ ✗ chips, red filled plate `LYING 6 · TRIPLE BOGEY · WASH`, card scrolled to
the end) · sudden death (red overlay, chain `19 ▶ NOW`, console S19/D19/T19) · playoff
BULL (chain 19 ✓ 20 ✓ BULL ▶, cells 25/50/✗, board = tied leaders).

## Implementation owns

Rules/scoring/sudden-death behaviour · per-dart history data (zone per throw) · scroll
physics + auto-centering (leaderboard vertical, card horizontal) · widget rewrites
(`DossedartGolfActiveCard` → Hero3 etc., APIs free) · fixed-height regression test
pinning the zone budget · the ActionBar-MISS duplication call (proposal 1).

## Constraints honored

820×1180 · TopBar / ActionBar / S/D/T cells = approved chrome, untouched · tokens only ·
green = Golf brand · player accents from the 5-accent cycle (rule 7; 6th player repeats
cyan) · rule-4 header verbatim · always rendered, never grows (rule 2) ·
Press Start 2P / VT323 · no border-radius · English UI strings.

## Files

- `DOSSEDART golf overview round.html` — canvas (compare · stress · fasit)
- `golf-overview-round.jsx` — v3 components + fixtures + spec card (visual fasit)
- `golf-cockpit-v2.jsx` — baseline, loaded for the side-by-side boards only
- `design-canvas.jsx` — canvas shell
