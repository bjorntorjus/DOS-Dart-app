# WILDCARD QA Round 3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bjørn's second WILDCARD tablet-QA round: app renamed DOSSEDART, HOLY TRINITY v3 (5/20/1-only restriction + coverage bonus), compact chaos+round line (big meter gone, round shown ONCE), winner popup removed (straight to post-game with total score + per-round graph), high-level chaos boost, plus three log-discovered bugs (silent first-turn modifier, cursed-number reveal, TTS queue flooding).

**Architecture:** Data/table changes in `wildcard_events.dart`; trinity semantics in the engine; a slim chaos strip replaces the meter in the cockpit; PostGameScreen gains an optional shared progression chart (extracted from game_detail); TtsService gets a queue cap.

## Global Constraints (locked with Bjørn 2026-07-09)

- **Branch:** `feat/wildcard-qa2` off `feat/wildcard-qa` tip.
- **Chaos tuning:** chance table `[0, 5,5, 15,15, 30,30, 65,65, 90,90]`; `wcJokerCount`: 7–10 → **2** jokers (was 9–10 only).
- **HOLY TRINITY v3:** becomes a RESTRICTION + bonus: only segments {20, 5, 1} score (ANY ring — D5=10 counts, T20=60 counts); all other segments dim/score 0 (board dims per the normal restriction machinery; bull scores 0 too? — NO: locked rule "bull always scores under restrictions" gets an EXCEPTION here: trinity is about exactly three numbers; bull scores 0 and does NOT count toward coverage. Comment this exception in the def). Bonus: the turn's darts cover ALL THREE numbers (one dart on each of 20, 5, 1 — any ring each) → +100 at banking. Partial hits keep their points (e.g. D5+S20+miss = 30, no bonus; D5+S20+S1 = 31+100 = 131). Desc/directive sub: `'Only 5, 20 and 1 score — hit all three for +100'`.
- **Compact chaos strip:** the big 10-segment meter is REPLACED by a one-line strip: left `CHAOS <n>/10` (PressStart2P, heat color wcChaosColor(n), glow; subtle pulse only at ≥9, disableAnimations-aware), right `ROUND <x>/<N>` (VT323). Round shown ONLY here: TopBar trailing becomes null/empty; scorecard ribbon becomes `'▶ NOW THROWING'` (drop `SCORECARD · Rx/N`). The strip is small (~40px) — that + the ribbon change is the "calmer scorecard" ask.
- **Winner flow:** the winner overlay is REMOVED. gameOver → celebration (generic winner video + announceWinner unchanged) → straight to PostGameScreen. Post-game undo protocol unchanged ('↶ Back' still reopens).
- **Post-game additions:** (1) wildcard stat rows START with `Score: <total>` (the missing totalsum); (2) a per-round progression chart on PostGameScreen — extract the private `_LegPainter` + legend from `game_detail_screen.dart` into a shared `lib/widgets/dossedart/progression_chart.dart` (used by BOTH sites, rendering identical), `GameResult` gains `final List<DartThrow>? throwHistory;` + `final String? progressionMode;` (the gameMode key) — PostGameScreen renders the chart when both present, via `progressionForEntry`-equivalent logic (reuse `CumulativeScoreProgression` for wildcard). Wildcard passes them; other modes unchanged (null = no chart, zero behavior change).
- **Log-found fixes:** (a) FIRST-TURN modifier must announce (v1.11 game: constructor-rolled GOLDEN DART played silently — S5 scored 15 with no announce; ensure `_maybeShowAnnounce` runs on first build via post-frame callback + test); (b) cursed-number event dialog must NOT reveal the number — engine's `lastEventResolution.detail` for cursedNumber says a hidden number was cursed, no digits (fix at the engine detail-building site; test asserts no digit in the detail); (c) `TtsService` queue cap: when the pending queue exceeds 3, drop the OLDEST pending (never the currently-speaking) — keeps announcements near-real-time under rapid entry (X01 log hit queue=73); unit-test with the service's existing test seams (see tts_service_init_test.dart for the harness).
- **App name:** `android:label="DOSSEDART"` in android/app/src/main/AndroidManifest.xml (+ iOS CFBundleDisplayName='DOSSEDART' in ios/Runner/Info.plist if the key exists).
- **Chaos strip footer honesty:** the old meter's tests/labels retire with it; the strip has no event-% text (keep it clean — the % lives in the spec).
- All strings English; tokens only; pump+Duration tests; fix-dispatches stage only edited files; docs edits via the Edit tool only (never PowerShell -replace). Baseline 627 tests.

## Tasks

### Task 0: Branch
- [ ] `git checkout feat/wildcard-qa && git checkout -b feat/wildcard-qa2`; analyze clean; suite green (627).

