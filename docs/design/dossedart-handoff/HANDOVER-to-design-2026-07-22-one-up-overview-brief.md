# 1UP overview — mode round 2 of 5 (2026-07-22)

**To:** Claude design (DOSSEDART track)
**Prerequisites:** the grammar sheet (incl. rules 4/7 from the X01 round) and the approved X01
reference artboard (`x01-overview/design_handoff_x01_overview/`, proposal B) — 1UP is a restyle
onto that skeleton: same 272 px zone, same card frame, same header, same standings rail.
Round order after this: Gotcha → Wildcard → Killer.
**Scope:** ONE zone — 1UP's overview between TopBar and board. Board, glow, TopBar, ActionBar:
approved chrome, out of scope.

---

## Where 1UP stands today

Closest to the target grammar already: per-player accents and an opponents strip with lives ship
now. What changes is the container (X01 card frame + rail replace today's card + strip), plus the
grammar header (photo avatar replaces the initials box). The mode-semantic frame states —
**green SAFE / red danger** — are approved deviations from the neutral grammar and stay.
Lime `#C6FF3C` is the 1UP mode brand (labels/chrome), never a player accent (grammar rule 7).

## Data priorities (what the zone must say, in order)

| Priority | Data | Notes |
|---|---|---|
| P1 — primary number | **BEAT `<target>`** — the score to beat | 60 px reference. Free-throw states (game start; every SURVIVOR round start) have no target: `SET THE TARGET` treatment instead |
| P1 — status | SAFE / CAN'T BEAT / `NEED n MORE` | The green/red moment; must read from the oche mid-turn. Tie = success (beat means ≥) |
| P2 | Own lives (pips) | Last-life keeps its persistent danger styling |
| Rail | Every player: lives + (SURVIVOR) `ROUND OUT` state | Poured into the X01 rail shape; sort order is design's call (throw order vs lives) since 1UP has no score ladder |
| Header | Avatar + name + dart pips `DART n/3` | Grammar rule 4 verbatim (`DART n/3` = the dart being thrown) |

Not shown, by decision: cumulative dart count, points (1UP has none), turn history beyond the
current-turn sum feeding the status line.

## The one question for design

**How do the mode-semantic states live inside the shared skeleton?** Today the whole card frame
flips green/red — but the frame border is now the player's accent (identity). Decide what carries
SAFE / CAN'T-BEAT / last-life instead (status band? primary-number treatment? glow?), and how
`ROUND OUT` reads on rail rows without fighting the accent dots. Everything else is inherited,
not designed.

## Stress states (each on the artboard)

Free throw — `SET THE TARGET`, no target exists (game start and SURVIVOR round start) ·
SAFE mid-turn · CAN'T BEAT · active player on last life · 6 players in the rail, 2 of them
`ROUND OUT` (SURVIVOR) · longest name (>16 chars, rail middle-truncation).

## Division of labor

- **Design owns:** the 1UP overview artboard (stress states above), the SAFE/danger/ROUND OUT
  treatments inside the grammar, spec card as fasit restating `OVERVIEW ZONE: h=272 px @
  820×1180 — all states fit, no growth`.
- **Implementation owns:** all rules/variant behaviour (BEAT THE LAST / SURVIVOR), tie logic,
  `DossedartOneUpActiveCard` rewrite, the fixed-height regression test.

## Format

Same bundle format: HTML artboard(s) + spec cards as fasit, JSX optional. Tokens only (player
accents from the 5-accent cycle — grammar rule 7), English strings, no border-radius.
