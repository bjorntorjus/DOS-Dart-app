# WILDCARD QA Round 1 — Tuning & Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply Bjørn's WILDCARD tablet-QA feedback (2026-07-09): fix scorecard/board overlap, cut TTS chatter, value-based EVENS/ODDS/DIV3 with per-ring board dimming, flow tuning (event chances, meter movement, modifier cooldown), literal HOLY TRINITY (S20+S5+S1), and normalize the home fresh-tile chrome.

**Architecture:** Data-layer changes in `wildcard_events.dart` (table + dims signature), per-ring dim in the shared dartboard (nullable, callers unchanged), engine tuning in `wildcard_engine.dart` (all snapshot-safe), screen TTS/layout fixes, home tile chrome change.

## Global Constraints (decisions locked with Bjørn 2026-07-09)

- **Branch:** `feat/wildcard-qa`, based on `feat/gotcha-v2` tip (linear train).
- **Chance table:** `[0, 5,5, 15,15, 30,30, 50,50, 80,80]` (was 0/10/10/25/25/45/45/70/70/100/100).
- **Meter movement:** TRUE miss −1 **at most once per turn**; **double +1** (new); **triple +2** (was +1); joker +2 and bull ±1/±3 unchanged. Clamp 0–10 unchanged.
- **Modifier cooldown:** a player who had a modifier on their previous turn gets NO roll this turn (guaranteed breather, per player).
- **Value-based restrictions:** ONLY EVENS / ONLY ODDS / DIVIDE BY THREE judge the DART VALUE (`segment × multiplier`): D5=10 scores under EVENS; the T-ring always scores under DIV3. Halves + BLACK/WHITE stay positional (about the board, not the number). **Bull always scores under every restriction** (unchanged locked rule — the chaos lever is unconditional).
- **Per-ring dimming:** the dartboard's dim predicate becomes `bool Function(int segment, int multiplier)?` — each wedge band (inner single=1, triple=3, outer single=1, double=2) dims independently; number label dims only when ALL of the segment's bands dim. Bull never dims. X01/Gotcha/Killer pass null — byte-identical rendering.
- **HOLY TRINITY:** the turn's three darts are EXACTLY the singles S20, S5, S1 in any order → +100 (banks 126). Not "any 26". Desc: `'Hit single 20, 5 and 1 — the classic'`.
- **TTS diet (WILDCARD only):** REMOVE announceNextPlayer + per-dart announceThrow + modifier descriptions + event details. KEEP short stings via announceChaos: modifier NAME only, `'Joker!'`, `'Cut!'`, `'Rewind!'`, `'Window prize! 100 points'`, winner announcement. Meme sound hooks untouched (sounds ≠ TTS).
- **Board overlap fix:** board side = `min(width − 28, availableHeight − 32)`, bottom-anchored — full 760-class size when it fits, shrinks instead of overlapping the scorecard on 16:10 tablets. WILDCARD screen only.
- **Home fresh tiles:** same chrome as live tiles (surface bg, phosphor 2px border, phosphor glow, white label) + the yellow NEW ribbon. Drop the cyan treatment entirely. Keep `StackFit.passthrough` + width regression test.
- **Chaos-meter footer:** must not lie about the new table — right text becomes `'events @ <pct>%'` at every level, with `' · 2 JOKERS'` appended at ≥9 (replaces 'EVENTS EVERY TURN · 2 JOKERS').
- All strings English; tokens only; tests pump+Duration; commit per green task. Baseline 611 tests.

---

### Task 0: Branch
- [ ] `git checkout feat/gotcha-v2 && git checkout -b feat/wildcard-qa`; analyze clean; full suite green (611).

### Task 1: Data layer — table, value-based dims, trinity text
**Files:** `lib/models/wildcard_events.dart`, `test/models/wildcard_events_test.dart`.
- `wcModifierChancePct` returns the new table; update the exact-table test.
- `WcModifierDef.dims` signature → `final bool Function(int segment, int multiplier)? dims;` — positional modifiers ignore the multiplier param; value-based: onlyEvens `(s,m) => (s*m).isOdd`, onlyOdds `(s,m) => (s*m).isEven`, divideByThree `(s,m) => (s*m) % 3 != 0`. Descriptions updated: onlyEvens `'Only even dart values score this turn'` (mirror for odds/div3).
- holyTrinity desc → `'Hit single 20, 5 and 1 — the classic'` (name/severity unchanged).
- Tests: D5 scores under EVENS (`dims(5,2) == false`), S5 dims (`dims(5,1) == true`); T7 scores under DIV3 (21), S7 dims; table test literal.
- [ ] TDD → green → commit `feat(wildcard): value-based restrictions, tuned chance table, literal trinity text`

### Task 2: Dartboard — per-ring dim
**Files:** `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart`, `test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart`.
- `isDim` → `bool Function(int segment, int multiplier)?`. Painter: inner+outer single bands dim on `isDim(n,1)`, triple band on `isDim(n,3)`, double band on `isDim(n,2)`; number label dims only when all three dim. Bull untouched; hit-testing untouched; null → identical.
- Update the existing dim tests to the new signature (e.g. `(n, m) => (n*m).isOdd`) + add: with the D5-scores predicate, painting succeeds and taps on segment 5's double band still resolve `DartZone.double_(5)`.
- The ONLY isDim caller is the WILDCARD screen (`isDim: engine.dimPredicate`) — it breaks compile until Task 3 updates the engine's exposure; do Tasks 2+3 in the same commit IF needed, otherwise adapt the screen line in this task with a thin lambda and let Task 3 finish the wiring. Prefer: change the engine's `dimPredicate` getter type in THIS task too (one line — it just forwards `activeModifier.dims`) so the branch stays green; Task 3 owns the scoring-side consumption.
- [ ] TDD → full suite green → commit `feat(wildcard): per-ring board dimming (value-based restrictions visible)`

