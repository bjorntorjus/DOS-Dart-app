# Cross-Mode Logging Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the game log a real debugging tool across all 6 modes — a full-standings snapshot (all players' totals) at every turn, standardized turn-start lines, roster-mutation logging, a build stamp on each game, and WILDCARD-specific diagnostics (chaos level, joker number, window bounds, cursed value).

**Architecture:** One pure formatter + two new methods on the `GameLogger` singleton; each game screen gains a call at its existing turn-advance / round-complete / roster-mutation points (already located per file below). A single `kAppVersion` constant replaces the two hardcoded UI version strings and feeds the build stamp.

**Tech Stack:** Flutter, Dart, no new packages (no `package_info_plus` — version stays a source constant).

## Global Constraints

- **Branch:** `feat/wildcard-qa3`. Release-train: commit locally after every green task; push on Bjørn's signal.
- **Log gating:** general lines write only when `GameLogger.isGeneralAllowed` (mode == `LogMode.full`); battery uses the looser `isBatteryAllowed`. LogMode values are `full`, `minimal`, `off` (`lib/services/app_settings.dart:3`). All new general lines MUST keep the `if (!isGeneralAllowed) return;` guard.
- **No behavior change** to gameplay — logging only. Every existing screen test suite MUST stay green (the harnesses stub channels; a new logger call must not throw when the logger is uninitialized in tests — the logger already no-ops when `_logFile == null`, `game_logger.dart:347`).
- **Two roster models:** engine-backed (`cricket`, `shanghai` — totals in `engine.scores` / `engine.totalScores`) vs screen-backed (`game_screen`/X01, `halve_it`, `killer`, `around_the_clock` — parallel lists `players[].score` / `totalScores` / `lives` / `currentTargets`). Read totals from the source listed per task.
- **Reference pattern:** `game_screen.dart` (X01) already calls `logTurnStart` (`:834`) and `logRoundComplete` (`:857`) — mirror its shape in the other five.

---

## File Structure

- Create: `lib/app_version.dart` — `const String kAppVersion = 'v1.14.0';` (single source of truth).
- Modify: `lib/services/game_logger.dart` — pure `formatStandings`, `logStandings`, `logRoster`, build-stamp param on `logGameStart`.
- Modify: `lib/screens/home_screen.dart:62`, `lib/screens/dossedart/dossedart_home_screen.dart:160` — use `kAppVersion`.
- Modify (one call each): the 6 game screens + `wildcard_game_screen.dart` for WILDCARD extras.
- Tests: `test/services/game_logger_test.dart` (new or extend).

---

### Task 1: Logger — `formatStandings`, `logStandings`, `logRoster`, build stamp, `kAppVersion`

**Files:**
- Create: `lib/app_version.dart`, `test/services/game_logger_test.dart` (if absent)
- Modify: `lib/services/game_logger.dart` (`logGameStart` `:74-94`), `lib/screens/home_screen.dart:62`, `lib/screens/dossedart/dossedart_home_screen.dart:160`

**Interfaces (produces — consumed by Tasks 2–8):**
```dart
// game_logger.dart
/// Pure, testable STANDINGS line body: "Aa:69  Aaa:76".
static String formatStandings(List<String> names, List<int> scores);
/// "R<round> STANDINGS <body>" (round omitted when null). Gated by isGeneralAllowed.
void logStandings({int? roundNumber, required List<String> names, required List<int> scores});
/// "ROSTER <action> P<index>(<name>) -> <formatStandings body>". action = 'ADD' | 'REMOVE'.
void logRoster({required String action, required int playerIndex, required String playerName,
    required List<String> names, required List<int> scores});
// logGameStart gains: String? build   // appended as " | BUILD <build>" on the GAME # line
```

