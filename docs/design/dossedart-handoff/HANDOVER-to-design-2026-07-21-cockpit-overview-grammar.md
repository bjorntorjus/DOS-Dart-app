# Cockpit overview grammar — cross-mode consistency round (2026-07-21)

**To:** Claude design (DOSSEDART track)
**From:** implementation, after a cross-mode audit of the five dartboard cockpits
**Scope:** ONE zone — the "overview" field that sits between the TopBar and the dartboard
(active card / scorecard / status key) in the five dartboard-input cockpits: **X01, Killer,
Gotcha, Wildcard, 1UP**. Everything below it (board, glow, ActionBar) and everything above it
(TopBar) is approved chrome and out of scope. The four strip-modes (Cricket, ATC, Shanghai,
Splitscore) already share one `DossedartActiveStrip` and are out of scope; Golf's hero/leaderboard
cockpit is freshly QA'd and out of scope.

---

## Why this round

Each dartboard cockpit got its overview designed in its own handoff, and each one is right *for
its mode* — but side by side the grammar has drifted. Same app, five answers to "who's throwing,
what do they need, where is everyone else". This round defines ONE grammar; content stays
mode-specific.

## Current state (audit, build 1.16.0+41)

| Mode | Overview today | Avatar | Active accent | Opponents visible? |
|---|---|---|---|---|
| X01 | Active card: REMAINING (60px) + AVG/LAST + checkout tip | Photo 56px | Locked cyan | **None** (player sheet only) |
| Gotcha | Active card + climb-bar + CHECKOUT/KILL helpers + NOW THROWING badge | Photo 52px | Locked cyan | Ticks on climb-bar |
| 1UP | Active card: life pips + BEAT target + turn block + status line | Initials box | Per-player accent; frame goes green/red semantically | Opponents strip w/ lives |
| Wildcard | Chaos meter + scorecard: dart slots, TURN/GAME, rank, directive | 3-letter handle box 46px | Per-player accent; purple on modifier | Full standings strip |
| Killer | No card — full roster list (number, name, tags, lives) | None | Cyan active / red others | Whole roster always |

Divergences that need a single answer:

1. **Active-accent policy is self-contradicting.** X01/Gotcha carry a comment calling locked-cyan
   a "locked design rule"; 1UP/Wildcard ship per-player accents. Both cannot be the rule.
   Implementation's recommendation: **per-player accent** — it is what the newest artboards use,
   and it directly serves the known tester complaint that the active thrower is hard to spot.
   Whatever you pick becomes the rule for all five (and the written rule gets updated).
2. **X01 is the outlier on opponent visibility.** Every newer cockpit shows the other players at
   a glance; X01 — the most played mode — shows nothing without opening the player sheet. X01
   needs a standings element (Wildcard's demoted standings strip is a proven shape; a "to win"
   delta vs the leader has been on the wishlist).
3. **Chrome drift with no design intent behind it:** photo vs initials vs handle vs no avatar;
   solid `surface` card fill (X01/Gotcha) vs vertical gradient fill (1UP/Wildcard); margins
   14/12/14/10 vs 14/8/14/4 vs 16/12/16/0; four different name-size curves; NOW THROWING badge
   in Gotcha only.

## HARD REQUIREMENT — one fixed height for the overview zone

**The overview zone gets ONE fixed height budget, identical across all five modes, spec'd in px
against the 820 × 1180 frame.** This is the top priority of the round, above the visual grammar:

- Every new mode so far has fought overview-vs-board overlap: Wildcard's scorecard overlapped the
  board on real 16:10 tablets (QA 2026-07-09, patched with a LayoutBuilder shrink), X01's card
  needed always-rendered placeholder rows so its height stays constant between darts, Gotcha's
  helpers dim-instead-of-disappear for the same reason. These are all local patches for the same
  missing rule.
- Design the zone **to the budget**: every state of every card fits inside it. Nothing may grow
  the card at runtime — helpers/chips/status lines that have no content **dim or show a
  placeholder, never collapse or appear** (Gotcha's `_HelperBar` dim-when-empty pattern is the
  precedent, now mandatory grammar).
- State the budget explicitly on the spec card (e.g. `OVERVIEW ZONE: h=xxx px @ 820×1180 —
  all states fit, no growth`) so implementation can pin it with a regression test per mode.
- Everything left over goes to the board zone — which then has the same size in all five
  cockpits, and tap targets never move between darts or between modes.
- If a mode genuinely cannot fit its overview in the shared budget (Killer's full roster at 6+
  players is the stress case), the artboard must solve it *inside* the zone (scroll, collapse to
  ticks, pagination) — not by taking space from the board.

## What design owns (the deliverable)

- The **shared grammar**: fixed zone height; one header pattern (avatar treatment + name +
  dart pips); one active-accent policy; one card frame treatment (fill, border, glow, margins);
  one name-size curve; whether NOW THROWING is a universal badge or dropped.
- The **standings element**: one compact "everyone else" pattern that each mode feeds its own
  data into (X01 remaining, Gotcha totals, 1UP lives, Wildcard totals, Killer lives/status).
  Per-mode extras (climb-bar ticks, danger skulls) may stay as mode flavour on top.
- **Restyled artboards for all five overviews** to the new grammar. Content/data per card is
  already QA'd and stays as listed in the audit table — this is a reskin of the zone, not a
  rethink of what each mode shows.
- **Killer's call:** keep the roster-list-as-overview concept (it fits the mode — no score, all
  status) but bring it into the grammar (zone height, accent policy, header treatment), or give
  Killer an active-card + standings split like the others. Your call, on the artboard.

## What implementation owns (do NOT design or spec this)

- All rules, scoring, engines, undo, stats, sounds/TTS — nothing behavioural changes this round.
- Component APIs: the five overview widgets are ours to rewrite/merge against the artboards
  (`DossedartX01ActiveCard`, `DossedartGotchaActiveCard`, `DossedartOneUpActiveCard`,
  `DossedartWildcardScorecard`, Killer's `_killerStatusKey`). Shared-widget extraction is an
  implementation decision.
- Fixed-height regression tests per mode once the budget is spec'd.

## Fixed constraints (unchanged)

- 820 × 1180 portrait tablet frame; CrtFrame, TopBar, ActionBar, dartboard + magenta glow reused
  verbatim.
- Tokens only (incl. lime `#C6FF3C` as the 8th accent); `Press Start 2P` / `VT323`; no
  border-radius; all UI strings English.
- Mode-specific state colours stay: 1UP's green-SAFE/red-danger frame, Wildcard's purple-modifier
  frame — the grammar defines the *neutral* look these deviate from.
- New functionality is **PROPOSAL**-only (standard protocol); the X01 standings element and a
  possible "to win" delta are in-scope asks, not proposals.

## Deliverable

Same bundle format as before: one artboard per mode's overview zone (stress states included —
longest name, 6+ players, empty helpers, first dart of the game), spec cards as fasit with the
zone height budget stated explicitly, JSX prototype optional.
