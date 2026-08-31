# Post-game v2 — Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Richer post-game screens — the progression chart in 8 of 10 modes (incl. a new Golf strokes-per-hole progression), an embedded Golf scorecard, the Shanghai stats bug fixed, the four dead stat fields rendered, and a DETAILS drill-down into KAMPDETALJER for golf/x01/wildcard.

**Architecture:** All content flows through the existing `GameResult` → `PostGameScreen` pipeline. New: a `'golf'` case in `progressionForMode`, an optional `GameResult.detailEntry` (ephemeral `GameHistoryEntry` built by a new `StatsRecorder.buildEntry` shared with `recordGame`), and a `GolfScoreGrid` extracted from the modal sheet for reuse on the post-game screen. No engine/rules changes.

**Spec:** `docs/superpowers/specs/2026-07-23-post-game-v2-design.md`.

## Global Constraints

- The post-game screen serves BOTH design tracks → M3 `colorScheme` roles per CLAUDE.md palette (primary/secondary/tertiary/error), NOT DossedartTokens — except the embedded Golf grid, which reuses the existing golf term-color helpers as-is (approved exception family: data-viz/term colors).
- English UI strings. No behavioral/rules changes; Elo suppression per mode unchanged.
- Golf's `DartThrow.points` is a placeholder — NEVER use it for golf math; derive strokes from segment/multiplier/roundNumber.
- Chart wiring copies wildcard's guard: `throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory)`, same for `progressionMode` (adapt the guard name per screen — some call it differently; the intent is "no chart on roster-changed games").
- Branch: `feat/post-game-v2`. `flutter analyze` clean before every commit.

---

### Task 1: GolfProgression

**Files:**
- Modify: `lib/stats/mode_progression.dart` (add class + `'golf'` switch case)
- Test: `test/stats/mode_progression_test.dart` (extend; create if absent — check for an existing test file first)

**Interfaces:**
- Consumes: `ModeProgression` base (`seriesFor(throws, {required playerIndex}) → List<num>`, `maxValue`, `descending`, `finishLabel`) at mode_progression.dart:4-10.
- Produces: `class GolfProgression extends ModeProgression` — y = CUMULATIVE vs-par after each hole (starts at 0; +(strokes-3) per hole), `descending: false` (lower is better but the chart plots the value; vs-par keeps lines centered and comparable), `maxValue` computed from data (follow how existing progressions set it — read `CumulativeScoreProgression`), `finishLabel: '⛳'`. Registered as `case 'golf':` in `progressionForMode`.
- **Strokes-per-hole derivation (the correctness core):** group the player's throws by `roundNumber`; within one round, walk IN ORDER and stop at the first hole-terminating dart: a hit (`segment > 0`) → strokes = `(4 - multiplier) + missesSoFar`; or the 3rd miss → strokes = 6. IGNORE any darts after the terminator in the same round — playoff darts are stamped with the frozen final `roundNumber` and would otherwise contaminate the last hole (verified quirk). A round with no terminator yet (in-progress) contributes nothing.

- [ ] **Step 1: Write the failing test** — cases: hit on first dart (T7 → 1 stroke → vsPar −2 cumulative), hit after 2 misses (D7 → 2+2=4 → +1), wash (3 misses → 6 → +3), cumulative series across 3 holes, playoff contamination (extra darts on the final roundNumber after its terminator are ignored — series unchanged), two players interleaved (per-player filtering). Build `DartThrow` fixtures with the fields golf actually stamps (segment=target or 0, multiplier, playerIndex, roundNumber; other required ctor fields dummy — copy an existing fixture pattern from the wildcard/x01 progression tests if present, else from `DartThrow`'s ctor).
- [ ] **Step 2:** Run red.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run green + `flutter analyze`.
- [ ] **Step 5:** Commit — `feat(stats): golf strokes-per-hole progression (vs-par series)`

---

### Task 2: Stats gaps — Shanghai case + four dead fields

**Files:**
- Modify: `lib/screens/post_game_screen.dart` (`_buildStats` switch, ~:276-326)
- Modify: `lib/screens/shanghai_game_screen.dart` (~:441 — pass richer stats)
- Test: `test/screens/post_game_stats_test.dart` (create if absent; else extend the existing post-game test file — grep first)

**Requirements:**
- New `case 'shanghai':` → `Score: X` (from `stats['score']`), `Best round: X` (new — the screen computes max per-round sum from its throwHistory and passes `'bestRound'`), and `Shanghai!` entry when `stats['shanghai'] == true` (screen sets it on the winner when `engine.isInstantShanghai`).
- `case 'gotcha'`: add `Score: X` first (field already passed).
- `case 'oneUp'`: add `Elims: X` (hide at 0; field already passed as `elimsDealt`).
- `case 'golf'`: add `1st-dart: X/Y` from `firstDartHits`/`holesPlayed` (both already passed).
- TDD: widget tests pumping `PostGameScreen` with synthetic `GameResult`s per mode asserting the new strings render (and `Elims` hidden at 0). Keep assertions exact-text.

- [ ] Steps: failing tests → red → implement (screen + switch) → green + analyze → commit `feat(post-game): shanghai stats case + render the four dead stat fields`

---

### Task 3: Chart wiring — six call sites + golf

**Files:**
- Modify: `lib/screens/game_screen.dart` (~:1437 and the early-termination ~:1352), `cricket_game_screen.dart` (~:639), `around_the_clock_game_screen.dart` (~:1090), `halve_it_game_screen.dart` (~:674), `gotcha_game_screen.dart` (~:449), `shanghai_game_screen.dart` (~:441), `golf_game_screen.dart` (~:609 — has throwHistory already; add `progressionMode: 'golf'`)
- Test: extend each screen's existing test file with one assertion where cheap, plus one shared widget test in `test/screens/post_game_stats_test.dart` proving the chart section renders when progressionMode+throwHistory are set and not when null.

**Requirements:** each site passes `throwHistory: <roster-changed> ? null : List<DartThrow>.from(throwHistory)` and `progressionMode: <roster-changed> ? null : '<key>'` with keys `'x01'`, `'cricket'` (use `'cricket'` for both variants — the switch handles cutthroat via the same class), `'aroundTheClock'`, `'halveIt'`, `'shanghai'`, `'gotcha'`, `'golf'`. Find each screen's roster-change flag (grep `_midGamePlayerChanges` or the screen's equivalent; killer/1UP excluded from this task).

