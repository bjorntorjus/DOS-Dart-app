# X01 overview — mode round 1 of 5 (2026-07-22)

**To:** Claude design (DOSSEDART track)
**Prerequisite:** the grammar sheet (`HANDOVER-to-design-2026-07-22-grammar-sheet.md`) — X01 is
the template mode, so this round *produces the reference artboard* the other four restyle against.
**Scope:** ONE zone — X01's overview between TopBar and board. Board, glow, TopBar, ActionBar:
approved chrome, out of scope.

---

## Data priorities (what the zone must say, in order)

| Priority | Data | Today |
|---|---|---|
| P1 — primary number | REMAINING (oche-legible, 60 px reference) | ✅ ships |
| P2 | Checkout suggestion when ≤170 (helper strip) | ✅ ships — becomes always-rendered, dimmed when no checkout |
| P2 | Turn context: AVG + LAST turn (label + sum) | ✅ ships (placeholder-stable) |
| P3 — **NEW** | **Standings: every opponent's remaining** + a "to win" delta vs the leader | ❌ X01 is the only mode where opponents are invisible without opening the player sheet |
| header | Avatar + name + dart pips (`DART n/3`) | ✅ ships |

Not shown, by decision: cumulative dart count (AVG carries pace), match legs/sets (TopBar
territory), opponent AVGs (player sheet).

## What this round changes (only these three)

1. **Standings element** — the one real design task. All opponents visible inside the zone:
   name/initials + remaining + their accent dot; leader marked; a compact "to win" delta for the
   active player is an in-scope ask (not a PROPOSAL). Wildcard's demoted standings strip is the
   proven shape — standardize it here, since all four other modes will inherit it.
   **The 272 px budget does not grow**: fitting standings means rebalancing the card's interior
   (the AVG/LAST band and inner spacing are yours to tighten or merge; header and 60 px primary
   number stay).
2. **Per-player accent** replaces locked cyan (grammar rule 3).
3. **Checkout strip always-rendered** — design its empty/dimmed state (grammar rule 2).

## Stress states (each on the artboard)

First dart of the game (no AVG/LAST/checkout — all placeholders) · longest name (>16 chars) ·
6 players in standings · checkout present + 6 players at once (the max state that defines the fit).

## Division of labor

- **Design owns:** the restyled X01 overview artboard (stress states above), spec card as fasit
  stating `OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit, no growth`.
- **Implementation owns:** checkout computation, "to win" math, all behaviour;
  `DossedartX01ActiveCard` rewrite; the fixed-height regression test.

## Format

Same bundle format as previous handoffs: HTML artboard(s) + spec cards as fasit, JSX optional.
Tokens only, English strings, no border-radius.

---

## Round outcome (2026-07-22) — APPROVED

Bundle received same day (`x01-overview/design_handoff_x01_overview/`, DOSSEDART (11).zip);
**proposal B (standings rail on the right) approved** — it is the reference skeleton for rounds
2–5. Decisions on review:

- **HIT% PROPOSAL: APPROVED** (user sign-off). Definition, simpler than the artboard's
  suggestion: share of this leg's darts that hit the board at all — misses drag it down.
  Implementation owns the computation.
- **`DART n/3` = the dart being thrown** (`DART 1/3` before the first dart) — promoted to
  grammar rule 4 for all five modes.
- Name-curve thresholds: implementation keeps the shipped 6/10/16 breakpoints (spec card pins
  sizes 18/15/12/10, not thresholds).
- **Flag to design (does not block X01):** demo data used lime and yellow as player accents and
  purple `#B15CFF` — see grammar rule 7 (new) for the real 5-accent cycle. Spec-card *rules*
  were correct; only the sample players were off.
