# QA Round 3 — Design Spec

**Date:** 2026-06-11
**Status:** Approved by Bjørn (verbal, same day)
**Scope:** X01 active-card placeholder + live last-3, layout lift (board/action bar), Splitscore layout/random/keypad, rating-rank in stats graph, player archiving.

## Background

Tablet-QA feedback after the 1.8.4+19 build (branch `fix/dossedart-x01-cockpit-fixes`). Decisions locked with Bjørn 2026-06-11:

1. Rating "placement" = rank on the rating leaderboard over time, derived backwards from existing history.
2. Player deletion = **archiving** (hide everywhere, keep all data, reversible).
3. Action-bar changes apply to ALL modes including Cricket (shared chrome consistency rule).
4. Splitscore double/triple keypad = 4 rows of 5 numbers.

## 1. X01 active card — placeholder + live last-3

**Problem:** The LAST/AVG section of `DossedartX01ActiveCard` only renders when data exists (`if (lastTurnLabel != null || avg != null)` — dossedart_x01_active_card.dart:144-230). Before the first throw the card is shorter, and after the first throw it grows. Additionally `_previousTurnLabel` (game_screen.dart:1148-1161) excludes the in-progress turn, so a player never sees their current darts — the panel looks stale until their next turn.

**Design:**

- The LAST + AVG section renders **always**. With no data: `—  —  —` for darts, `–` for sum, `AVG –` — dimmed (e.g. white at 0.3 alpha). Card height becomes constant.
- New LAST semantics: **"the player's most recent turn, where an in-progress turn counts as most recent."**
  - During your turn: shows the darts thrown so far this turn (1..3), updating live per dart. Sum likewise.
  - Between your turns: shows your last completed turn (current behavior).
- AVG already updates per dart — unchanged.

**Cross-mode consistency:** the same semantics apply to the `lastThrowLabel` string passed to `DossedartActiveStrip` in ATC, Cricket, Splitscore and Shanghai: the strip shows the in-progress turn's darts joined with ` · ` (e.g. `S5 · S6 · MISS`), falling back to the previous turn. `DossedartActiveStrip` itself is unchanged — each screen computes the string from its `throwHistory` (or equivalent state). This satisfies the ATC request ("text should say what you hit, all three darts") and keeps all modes identical.

## 2. Layout lift — board up, MISS bigger and lifted (all modes)

**Problem:** The X01 board sits low with a large constant gap above it; the MISS button feels small and hugs the bottom edge (Android gesture zone). ATC input cells also sit low.

**Design:**

- Because the active card now has constant height (§1), the gap above the X01 board no longer needs slack. Increase the board's `bottom` offset in the Positioned (game_screen.dart `_buildDossedartCockpit`) so the board moves up; the fixed-position invariant from the previous round is preserved (the board still never moves between darts).
- Shared `DossedartActionBar` (ALL 6 modes): button padding `vertical: 16 → 20`; bar bottom padding `12 → 20` (`EdgeInsets.fromLTRB(14, 12, 14, 12)` → `(14, 12, 14, 20)`). Exact values are tuned visually on the Galaxy Tab emulator during implementation; the intent is fixed: taller MISS, lifted clear of the gesture zone.
- ATC: input cells move up — reduce the gap above them, keep/grow the bottom margin toward the bar.

## 3. Splitscore

### 3a. SUM row placement

**Problem:** SUM is pinned at the bottom of the scorecard area while round rows sit at the top — dead space between them.

**Design:** Move the SUM row into the scroll content, directly below the last round row (halve_it_game_screen.dart `_splitScorecard`). The freed vertical space flows to the input area and action bar (§2).

### 3b. Random mode — hide future targets

**Problem:** In random mode all future round targets are visible from game start.

**Design:** Rounds with index greater than `currentRoundIndex` render `?` in the round-label column instead of their target. Played and current rounds render as today. The reveal happens when the round becomes current. Fixed (non-random) mode is unchanged. The trailing MÅL chip in the active strip already shows only the current round — unchanged.

### 3c. Double/triple keypad

**Problem:** `_splitKeypad` lays 20-21 fixed-width (58px) buttons in a Wrap → 2 dense rows, hard to hit.

**Design:** 4 rows of 5 numbers (1-5 / 6-10 / 11-15 / 16-20), button width computed from available width (not fixed 58px), larger tap targets and font. On double rounds, D-BULL gets its own row below row 4. Applies to both `anyDouble` and `anyTriple` keypads.

## 4. Stats — rank in the rating graph

**Problem:** The rating sparkline (dossedart_stats_screen.dart:725-766) shows the rating value only; you cannot see when a player passed someone on the leaderboard.

**Design:**

- **Derivation, no new storage:** for each `RatingSnapshot` in the focused player's `ratingHistory`, compute their leaderboard rank at that date by comparing against every other (non-archived) player's rating at the same point in time (each opponent's latest snapshot with `date <=` that point; players with no snapshot yet are excluded at that point).
- **Display:** a marker with a `#N` label is drawn on the sparkline at every point where the rank **changed** relative to the previous point: ▲ green (passed someone), ▼ red (got passed). Points with unchanged rank get no marker (no clutter).
- Archived players (§5) are excluded from rank computation.

## 5. Player archiving

**Problem:** No way to remove players. Long-press on a picker tile opens a profile dialog offering only name + avatar edit. (A hard-delete exists only in the legacy stats screen and does not cascade.)

**Design:**

- New persisted field on `SavedPlayer`: `bool archived` (default false, `?? false` on fromJson for legacy payloads).
- The long-press profile dialog (`_PlayerProfileDialog` in dossedart_setup_scaffold.dart) gains an **ARKIVER SPILLER** action with a confirmation dialog.
- Archived players are filtered out of: the setup picker, stats player lists, and all rank computations (§4). All their data — stats, H2H entries, rating history, game history — remains untouched. Fully reversible.
- **Restore path:** a discreet `ARKIV (n)` row at the bottom of the picker (rendered only when n > 0) expands to show archived players; their profile dialog shows **GJENOPPRETT** instead of ARKIVER.
- The legacy stats-screen hard delete is left as-is (out of scope).

## Out of scope

- Cricket changes beyond the shared action bar.
- Hard delete / cascade cleanup of player data.
- Elo calculation changes.
- Shanghai gamesWon/gamesPlayed gap and mid-game-change stats sentinel issue (separate follow-up, noted 2026-06-11).

## Testing

- Widget tests: X01 active card renders placeholder section with no data and constant height (pump both states, compare heights); live last-3 per-dart update (screen-level test via existing test hooks); Splitscore future-round `?` in random mode; keypad row structure; archived player hidden from picker; restore flow.
- Unit tests: rank derivation from multi-player rating histories (pass/fall/tie cases, archived exclusion); SavedPlayer JSON round-trip with `archived`.
- Existing suite must stay green; action-bar test untouched (asserts labels/callbacks only).