- [ ] **Step 1: Failing tests:**
```dart
test('formatStandings joins name:score pairs', () {
  expect(GameLogger.formatStandings(['Aa','Aaa'], [69,76]), 'Aa:69  Aaa:76');
});
test('formatStandings tolerates length mismatch (zips to shortest)', () {
  expect(GameLogger.formatStandings(['Aa'], [69,76]), 'Aa:69');
});
test('kAppVersion is a non-empty v-string', () {
  expect(kAppVersion.startsWith('v'), isTrue);
});
```
- [ ] **Step 2:** Run → FAIL. `flutter test test/services/game_logger_test.dart`.
- [ ] **Step 3:** Implement:
  - `lib/app_version.dart`: `const String kAppVersion = 'v1.14.0';`
  - `formatStandings` (static, pure): zip to `min(names.length, scores.length)`, `'${names[i]}:${scores[i]}'`, joined by two spaces.
  - `logStandings`: `if (!isGeneralAllowed) return;` then `_write('${roundNumber != null ? 'R$roundNumber ' : ''}STANDINGS ${formatStandings(names, scores)}');`
  - `logRoster`: `if (!isGeneralAllowed) return;` then `_write('ROSTER $action P$playerIndex($playerName) → ${formatStandings(names, scores)}');`
  - `logGameStart`: add optional `String? build`; on the `GAME #` line (`:84`) append `${build != null ? ' | BUILD $build' : ''}`.
  - Replace the two hardcoded `'v1.14.0'` UI literals with `kAppVersion` (import `app_version.dart`). **Flag for review:** this centralizes the version so future bumps touch `pubspec.yaml` + `app_version.dart` only (the two home screens now derive it) — a deliberate reduction of the "bump in 3 places" chore.
- [ ] **Step 4:** Run → PASS + `flutter test test/` full suite green + `flutter analyze` clean.
- [ ] **Step 5:** Commit `feat(logging): standings/roster log helpers, build stamp, kAppVersion constant`

---

### Task 2: X01 (game_screen.dart) — standings + roster

**Files:** modify `lib/screens/game_screen.dart` (turn-start `:834`; round-complete `:857`; remove `_removePlayerMidGame` `:2229`)

- [ ] **Step 1:** Wire the build stamp: at the `logGameStart` call (`:208`) add `build: kAppVersion` (import `../app_version.dart`).
- [ ] **Step 2:** After the existing `logTurnStart` (`:834`), add:
  ```dart
  _log.logStandings(roundNumber: _roundNumber, /* the round field used at :857 */
      names: players.map((p) => p.name).toList(),
      scores: players.map((p) => p.score).toList());
  ```
  (Use the same round variable `logRoundComplete` uses at `:857`.)
- [ ] **Step 3:** In `_removePlayerMidGame` (`:2229`), after the removal mutates `players`, add a `_log.logRoster(action: 'REMOVE', playerIndex: index, playerName: <removed name>, names: players.map((p)=>p.name).toList(), scores: players.map((p)=>p.score).toList());`
- [ ] **Step 4:** Run `flutter test test/` (X01 screen suite must stay green) + `flutter analyze` clean. Manually confirm a STANDINGS + ROSTER line appears in a driven game log (verification section).
- [ ] **Step 5:** Commit `feat(logging): X01 standings snapshot + roster logging`

---

### Task 3: Cricket — turn-start + standings + roster

**Files:** modify `lib/screens/cricket_game_screen.dart` (turn-end block `:257-279`, `logAdvance` `:269`; add `engine.addPlayer` `:1700`; remove `:1716/1741`; `logGameStart` `:111`)

