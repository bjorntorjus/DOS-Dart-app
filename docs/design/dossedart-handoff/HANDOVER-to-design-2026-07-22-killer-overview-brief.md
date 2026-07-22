# Killer overview — mode round 2 of 5 (2026-07-22)

**To:** Claude design (DOSSEDART track)
**Prerequisites:** the grammar sheet (incl. new rules 4/7 from the X01 round) and the approved
X01 reference artboard (`x01-overview/design_handoff_x01_overview/`, proposal B) — Killer is a
restyle onto that skeleton: same 272 px zone, same card frame, same header, same standings rail.
**Scope:** ONE zone — Killer's overview between TopBar and board. Board, glow, TopBar, ActionBar:
approved chrome, out of scope.

---

## Where Killer stands today

The only mode with **no active card at all** — a full roster list (number, name, tags, lives)
fills the zone, colored cyan-active / red-others. That colour scheme is replaced by the grammar's
per-player accents; red survives only as danger/eliminated semantics.

## Data priorities (what the zone must say, in order)

| Priority | Data | Notes |
|---|---|---|
| P1 — primary number | **YOUR NUMBER** — the segment the thrower physically aims at | Killer's REMAINING-equivalent: 60 px, player accent. Easily forgotten between turns |
| P1 — status | **KILLER or not** | The mode's biggest state flip; must read from the oche the instant it happens |
| P2 | Own lives (pips) | The only other number that matters to the thrower |
| Rail | Every player: number + lives + KILLER tag + eliminated state | The old roster's content, poured into the X01 rail shape |
| Header | Avatar + name + dart pips `DART n/3` | Grammar rule 4 verbatim |

Not shown, by decision: points (Killer has none), cumulative dart count, turn history.

## The one question for design

**How does KILLER status read on the card and in the rail?** The accent can no longer carry it
(accents are player identity now). Options are yours — badge, skull marker, border treatment —
but it must work in the two loud states: the active thrower IS a killer, and multiple killers in
the rail at once. Same call for the eliminated treatment (old roster used a dark veil).
Everything else is inherited, not designed.

## Stress states (each on the artboard)

First dart of the game (no killers, all lives full) · active player is a KILLER ·
6 players in the rail with 2 eliminated + 2 killers at once · longest name (>16 chars,
rail middle-truncation) · 1 life left on the active player.

## Division of labor

- **Design owns:** the Killer overview artboard (stress states above), the KILLER/eliminated
  treatments, spec card as fasit restating `OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit,
  no growth`.
- **Implementation owns:** all rules/lives/elimination behaviour, `_killerStatusKey` → rail
  rewrite, the fixed-height regression test.

## Format

Same bundle format: HTML artboard(s) + spec cards as fasit, JSX optional. Tokens only (player
accents from the 5-accent cycle — grammar rule 7), English strings, no border-radius.