### Task 3: Engine — meter tuning, cooldown, literal trinity, value-based scoring
**Files:** `lib/models/wildcard_engine.dart`, `test/models/wildcard_engine_test.dart`.
- Meter: `_missedThisTurn` flag (snapshot) — first TRUE miss in a turn −1, later misses 0; double-ring dart (multiplier==2, segment 1–20; D-Bull excluded — bull has its own lever) +1; triple +2. Update every affected meter test with the new literals.
- Restriction scoring consumes `dims(segment, multiplier)` (value-based now); dimmed-dart 0-points rule otherwise unchanged; meter still follows the dart (a dimmed triple gives +2 now — same principle as before, update tests).
- Cooldown: `late List<bool> _hadModifierLastTurn` (per player, snapshot, grows on addPlayer): at roll time, if the thrower's flag is set → skip roll AND clear the flag; when a modifier IS rolled, set the flag at banking. Tests: forced modifier turn → next turn same player never rolls (chaos 10, statistical-free: force + assert null), then the turn after CAN roll (force again → applies).
- HOLY TRINITY: engine tracks `turnDarts` as `List<({int segment, int multiplier})>` (snapshot; cleared per turn — replaces/augments whatever label list exists); banking check: exactly 3 entries, all multiplier 1, segment set == {20,5,1} → +100. Tests: S20,S5,S1 any order → 126; S20,S5,S2 → 27; T20,S5,S1 → no bonus (65... compute literal); 20,5,1 with a D → no bonus.
- [ ] TDD → green → commit `feat(wildcard): meter tuning (miss/turn, D+1, T+2), modifier cooldown, literal HOLY TRINITY`

### Task 4: Screen — TTS diet + board overlap
**Files:** `lib/screens/wildcard_game_screen.dart`, `test/screens/wildcard_game_screen_test.dart`.
- Remove `announceNextPlayer` + per-dart `announceThrow` calls; modifier announce → `_announcer.announceChaos('${mod.name}!')` (name only); joker → `'Joker!'`; cut/rewind → `'Cut!'`/`'Rewind!'`; event resolution NOT spoken (screen shows it); window prize + winner kept as-is. Meme/sound hooks untouched.
- Board zone: replace the width-anchored Positioned+AspectRatio with a LayoutBuilder-based bottom-anchored square of side `min(maxWidth − 28, maxHeight − 32)` (glow container + MISS field semantics unchanged). Comment: QA 2026-07-09 — 16:10 tablets are shorter than the 820×1300 design frame; shrink the board, never overlap the scorecard.
- Tests: existing screen tests keep passing (they don't assert TTS); add a layout regression: pump at a SHORT surface (e.g. 800×1000 logical), assert no RenderFlex/overlap exceptions and the dartboard's size ≤ available height (tester.getSize on the board finder).
- [ ] TDD → green → commit `fix(wildcard): board shrinks on short screens; TTS reduced to short stings`

### Task 5: Home — fresh tile chrome normalized
**Files:** `lib/screens/dossedart/dossedart_home_screen.dart`, `test/screens/dossedart_home_screen_test.dart`.
- `_TileKind.fresh` renders EXACTLY the live chrome (surface bg, phosphor border 2, phosphor glow, white label) wrapped in the existing Stack(passthrough) with the yellow NEW ribbon. Remove cyan bg/border/glow/label/emoji-shadow. Header hint stays.
- Tests: adjust any cyan-assertions; keep 2×NEW + width regression; add: fresh tile border color == phosphor (decoration predicate).
- [ ] TDD → green → commit `fix(gotcha,wildcard): NEW tiles use standard live chrome + ribbon only`

### Task 6: Meter footer + spec + verification + review
- `lib/widgets/dossedart/wildcard/dossedart_chaos_meter.dart`: footer right text `'events @ <wcModifierChancePct(level)>%'` at all levels, `' · 2 JOKERS'` appended at ≥9; update widget tests (level 10 → `'events @ 80% · 2 JOKERS'`).
- Spec `docs/superpowers/specs/2026-07-07-wildcard-design.md`: §3 movement + table updated, §4 EVENS/ODDS/DIV3 value-based + trinity literal, changelog note 'v1.1 QA tuning 2026-07-09'. Use the Edit tool for docs (NEVER PowerShell -replace on UTF-8 files).
- `flutter analyze` 0; full suite green; whole-branch fable review vs this plan; fix Criticals/Importants; hold for Bjørn.

## Self-review notes
- dims signature change ripples: events (T1) → board+engine getter (T2) → engine scoring (T3) → screen already passes the getter through. Order chosen so the branch compiles green after every task.
- Double +1 excludes D-Bull (bull is its own ±lever; double-counting the meter there would be noise) — documented in T3.
- 'EVENTS EVERY TURN' label dies with the 100% table — T6 fixes the honesty.
- Chain: dimmed T now +2 meter (was +1) — consistent with "meter follows the dart".
