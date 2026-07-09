# Gotcha v2 — Halving Mode + Chain-Gotcha Achievements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gotcha's kill becomes a HALVING by default (hardcore setup option keeps reset-to-0), plus four new event-based achievements for chain-gotchas (same-round double hits and consecutive-round hits).

**Architecture:** `GotchaEngine` gains a `hardcore` flag, an undo-safe round counter, and an event-sourced `killLog`; a pure derivation util maps the log to `AchievementEvent`s at game end (Shanghai `instantShanghai` pattern). Config/setup/announcer follow.

**Tech Stack:** Flutter, no new packages.

## Global Constraints

- **Branch:** `feat/gotcha-v2`, based on `feat/wildcard` tip (linear release train).
- Decisions (Bjørn 2026-07-09): default kill = **halving** (`totals[j] ~/ 2`, integer floor, 1 → 0 — halving CAN finish someone off); **hardcore** setup option = reset to 0 (v1 behavior). Achievements fire in BOTH modes. «Fortsett etter første vinner» stays PARKED (memory `project_gotcha_v2_feedback.md`).
- Achievement rules (memory): globally unique names (verified against the 68-name catalog — note PUNCHING BAG is taken), one-time unlocks (service-enforced), humor. New names: **DOUBLE TAP / PIÑATA / PERSONAL VENDETTA / CRASH TEST DUMMY**.
- All UI strings English; DossedartTokens only in DOSSEDART files; guard test applies.
- Kill-tips/climb-bar/stats keys UNCHANGED (kills/timesKilled count halvings too — a "gotcha" is a gotcha).
- Adding `AchievementEvent` values forces a compile error in `EarnedFeat._eventLabel`'s exhaustive switch — fix it in the same task.
- Tests: engine pure-Dart; screen tests reuse the existing gotcha harness (pump+Duration, no pumpAndSettle). Commit after every green task.

## Definitions (binding)