### Task 1: Data layer — table, jokers, trinity def
**Files:** `lib/models/wildcard_events.dart`, `test/models/wildcard_events_test.dart`.
- Table → `[0,5,5,15,15,30,30,65,65,90,90]`; `wcJokerCount`: `level >= 7 ? 2 : level >= 1 ? 1 : 0`; holyTrinity def gains `dims: (s, _) => !const {20, 5, 1}.contains(s)` (note: this makes it a restriction — the ONE modifier where bull does NOT score; comment the exception) + new desc.
- Tests: table literal; jokerCount 6→1, 7→2, 10→2; trinity dims: (5,2) false (D5 scores!), (20,3) false, (7,1) true, (25,1) → the def dims bull? dims(25,·) must return true for trinity (bull excluded) — encode.
- [ ] TDD → commit `feat(wildcard): chaos boost at 7+, trinity becomes a 5/20/1 restriction`

### Task 2: Engine — trinity v3 banking + cursed redaction
**Files:** `lib/models/wildcard_engine.dart`, `test/models/wildcard_engine_test.dart`.
- Trinity scoring: restriction machinery already zeroes non-{20,5,1} darts via dims (verify the engine's bull-always-scores special case does NOT bypass trinity — the current code checks `segment == 25` before dims; trinity needs the exception: when activeModifier.id == 'holyTrinity', bull is NOT exempt. Implement minimally: the bull-exemption consults the modifier's dims for segment 25 — positional modifiers return false there anyway, so just remove the hardcoded exemption and let dims decide (all restriction defs must then explicitly NOT dim 25: verify each positional/value-based def returns false for segment 25 under all multipliers — value-based: 25*1=25 odd → EVENS would dim bull! So DON'T remove the blanket exemption; instead special-case trinity: `if (segment == 25 && mod.id != 'holyTrinity')` exempt. Comment.)
- Banking bonus: replace the all-singles set check with coverage: `turnDarts.map((d) => d.segment).toSet().containsAll({20, 5, 1})` → +100 (misses/off-numbers score 0 via dims so partials keep their trinity-number points automatically).
- Cursed-number detail: the `lastEventResolution.detail` for cursedNumber currently names the number — redact to `'A hidden number is now CURSED — hit it and it bites'` (no digits).
- Tests: D5+S20+S1 banks 131; S5+S5+S20 banks 30 no bonus; T20+D5+S1 banks 71+100=171; S5+S20+miss banks 25 no bonus; T7 under trinity scores 0; BULL under trinity scores 0 and doesn't count as coverage; cursed detail contains no RegExp(r'\d').
- [ ] TDD → commit `feat(wildcard): literal-coverage HOLY TRINITY restriction; cursed number stays hidden`

### Task 3: Cockpit — compact chaos strip, round dedupe, first-turn announce
**Files:** `lib/widgets/dossedart/wildcard/dossedart_chaos_meter.dart` (replace content with the strip — keep the file/class name `DossedartChaosMeter` but new one-line layout + `required int round, required int rounds` params), `lib/screens/wildcard_game_screen.dart`, `lib/widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart` (ribbon param/behavior), tests.
- Strip: margin (16,10,16,0), single Row height ~40: `'CHAOS'` PressStart2P 9 heat-colored + `<n>/10` PressStart2P 20 heat color w/ glow; Spacer; `'ROUND <x>/<N>'` VT323 16 white70. Danger pulse (subtle glow, 550ms reverse) only ≥9. Old meter tests replaced by strip tests (level 3 → 'CHAOS'+'3/10'+'ROUND 2/10'; level 10 pulse exists; no 'events @' text anymore).
- TopBar: trailing null/'' (check DossedartTopBar API); scorecard ribbon: `'▶ NOW THROWING'` (constructor: drop round/rounds params from the scorecard, keep everything else).
- First-turn announce: `initState` → `WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAnnounce())` (guard mounted). Test: pump a screen whose engine got `debugForceModifier` applied BEFORE first build → tricky since the engine constructor rolls first; use the ForTest seam: construct, immediately `engineForTest.debugForceModifier('onlyEvens')`... the first roll already happened in the ctor. Simplest deterministic test: chaos 8 seeded screens are non-deterministic — instead expose `@visibleForTesting void reRollFirstTurnForTest(String id)` that forces+rolls+re-announces, OR pump with startingChaos 0, force via debugForceModifier, call the screen's internal roll... PRAGMATIC: test that _maybeShowAnnounce is invoked post-frame by asserting the announce overlay appears when the engine has an activeModifier at first build — inject via `engineForTest..debugForceModifier('onlyEvens').. <trigger a re-roll through removePlayerForTest? no>`. Acceptable fallback: set `engineForTest.activeModifier` directly (public field) + call the new postFrame path via `dismissOverlayForTest`-style hook `@visibleForTesting void maybeAnnounceForTest()`; widget test asserts overlay appears. Implementer picks the cleanest; the REQUIREMENT is: a modifier active at first build produces the announce overlay + TTS sting.
- [ ] TDD → commit `feat(wildcard): compact chaos strip (round shown once), first-turn modifier announces`

### Task 4: Winner flow + post-game score & graph
**Files:** `lib/screens/wildcard_game_screen.dart`, `lib/models/game_result.dart`, `lib/screens/post_game_screen.dart`, new `lib/widgets/dossedart/progression_chart.dart`, `lib/screens/dossedart/game_detail_screen.dart` (delegates to the shared widget), tests (`test/screens/wildcard_postgame_undo_test.dart` + a post_game widget test).
- Remove the winner overlay state: on gameOver run the existing `_onGameEnd` celebration then call `_showPostGame(ranking)` directly (no overlay, no tap gate). Update the postgame-undo test (no more overlay dismissal step).
- `GameResult`: `final List<DartThrow>? throwHistory; final String? progressionMode;` (both null default — zero impact on other modes).
- Extract the chart: move `_LegPainter` + the series/legend block from game_detail into `ProgressionChart` (constructor: `{required ModeProgression progression, required List<DartThrow> throws, required List<String> playerNames}`); game_detail uses it (rendering byte-identical — its tests keep passing); PostGameScreen renders a `ProgressionChart` section when `result.throwHistory != null && result.progressionMode != null` (mode→progression mapping: reuse/move `progressionForEntry`'s switch into the shared file as `progressionForMode(String mode, List<DartThrow>)`, game_detail delegates).
- Wildcard `_showPostGame`: pass `throwHistory: List<DartThrow>.from(throwHistory), progressionMode: 'wildcard'`; stats map order puts score first AND post_game 'wildcard' case adds `Score: <n>` as the FIRST row.
- Tests: post_game widget test — pump PostGameScreen with a wildcard GameResult incl. a small throwHistory → finds the chart (byType ProgressionChart) + 'Score: 419'-style row; without throwHistory (gotcha result) → no chart. Wildcard postgame-undo test updated: gameOver → PostGameScreen appears WITHOUT any overlay tap; '↶ Back' still reopens.
- [ ] TDD → commit `feat(wildcard): straight-to-scoreboard with total score and per-round graph`

### Task 5: TTS queue cap + app name + exit log marker
**Files:** `lib/services/tts_service.dart` + `test/services/tts_service_*.dart`; `android/app/src/main/AndroidManifest.xml`; `ios/Runner/Info.plist` (if CFBundleDisplayName exists); `lib/services/game_logger.dart` + game screens' `_confirmExit`? — NO: keep scope tight, add the exit marker ONLY in GameLogger API (`logExit(String reason)`) and call it from the wildcard + gotcha `_confirmExit` quit action (two lines).
- TtsService: pending-queue cap 3 — on enqueue beyond cap, drop the oldest PENDING utterance (never the active one); preserve the init-invariant behavior (see memory: setEnable must trigger init — don't touch that path). Unit tests: enqueue 6 while speaking → queue holds the newest 3; order preserved; callWhenIdle unaffected.
- AndroidManifest: `android:label="DOSSEDART"`.
- [ ] TDD (tts) → commit `fix: TTS queue cap; app named DOSSEDART; exit log marker`

### Task 6: Spec v1.2 + verification + review
- Spec updates (Edit tool): §3 table (65/90) + jokers 7+→2; §4 trinity v3 row + bull-exception note; §7.3 winner flow (no overlay) + §7.4 post-game score+graph; changelog v1.2 line. Status line updated.
- `flutter analyze` 0; full suite green; whole-branch fable review vs this plan; fix Criticals/Importants; version bump 1.13.0 (ALL THREE sites) + APK; hold for Bjørn.

## Self-review notes
- Trinity/bull exception is the ONE deviation from locked rule #1/#2 ("bull always scores") — deliberately scoped to holyTrinity only, commented at the exemption site, spec §4 notes it.
- The meter widget keeps its class name so the screen diff stays minimal; its old tests are replaced wholesale (footer/heat-cell asserts die with the layout).
- ProgressionChart extraction must keep game_detail rendering byte-identical — its existing tests are the regression net.
- First-turn announce: game 1's silent GOLDEN DART (log 08:21, S5→15pts) is the repro; the fix is the postFrame announce; a deterministic widget test via a ForTest seam is required, exact seam left to the implementer.