- [ ] **Step 1:** `logGameStart` (`:111`) += `build: kAppVersion`.
- [ ] **Step 2:** In the `result.turnEnded` block (`:257-279`), after `logAdvance` (`:269`), add a `logTurnStart` (mirror X01: `roundNumber`, `playerIndex: engine.currentPlayerIndex`, `playerName: players[engine.currentPlayerIndex].name`, `score: engine.scores[engine.currentPlayerIndex]`) followed by `logStandings(names: players.map((p)=>p.name).toList(), scores: engine.scores)`. (Cricket has no discrete round; pass `roundNumber: null` or the turn's round if tracked.)
- [ ] **Step 3:** Roster: after `engine.addPlayer` (`:1700`) → `logRoster(action:'ADD', ...)`; after `engine.removePlayer` (`:1716`) → `logRoster(action:'REMOVE', ...)`, both reading `engine.scores`.
- [ ] **Step 4:** `flutter test test/` (cricket suite green) + analyze clean.
- [ ] **Step 5:** Commit `feat(logging): cricket turn-start + standings + roster`

---

### Task 4: Shanghai — turn-start + standings + roster (none today)

**Files:** modify `lib/screens/shanghai_game_screen.dart` (turn-end `:238-246`; add `:617`; remove `:643`; `logGameStart` `:118`)

- [ ] **Step 1:** `logGameStart` (`:118`) += `build: kAppVersion`.
- [ ] **Step 2:** In the `turnEnded` block (`:238-246`), add `logTurnStart` (playerIndex `engine.currentPlayerIndex`, name `players[...].name`, score `engine.totalScores[...]`) + `logStandings(names: players.map((p)=>p.name).toList(), scores: engine.totalScores)`. Shanghai has rounds — pass the current round number if available, else null.
- [ ] **Step 3:** Roster: after `engine.addPlayer(initialScore: avgScore)` (`:617`) → `logRoster('ADD', …, scores: engine.totalScores)`; after `engine.removePlayer` (`:643`) → `logRoster('REMOVE', …)`.
- [ ] **Step 4:** `flutter test test/` (shanghai suite green) + analyze clean.
- [ ] **Step 5:** Commit `feat(logging): shanghai turn-start + standings + roster`

---

### Task 5: Halve It — turn-start + standings + roster

**Files:** modify `lib/screens/halve_it_game_screen.dart` (`_finishTurn` `:292`, `logAdvance` `:342`; add `:1769`; remove `:1797/1825`; `logGameStart` `:147`)

- [ ] **Step 1:** `logGameStart` (`:147`) += `build: kAppVersion`.
- [ ] **Step 2:** After `logAdvance` (`:342-349`), add `logTurnStart` (score from `totalScores[currentPlayerIndex]`) + `logStandings(names: players.map((p)=>p.name).toList(), scores: totalScores)`. The `logAdvance` `reason: 'new round …'` at `:348` already marks round rollover — pass that round number to `logTurnStart`.
- [ ] **Step 3:** Roster: after the add (`:1782/1788`, `_addSavedPlayerMidGame` `:1769`) → `logRoster('ADD', …, scores: totalScores)`; in `_performRemovePlayer` (`:1797`) → `logRoster('REMOVE', …)`.
- [ ] **Step 4:** `flutter test test/` (halve_it suite green) + analyze clean.
- [ ] **Step 5:** Commit `feat(logging): halve-it turn-start + standings + roster`

---

### Task 6: Killer — turn-start + standings + roster

**Files:** modify `lib/screens/killer_game_screen.dart` (`_advancePlayer` `:528`, round bump `:539-541`, `logAdvance` `:543`; add `:1831`; remove `:1850/1878`; `logGameStart` `:186`)

- [ ] **Step 1:** `logGameStart` (`:186`) += `build: kAppVersion`.
- [ ] **Step 2:** After `logAdvance` (`:543-550`), add `logTurnStart` (score = `lives[currentPlayerIndex]`, round `_roundNumber`) + `logStandings(names: players.map((p)=>p.name).toList(), scores: lives)`. (Score is lives — document that in the call site comment so a log reader knows.)
- [ ] **Step 3:** Roster: after the add grows the lists (`:1831-1841`) → `logRoster('ADD', …, scores: lives)`; in `_performRemovePlayer` (`:1850`, sets `isEliminated[index]=true` `:1859`) → `logRoster('REMOVE', …)`.
- [ ] **Step 4:** `flutter test test/` (killer suite green) + analyze clean.
- [ ] **Step 5:** Commit `feat(logging): killer turn-start + standings + roster`

---

### Task 7: Around the Clock — turn-start + standings + roster

**Files:** modify `lib/screens/around_the_clock_game_screen.dart` (`_advancePlayer` `:428`, `logAdvance` `:444`; `_isRoundComplete` `:455`; add `:1810`; remove `:1826/1859`; `logGameStart` `:201`)

- [ ] **Step 1:** `logGameStart` (`:201`) += `build: kAppVersion`.
- [ ] **Step 2:** After `logAdvance` (`:444-451`), add `logTurnStart` (score = `currentTargets[currentPlayerIndex]`) + `logStandings(names: players.map((p)=>p.name).toList(), scores: currentTargets)`. (Score is the current target number — comment it.)
- [ ] **Step 3:** Roster: after the add (`:1810`, grows `players`+`currentTargets` `:1815/1821`) → `logRoster('ADD', …, scores: currentTargets)`; in `_performRemovePlayer` (`:1826`) → `logRoster('REMOVE', …)`.
- [ ] **Step 4:** `flutter test test/` (ATC suite green) + analyze clean.
- [ ] **Step 5:** Commit `feat(logging): around-the-clock turn-start + standings + roster`

---

### Task 8: WILDCARD — standings + chaos/joker/window/cursed diagnostics

**Files:** modify `lib/screens/wildcard_game_screen.dart` (turn-advance / announce path around `:477-484`; event path `:342-349`; `logGameStart`), and `lib/services/game_logger.dart` if a dedicated line helps.

**Interfaces (consumes):** engine fields `chaos`, `jokers` (Set<int>), `activeModifier`, `window` (`({int lo,int hi})?`), `cursedNumber` — all already public on `WildcardEngine`.

- [ ] **Step 1:** `logGameStart` (WILDCARD start) += `build: kAppVersion`.
- [ ] **Step 2:** On each turn start (co-locate with `_maybeShowAnnounce`, `:477-484`, or the turn-advance hook), emit a standings + chaos line:
  ```dart
  _log.logStandings(roundNumber: engine.round,
      names: players.map((p) => p.name).toList(), scores: engine.totals);
  _log.log('R${engine.round} STATE chaos=${engine.chaos} '
      'mod=${engine.activeModifier?.name ?? '-'} '
      'jokers=${engine.jokers.toList()..sort()} '
      '${engine.window != null ? 'window=[${engine.window!.lo},${engine.window!.hi}] ' : ''}'
      '${engine.cursedNumber != null ? 'cursed=${engine.cursedNumber} ' : ''}');
  ```
  (Uses the existing free-form `log(...)`; keeps the WILDCARD-specific fields out of the generic `logStandings`.)
- [ ] **Step 3:** Enrich the SCORE SWAP event log: the `logEvent` call (`:344-345`) logs `engine.lastEventResolution?.detail`. After Plan A the swap `scoreChanges` carry numbers; append them to the logged detail so the swap line shows totals (parity with ROBIN HOOD which already logs `288 → 238`). Format: `'${res.detail} · ' + res.scoreChanges.map((c)=>'P${c.playerIndex} ${c.before}→${c.after}').join(', ')`.
- [ ] **Step 4:** `flutter test test/` (WILDCARD suite green) + analyze clean. Manually confirm the log now shows `chaos=`, `jokers=`, and swap totals.
- [ ] **Step 5:** Commit `feat(logging): WILDCARD standings + chaos/joker/window/cursed + swap totals`

---

## Verification

- [ ] `flutter analyze` → 0 issues; `flutter test test/` → all green.
- [ ] **Manual log inspection (the real test):** play one short game in each of the 6 modes with log mode = `full`, export the log, and confirm: a `GAME #… | BUILD v1.14.0` line; an `R# TURN` + `R# STANDINGS` pair each turn; a `ROSTER ADD/REMOVE` line when adding/removing mid-game; and for WILDCARD the `chaos=`/`jokers=`/swap-totals lines. Diff two consecutive STANDINGS snapshots and confirm any score change is attributable to the turn between them.
- [ ] Confirm `minimal` mode suppresses all these (only battery lines) and `off` suppresses everything.
- [ ] Hold for Bjørn: push/PR on his signal.

## Self-review notes (applied)

- Spec Part 4 (logging, all modes) → Tasks 1–8. Build stamp → Task 1 + per-screen Step 1. Turn-start standardization → Tasks 2–7. Roster → each screen task. WILDCARD extras → Task 8.
- Placeholder scan: no TBD/TODO; each screen task names exact line anchors and the exact score source (`players[].score` / `engine.scores` / `engine.totalScores` / `totalScores` / `lives` / `currentTargets`).
- Type consistency: `formatStandings`/`logStandings`/`logRoster` signatures defined in Task 1 are used verbatim in Tasks 2–8; `kAppVersion` defined in Task 1, consumed everywhere.
- Testability note: `formatStandings` is pure and fully unit-tested (Task 1). Per-screen wiring is a single call at a documented point; it is verified by (a) the existing screen suites staying green — proving no throw/regression — and (b) manual log inspection above, since asserting singleton file output per screen would be brittle. This is a deliberate, flagged choice.
- Task 8 Step 3 depends on Plan A (swap `scoreChanges`); run Plan A first, or skip Step 3's number-append until it lands. The rest of Task 8 (chaos/joker/window/cursed) is independent of Plan A.
