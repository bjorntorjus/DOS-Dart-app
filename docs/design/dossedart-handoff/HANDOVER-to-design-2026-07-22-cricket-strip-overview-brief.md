# Cricket / strip-family overview — mode round 3 (2026-07-22)

**To:** Claude design (DOSSEDART track)
**Prerequisites:** the grammar sheet + the approved X01 (rail-B) and 1UP (status-plate A+)
rounds — for the *grammar* (header, accents, always-rendered, hierarchy), not the skeleton:
this round is about the **strip-input family**, which does not show the full dartboard, so the
272 px cockpit skeleton does NOT bind here.
**Scope:** the overview zone in the four strip-input modes — **Cricket, ATC, Shanghai,
Splitscore** — which share one component (`DossedartActiveStrip`). Cricket is the content case
(most played); the other three inherit the restyled strip without their own rounds. Input
strips/keys, TopBar, ActionBar: approved chrome, out of scope.

---

## Why Cricket leads this round

Cricket is the most-played mode right now, and it has a standing "revisit against the
consistency principles" note from the spring. Its overview is also the family's hardest case:
the **marks grid** (15–20 + Bull per player) *is* the standings — no rail needed — so the round
must make the grid and the shared strip speak the same grammar.

## Data priorities (Cricket)

| Priority | Data | Notes |
|---|---|---|
| P1 | **Marks grid** — every player's state on 15–20 + Bull (0/1/2/3 marks, closed) | The grid is both scoreboard and standings; leader marked |
| P1 — header | Who's throwing: avatar + name + `DART n/3` pips | Grammar rule 4; `DART n/3` = the dart being thrown |
| P2 | Points + the diff that matters (`+34` vs leader / `YOU LEAD`) | Oche-legible; points only matter through the diff |
| P3 | Last turn's marks | Nice context, never at the grid's expense |

Not shown, by decision: cumulative dart count, MPR/stats (post-game/player sheet).

## The rules that DO carry over (grammar, not skeleton)

- Header pattern + accent policy (rule 4/7 — player accents from the 5-accent cycle).
- Always rendered, never grows (rule 2): the family zone gets **one fixed height budget of its
  own**, stated on the spec card in px @ 820×1180 and identical across the four strip modes —
  same principle as the cockpits, its own number.
- One primary element per card (rule 6): for Cricket that is the grid, not a number.

## The one question for design

**How does the shared strip + Cricket's marks grid adopt the grammar so ATC/Shanghai/Splitscore
inherit it for free?** The strip is one component in code — design the Cricket artboard, then
show one thumbnail per sibling mode proving the same strip works with their data (ATC target,
Shanghai round/points, Splitscore target + risk).

## Stress states (each on the artboard)

6 players in the marks grid (the fit case) · a number closed by all · long name (>16 chars) ·
first dart of the game · one player far ahead (diff readability).

## Division of labor

- **Design owns:** the Cricket overview artboard + sibling thumbnails, the family height budget,
  spec card as fasit.
- **Implementation owns:** all rules/scoring, `DossedartActiveStrip` + grid rewrite, the
  fixed-height regression tests for all four modes.

## Format

Same bundle format: HTML artboard(s) + spec cards as fasit, JSX optional. Tokens only, English
strings, no border-radius.

---

## Round outcome (2026-07-22) — APPROVED

Bundle received same day (`cricket-strip-overview/design_handoff_cricket_strip_overview/`,
DOSSEDART (14).zip); **A+ with SEGMENTS approved** (user-picked through three iterations):
score-in-strip + points-in-grid-headers, active player's marks as a 3-segment meter inside the
existing tap cells. Family budget fasit: **`FAMILY STRIP: h=132 px @ 820×1180`** (card 110 +
margins 12/10), identical in Cricket · ATC · Shanghai · Splitscore, sibling inheritance proven
on thumbnails. Notes:

- **Diff plate dropped for Cricket** (user's KISS call during iteration) — 👑 in the grid header
  carries the leader; the P2 "diff vs leader" from this brief is intentionally not shipped.
  Siblings keep their plates (ATC behind-plate, Shanghai diff) as illustrated; exact copy is
  implementation's call against real data.
- Grid never changes height: always 7 rows, `DEAD` tag on closed-by-all, ⊗ lock for the active.
- Leader math flips in Cutthroat (lowest leads) — implementation owns it.
- **Recurring flag to design:** demo purple is `#B15CFF` again (rule 7 says `#7B3FFF`; the 1UP
  bundle had it right). No implementation impact — accents come from `dossedartAccent` — but
  rounds 6-7 (Gotcha/Wildcard) should start from the 1UP template, not the X01 one.