- **Round** (engine): 0-based counter, incremented when `_advancePlayer` wraps (new `currentPlayerIndex` <= previous thrower's index), matching the screen's existing `_roundNumber` semantics.
- **killLog entry:** `({int round, int attacker, int victim})` appended per victim per kill dart, snapshot-copied for undo.
- **Achievement events** (derived from killLog at game end, both modes):
  1. `gotchaDoubleTap` → attacker: same (attacker, victim) pair twice in ONE round → event for the attacker. (Possible: victim's total changes after the halving; landing on the new total with a later dart same turn.)
  2. `gotchaPinata` → victim: hit 2+ times in ONE round by ANY attackers (Bjørn's P2+P3 scenario).
  3. `gotchaVendetta` → attacker: same (attacker, victim) pair in two CONSECUTIVE rounds.
  4. `gotchaCrashDummy` → victim: hit in two CONSECUTIVE rounds by ANY attackers.

---

### Task 0: Branch

- [ ] `git checkout feat/wildcard && git checkout -b feat/gotcha-v2`; `flutter analyze` clean; `flutter test test/` green (baseline 588).

---

### Task 1: Engine — halving/hardcore, round counter, killLog

**Files:**
- Modify: `lib/models/gotcha_engine.dart`
- Test: `test/models/gotcha_engine_test.dart` (extend)

**Interfaces (produces):**
```dart
GotchaEngine({required int target, required int playerCount, this.hardcore = false});
final bool hardcore;
int round = 0;                     // 0-based, wrap-incremented, snapshot-restored
final List<({int round, int attacker, int victim})> killLog = []; // snapshot-copied
```

Kill block change (`applyDart`, currently `totals[j] = 0`):
```dart
if (totals[j] == newTotal && totals[j] > 0) {
  // Default: HALVING (integer floor — 1 halves to 0, so halving can
  // finish a player). Hardcore setup option keeps the v1 reset-to-0.
  totals[j] = hardcore ? 0 : totals[j] ~/ 2;
  timesKilled[j]++;
  killed.add(j);
  killLog.add((round: round, attacker: currentPlayerIndex, victim: j));
}
```
Round increment: in the existing turn-end/advance block, capture the pre-advance index; after `_advancePlayer()`, `if (currentPlayerIndex <= previousIndex) round++;`. Snapshot (`_GotchaUndoEntry`) gains `round` + deep-copied `killLog`; `undo()` restores both. `removePlayer`/`addPlayer` already clear the undo stack — killLog is NOT cleared on roster change (history stands; skipped players just stop appearing in new entries).

- [ ] **Step 1: failing tests** (add groups; hand-derived literals):

```dart
group('GotchaEngine halving mode (default)', () {
  test('kill halves the victim instead of resetting', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 280;
    final r = e.applyDart(20, 1); // 300 → lands on P0
    expect(r.killed, [0]);
    expect(e.totals[0], 150);
    expect(e.timesKilled[0], 1);
  });
  test('halving 1 finishes the player (1 ~/ 2 == 0)', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.totals[0] = 1; e.currentPlayerIndex = 1; e.totals[1] = 0;
    e.applyDart(1, 1); // lands on 1
    expect(e.totals[0], 0);
  });
  test('hardcore resets to 0 (v1 behavior)', () {
    final e = GotchaEngine(target: 301, playerCount: 2, hardcore: true);
    e.totals[0] = 300; e.currentPlayerIndex = 1;
    e.applyDart(20, 3) /* 60 — craft landing */;
    // rewrite while implementing: put P1 at 240 so T20 lands on 300
    expect(e.totals[0], 0);
  });
  test('chain-halving: same victim halved twice in one round by two attackers', () {
    final e = GotchaEngine(target: 501, playerCount: 3);
    e.totals[0] = 300; e.totals[1] = 240; e.totals[2] = 150;
    e.currentPlayerIndex = 1;
    e.applyDart(20, 3);  // P1: 240+60=300 → P0 halves to 150
    expect(e.totals[0], 150);
    e.applyDart(0, 0); e.applyDart(0, 0); // end P1's turn
    e.applyDart(0, 0); e.applyDart(0, 0); e.applyDart(0, 0); // P2 turn... WAIT P2 at 150 == P0 at 150 — landing? P2 misses: no kill (points>0 rule). Good.
    // rewrite while implementing: give P2 a dart landing exactly on 150 via
    // totals[2]=90 + T20 → 150 → P0 halves again to 75 IN THE NEXT ROUND —
    // for SAME-round chain use P2 seat AFTER P1 in the same rotation.
    expect(e.killLog.length, greaterThanOrEqualTo(2));
  });
  test('undo restores the halved total, round and killLog', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 280;
    e.applyDart(20, 1);
    expect(e.killLog, hasLength(1));
    e.undo();
    expect(e.totals[0], 300);
    expect(e.killLog, isEmpty);
  });
});
group('GotchaEngine round counter', () {
  test('round increments on rotation wrap and restores on undo', () {
    final e = GotchaEngine(target: 301, playerCount: 2);
    expect(e.round, 0);
    for (var i = 0; i < 6; i++) { e.applyDart(1, 1); } // P0 turn + P1 turn
    expect(e.round, 1);
    e.undo();
    expect(e.round, 0);
  });
});
```
(The two tests marked "rewrite while implementing" must be finalized with hand-derived exact sequences and literal asserts — the comments show the intent; no `greaterThanOrEqualTo` in the final version, assert the exact log contents as record literals.)

- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** file green + FULL suite green (existing kill tests asserted `totals[j] == 0` — they were written for v1: update ONLY those asserts to the halving default OR construct them with `hardcore: true`, whichever keeps each test's intent; document each choice in the commit body).
- [ ] **Step 5:** Commit `feat(gotcha): halving kill mode (hardcore option), round counter, event-sourced kill log`

---

### Task 2: Config + setup + announcer

**Files:**
- Modify: `lib/models/game_config.dart` (GotchaConfig), `lib/screens/dossedart/dossedart_gotcha_setup_screen.dart`, `lib/screens/player_setup_screen.dart` (gotcha options + dispatch), `lib/screens/gotcha_game_screen.dart` (engine ctor + announce), `lib/services/game_announcer.dart` (announceKill phrase)
- Test: extend `test/models/game_mode_test.dart` + `test/screens/gotcha_game_screen_test.dart`

- `GotchaConfig` gains `final bool hardcore;` (default false) — metadata test.
- DOSSEDART setup: `ArcadeToggleRow` gains `('HARDCORE · KILL TO 0', _hardcore, onChanged)` next to random-order; summary appends `' · HARDCORE'` when on; pass to config.
- Classic setup options card: a SwitchListTile-style row mirroring the file's toggle idiom ('Hardcore', subtitle 'Gotcha resets to 0 instead of halving') + dispatch passes it.
- Screen: `GotchaEngine(..., hardcore: widget.config.hardcore)`; kill announce builds the phrase per mode — change `GameAnnouncer.announceKill(List<String> victimNames)` to `announceKill(String phrase)` (same TTS+sound body) and build in the screen: hardcore → `'Gotcha! <names> back to zero'` / halving → `'Gotcha! <name> halved to <newTotal>'` (multi-victim: join with ' and ', totals read from `engine.totals` post-dart). Update the existing announceKill call site + any test touching it.
- Screen test: halving announce path smoke (kill fires, no crash, victim total halved in engine) + hardcore config drives reset (drive via onDartHitForTest with a crafted landing).
- [ ] TDD steps; analyze + full suite green. Commit `feat(gotcha): hardcore setup toggle; halving-aware kill announcements`

---

### Task 3: Achievement events + catalog + labels

**Files:**
- Modify: `lib/models/achievement_event.dart` (+4 values under a `// Gotcha` comment), `lib/models/earned_feat.dart` (`_eventLabel` cases), `lib/data/achievement_catalog.dart` (+4 entries)
- Test: extend the catalog/achievement test if one exists (glob test/**/*achievement*), else create test/data/achievement_catalog_gotcha_test.dart

Catalog entries (ids `got_` prefix, mode 'gotcha', category quirky, event-linked, glyph = fitting Material icons):
```dart
Achievement(id: 'got_double_tap', name: 'DOUBLE TAP', description: 'Gotcha the same player twice in one round', tier: AchievementTier.gold, category: AchievementCategory.quirky, glyph: _g(Icons.filter_2), mode: 'gotcha', event: AchievementEvent.gotchaDoubleTap),
Achievement(id: 'got_pinata', name: 'PIÑATA', description: "Get gotcha'd twice in the same round", tier: AchievementTier.silver, category: AchievementCategory.quirky, glyph: _g(Icons.celebration), mode: 'gotcha', event: AchievementEvent.gotchaPinata),
Achievement(id: 'got_vendetta', name: 'PERSONAL VENDETTA', description: 'Gotcha the same victim two rounds in a row', tier: AchievementTier.silver, category: AchievementCategory.quirky, glyph: _g(Icons.gps_fixed), mode: 'gotcha', event: AchievementEvent.gotchaVendetta),
Achievement(id: 'got_crash_dummy', name: 'CRASH TEST DUMMY', description: "Get gotcha'd two rounds in a row", tier: AchievementTier.silver, category: AchievementCategory.quirky, glyph: _g(Icons.airline_seat_flat), mode: 'gotcha', event: AchievementEvent.gotchaCrashDummy),
```
`_eventLabel` cases: 'Double tap', 'Piñata', 'Personal vendetta', 'Crash test dummy' (match the file's existing casing style — read it). Verify `AchievementCategory.quirky` exists (read the enum; else use the closest — social/scoring — and note it).
Tests: names unique across the whole catalog (there may already be such a test — extend), each new entry's event mapping resolves, ids unique.
- [ ] TDD; analyze + full suite green. Commit `feat(gotcha): chain-gotcha achievements — DOUBLE TAP, PIÑATA, PERSONAL VENDETTA, CRASH TEST DUMMY`

---

### Task 4: killLog → events derivation + game-end wiring

**Files:**
- Create: `lib/utils/gotcha_achievement_feats.dart`
- Modify: `lib/screens/gotcha_game_screen.dart` (_updateStats: replace both `const {}`)
- Test: `test/utils/gotcha_achievement_feats_test.dart`

**Interfaces:**
```dart
/// Derives chain-gotcha achievement events from the engine's kill log.
/// Pure — used at game end (undo-safe because the log itself is undo-safe).
Map<int, List<AchievementEvent>> gotchaEventsFromKillLog(
    List<({int round, int attacker, int victim})> killLog);
```
Rules per the Definitions section: doubleTap (same attacker+victim pair 2+ times in one round → attacker), pinata (same victim 2+ hits in one round → victim), vendetta (same pair in rounds r and r+1 → attacker), crashDummy (same victim in rounds r and r+1 → victim). Each event listed AT MOST ONCE per player per game (dedupe — the service one-times unlocks anyway, but feats display shouldn't spam).

Wiring: build `final events = gotchaEventsFromKillLog(engine.killLog);` in `_updateStats` and pass to `awardGameEnd(eventsByIndex: events)` + `buildEarnedFeats(eventsByIndex: events, ...)` (replacing BOTH `const {}` at ~lines 376/379).

- [ ] **Step 1: failing tests** — concrete logs with literal expectations:
```dart
test('double tap: same pair twice in one round → attacker event', () {
  final log = [(round: 2, attacker: 1, victim: 0), (round: 2, attacker: 1, victim: 0)];
  expect(gotchaEventsFromKillLog(log)[1], contains(AchievementEvent.gotchaDoubleTap));
});
test('pinata: two different attackers, same victim, same round → victim event only', () {
  final log = [(round: 0, attacker: 1, victim: 0), (round: 0, attacker: 2, victim: 0)];
  final ev = gotchaEventsFromKillLog(log);
  expect(ev[0], contains(AchievementEvent.gotchaPinata));
  expect(ev[1] ?? const [], isNot(contains(AchievementEvent.gotchaDoubleTap)));
});
test('vendetta: same pair rounds 3 and 4 → attacker; victim gets crash dummy', () {
  final log = [(round: 3, attacker: 2, victim: 1), (round: 4, attacker: 2, victim: 1)];
  final ev = gotchaEventsFromKillLog(log);
  expect(ev[2], contains(AchievementEvent.gotchaVendetta));
  expect(ev[1], contains(AchievementEvent.gotchaCrashDummy));
});
test('non-consecutive rounds do not trigger streak events', () {
  final log = [(round: 1, attacker: 2, victim: 1), (round: 3, attacker: 2, victim: 1)];
  final ev = gotchaEventsFromKillLog(log);
  expect(ev[2] ?? const [], isNot(contains(AchievementEvent.gotchaVendetta)));
});
test('events dedupe: pair hit twice in each of two rounds lists each event once', () { /* literal */ });
test('empty log → empty map', () => expect(gotchaEventsFromKillLog(const []), isEmpty));
```
- [ ] **Steps 2–4:** implement + wire; screen test extension: a game where a kill happened produces non-empty eventsByIndex... simplest integration assert: drive a double-tap sequence via hooks and after 'home' flow assert no crash + (if cheaply reachable) the recordGame call got feats — the pure util tests carry the logic burden; screen wiring verified by review.
- [ ] Full suite green. Commit `feat(gotcha): derive chain-gotcha achievement events from the kill log`

---

### Task 5: Spec update + verification + review

- [ ] Update `docs/superpowers/specs/2026-07-07-gotcha-design.md`: §2 kill rule (halving default, hardcore option, 1→0 note), new §2.1 'Chain gotchas & achievements' (the 4 definitions), changelog line 'v1.1 2026-07-09'. Mark the continue-after-winner idea as parked-for-v3 in §9.
- [ ] `flutter analyze` 0 issues; full `flutter test test/` green.
- [ ] Whole-branch review (superpowers:requesting-code-review, fable) against this plan + the updated spec; fix Criticals/Importants; hold for Bjørn (no push).

## Self-review notes

- Both modes fire achievements (Bjørn: «halver / kill») — derivation runs on killLog regardless of hardcore.
- PUNCHING BAG name collision avoided (existing cross-mode achievement) — CRASH TEST DUMMY instead.
- killLog survives roster changes (undo stack clears, history stands); skipped players can still hold historical entries — derivation doesn't filter them (an earned pinata before leaving still counts — matches how stats behave).
- Round counter matches the screen's `_roundNumber` semantics — the screen KEEPS its own counter for DartThrow (no behavior change); a follow-up could unify them (screen reads engine.round) — noted, not required.
