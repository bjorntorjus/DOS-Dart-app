# Golf overview — mode round 4 (2026-07-22)

**To:** Claude design (DOSSEDART track)
**Prerequisites:** the grammar sheet — for header/accents/always-rendered only. Golf does not
show the full dartboard, so the 272 px cockpit skeleton does NOT bind, and **this round is
deliberately loose: you have free rein** (user's explicit call). Cockpit v2 (hero + standalone
leaderboard + windowed strip + TAP TO SCORE console) passed tablet QA on 2026-07-20 — keep it,
evolve it, or rethink it; your call. If you rethink, the deltas should be worth a fresh
tablet-QA pass.
**Scope:** Golf's in-game screen above the input console. TopBar, ActionBar, S/D/T input cells:
approved chrome, out of scope.

---

## Data priorities (what must be readable, in order)

| Priority | Data | Notes |
|---|---|---|
| P1 | **Hole number** — the segment being played | The ~130 px hero size exists for oche legibility (QA round 1 finding); whatever the layout, the hole must stay the loudest element |
| P1 — header | Who's throwing + `DART n/3` pips | Grammar rule 4; `DART n/3` = the dart being thrown |
| P2 | Strokes so far on this hole (misses stack) | The «LYING n» feeling — how bad is this hole going |
| P2 | Leaderboard: every player's total vs the course | Lowest wins; leader marked |
| P3 | Recent holes (scorecard strip) | Windowed view is fine; full card lives behind SCORECARD |

Not shown, by decision: cumulative dart count across holes (strokes carry it), par terminology
beyond the golf terms already in the mode.

## What carries over regardless of layout

- Header pattern + player accents from the 5-accent cycle (rules 4/7).
- Always rendered, never grows (rule 2): every state fits one fixed zone budget, stated on the
  spec card in px @ 820×1180 — sudden death included.
- Tokens only · Press Start 2P / VT323 · no border-radius · English strings. Green stays the
  Golf mode brand (approved earlier).

## Stress states (each on the artboard)

Sudden death (playoff target 19/20/Bull) · 6 players on the leaderboard · long name (>16 chars) ·
hole 18 with a wash (6 strokes) · first dart of hole 1.

## Division of labor

- **Design owns:** the Golf artboard(s) to whatever depth you choose, spec card as fasit with
  the zone budget stated.
- **Implementation owns:** all rules/scoring/sudden-death behaviour, widget rewrites, the
  fixed-height regression test.

## Format

Same bundle format: HTML artboard(s) + spec cards as fasit, JSX optional.