- [ ] Steps: red (shared widget test) → wire all 7 → green + analyze + full `flutter test` → commit `feat(post-game): progression chart wired for 7 more modes`

---

### Task 4: GolfScoreGrid extraction + post-game embed

**Files:**
- Modify: `lib/widgets/dossedart/golf/golf_scorecard.dart` (extract `GolfScoreGrid` — public widget with `{required List<String> names, required List<List<int?>> scorecards, required List<int> totals, required List<int> vsPars, required Set<int> skippedSeats}`; `_GolfScoreSheet` becomes a thin modal wrapper around it; keep `_legend` inside the grid)
- Modify: `lib/models/game_result.dart` (add `final Map<String, dynamic>? modeExtras;` to GameResult — optional, default null)
- Modify: `lib/screens/golf_game_screen.dart` (pass `modeExtras: {'names': ..., 'scorecards': ..., 'totals': ..., 'vsPars': ..., 'skippedSeats': ...}` — same data it feeds `showGolfScoreSheet`)
- Modify: `lib/screens/post_game_screen.dart` (render a `GolfScoreGrid` section between the winner banner and placements when `gameMode == 'golf' && modeExtras != null`, inside a horizontally-scrolling container; add per-player term-distribution to golf's `_buildStats` — counts of aces/birdies/pars/bogey+ computed by the SCREEN from the player's scorecard row and passed as `'termDist'` string, e.g. `'A1 B4 P9 B+4'` with zero categories omitted)
- Test: golf widget test group (GolfScoreGrid renders rows/PAR/legend standalone) + post_game_stats_test (grid appears for golf with modeExtras, absent without; termDist row renders)

- [ ] Steps: red → extract + wire → green + analyze + full suite (the modal sheet tests must stay green — the extraction is behavior-preserving) → commit `feat(golf): scorecard grid on the post-game screen + term distribution`

---

### Task 5: DETAILS drill-down (ephemeral entry)

**Files:**
- Modify: `lib/services/stats_recorder.dart` (extract `GameHistoryEntry buildEntry({...})` from `recordGame`'s assembly — `recordGame` calls it; signature mirrors the assembly inputs it already uses)
- Modify: `lib/models/game_result.dart` (add `final GameHistoryEntry? detailEntry;`)
- Modify: `lib/screens/post_game_screen.dart` (a `▶ DETAILS` OutlinedButton in the bottom row when `result.detailEntry != null && !result.statsSkipped` → `Navigator.push(GameDetailScreen(entry: result.detailEntry!))`)
- Modify: `lib/screens/golf_game_screen.dart`, `lib/screens/game_screen.dart`, `lib/screens/wildcard_game_screen.dart` — build the ephemeral entry with `StatsRecorder.buildEntry(...)` from the same locals they already assemble for `recordGame`/`_updateStats` (ratings fields left null — ratings compute at Finish; GameDetailScreen must tolerate that: verify and, if it assumes ratings, guard its rating section on null)
- Test: post_game test — DETAILS visible with detailEntry, hidden without/statsSkipped, tap pushes GameDetailScreen; a stats_recorder test asserting recordGame output is byte-equivalent before/after the extraction (same entry fields for same inputs)

- [ ] Steps: red → extract + wire 3 screens → green + analyze + full suite → commit `feat(post-game): DETAILS drill-down via ephemeral history entry (golf/x01/wildcard)`

---

### Task 6: Verification + final review

- [ ] `flutter analyze && flutter test` — clean + green.
- [ ] Whole-branch review (the standard adversarial pass) before handoff; fixups as `fix(post-game): <what>`.
- [ ] Tablet-QA stays with Bjørn (chart readability per mode, golf grid on device).
