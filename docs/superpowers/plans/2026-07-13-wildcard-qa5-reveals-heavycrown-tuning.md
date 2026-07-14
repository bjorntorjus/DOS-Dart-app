# WILDCARD QA5 — Reveals, HEAVY CROWN & Chaos Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make WILDCARD's point-moving and turn-flow events legible (before→after reveals), add the rare leader-only HEAVY CROWN catch-up modifier, and tame the runaway chaos-meter loop.

**Architecture:** Extend the pure `WildcardEngine` event-resolution record with structured before/after score changes; the game screen renders those as rows in the existing `WildcardDialog` (no new overlay machinery). HEAVY CROWN is a standalone modifier def applied by a bespoke gate in `_rollTurnModifier` and penalised at banking. Chaos tuning is three constant/arithmetic edits in the engine's meter path.

**Tech Stack:** Flutter, Dart, no new packages. Seeded `math.Random` in every engine test.

## Global Constraints

- **Branch:** `feat/wildcard-qa3` (current WILDCARD QA branch). Release-train: commit locally after every green task; push/PR only on Bjørn's signal.
- **Staging:** stage ONLY the files you edited for this task (`git add <path> …`). NEVER `git add -A`/`git add .` — the working tree has untracked files (`.claude/`, design zips) that must never be committed.
- **Colors:** `DossedartTokens` only in WILDCARD widgets — never raw hex, never `colorScheme`.
- **All UI strings English.** Locked WILDCARD terminology unchanged.
- **Seeded RNG:** the engine takes `math.Random` in its constructor; NEVER `Random()` inside the engine. Every engine test constructs `Random(<fixed seed>)`.
- **Score floor 0** everywhere (steals/curses/penalties clamp). **Meter clamps 0–10.**
- **Snapshot undo:** every new mutable engine field MUST be added to `_WcUndoEntry` (currently 30 fields, `wildcard_engine.dart:67-130`), captured in `_pushUndo` (`:997-1030`) and restored in `undo()` (`:1032-1065`). RNG is deliberately NOT snapshotted.
- **Tests:** engine tests are pure Dart; screen/widget tests copy the existing WILDCARD harness (channel stubs, `pump()` + Durations, never `pumpAndSettle`). Full suite green after every task.
- **Spec:** `docs/superpowers/specs/2026-07-13-wildcard-qa5-polish-design.md`.

---

## File Structure

- `lib/models/wildcard_events.dart` — add `heavyCrown` modifier def (NOT added to `wcModifiers` list, so it never rolls randomly) + penalty table helper.
- `lib/models/wildcard_engine.dart` — extend `WcEventResolution` with `scoreChanges`; populate for swap/robinHood/rewind; HEAVY CROWN gate + banking penalty + `_missesThisTurn`; chaos tuning edits; undo coverage.
- `lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart` — a small reusable `WcBeforeAfterRows` widget (before→after rows) used inside dialog children.
- `lib/screens/wildcard_game_screen.dart` — render `scoreChanges` rows in `_eventDialog`, `_rewindDialog`; enrich `_cutDialog`/freeze copy; nothing else structural.
- Tests alongside each (`test/models/wildcard_engine_test.dart`, `test/models/wildcard_events_test.dart`, `test/widgets/dossedart_wildcard_dialogs_test.dart`, `test/screens/wildcard_game_screen_test.dart`).

**Task map:** Tasks 1–4 = Part A (event reveals); Tasks 5–7 = Part B (HEAVY CROWN); Task 8 = Part C (chaos tuning).

---

## Part A — Event reveals (before→after)

### Task 1: Add `scoreChanges` to the event-resolution record

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (typedefs ~`:133-145`; scoreSwap `:828-860`; robinHood `:862-886`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  ```dart
  /// Before/after game total for one player involved in an instant event.
  typedef WcScoreChange = ({int playerIndex, int before, int after});

  typedef WcEventResolution = ({
    WcInstantEventDef event,
    String detail,
    List<WcEventFlag> flags,
    List<WcScoreChange> scoreChanges, // NEW — empty when the event moves no visible totals
  });
  ```

- [ ] **Step 1: Write the failing tests** (seeded `math.Random(7)`; force events via `debugForceEvent`):
```dart
test('SCORE SWAP resolution carries before/after for both players', () {
  final e = plain(players: 2)..debugForceEvent('scoreSwap');
  // P0 banks a lead so totals differ, then hit a joker to fire the swap.
  // (Derive the seeded joker number by hand and drive onto it — see harness.)
  final ch = e.lastEventResolution!.scoreChanges;
  expect(ch.length, 2);
  expect(ch[0].after, ch[1].before);                  // swap symmetry
  expect(ch[1].after, ch[0].before);
  expect(ch.any((c) => c.before != c.after), isTrue); // it actually changed
});
test('ROBIN HOOD resolution carries hitter and victim before/after', () {
  final e = plain(players: 2)..debugForceEvent('robinHood');
  // ... drive onto a joker with a clear leader ...
  final ch = e.lastEventResolution!.scoreChanges;
  expect(ch.length, 2);
  final victim = ch.firstWhere((c) => c.after < c.before);
  final hitter = ch.firstWhere((c) => c.after > c.before);
  expect(victim.before - victim.after, hitter.after - hitter.before); // conserved
});
```
(Write these as concrete seeded scenarios with literal expected numbers derived by hand from the locked rules — no `expect(x, x)` tautologies. Reuse the existing engine-test harness helpers for driving a specific joker hit.)

- [ ] **Step 2: Run tests to verify they fail.** `flutter test test/models/wildcard_engine_test.dart` — expect FAIL (`scoreChanges` not a member).
- [ ] **Step 3: Implement.**
  - Add the `WcScoreChange` typedef; add `scoreChanges` to `WcEventResolution`.
  - **scoreSwap** (`:828-860`): after the swap, add
    ```dart
    scoreChanges: <WcScoreChange>[
      (playerIndex: hitter, before: a, after: b),
      (playerIndex: other, before: b, after: a),
    ],
    ```
    (`a`/`b` are the existing before-locals at `:837-838`.)
  - **robinHood** (`:862-886`): capture the hitter's before BEFORE mutating —
    ```dart
    final hitterBefore = totals[hitter];
    // ... existing victim math ...
    totals[hitter] += stolen;
    ```
    then
    ```dart
    scoreChanges: <WcScoreChange>[
      (playerIndex: hitter, before: hitterBefore, after: totals[hitter]),
      (playerIndex: victim, before: before, after: before - stolen),
    ],
    ```
  - Every OTHER `lastEventResolution` assignment (gift, cursed, freeze, cut, rewind, the "no target" early-returns) gets `scoreChanges: const <WcScoreChange>[]` so the record stays total. (REWIND fills it in Task 2.)
  - `WcScoreChange` is a value record → no undo-snapshot change needed (it lives inside `lastEventResolution`, already snapshotted at field 29).
- [ ] **Step 4: Run tests to verify they pass.** `flutter test test/models/wildcard_engine_test.dart` → PASS; then `flutter test test/` full suite green + `flutter analyze` clean.
- [ ] **Step 5: Commit** (stage only the two edited files): `git add lib/models/wildcard_engine.dart test/models/wildcard_engine_test.dart && git commit -m "feat(wildcard): event resolution carries before/after score changes"`

---

### Task 2: REWIND resolution carries per-player before/after

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (rewind case `:948-955`; `_executeRewind` `:986`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces:**
- Consumes: `WcScoreChange`/`scoreChanges` (Task 1).
- Produces: nothing new (populates an existing field).

- [ ] **Step 1: Write the failing test:**
```dart
test('REWIND resolution lists every player wiped back to round-start totals', () {
  final e = plain(players: 2)..debugForceEvent('rewindEvent');
  // Bank some round-3 points for both, then hit a joker to fire REWIND.
  final ch = e.lastEventResolution!.scoreChanges;
  expect(ch.length, 2);                                  // one row per living player
  for (final c in ch) {
    expect(c.after, e.roundStartTotals[c.playerIndex]);  // restored to round start
  }
});
```
- [ ] **Step 2: Run to verify it fails.** `flutter test test/models/wildcard_engine_test.dart` — FAIL (rewind `scoreChanges` empty).
- [ ] **Step 3: Implement** — in the `rewindEvent` case (`:948-955`), capture before/after around the delegate:
```dart
case 'rewindEvent':
  final before = List.of(totals);
  _executeRewind();                 // mutates totals -> roundStartTotals
  lastEventResolution = (
    event: event,
    detail: 'REWIND · round $round restarts',
    flags: const <WcEventFlag>[],
    scoreChanges: <WcScoreChange>[
      for (var i = 0; i < totals.length; i++)
        if (!isSkipped(i)) (playerIndex: i, before: before[i], after: totals[i]),
    ],
  );
  return true;
```
- [ ] **Step 4: Run to verify it passes.** `flutter test test/models/wildcard_engine_test.dart` → PASS; full suite green.
- [ ] **Step 5: Commit:** `git add lib/models/wildcard_engine.dart test/models/wildcard_engine_test.dart && git commit -m "feat(wildcard): REWIND resolution lists per-player score restore"`

---

### Task 3: `WcBeforeAfterRows` reveal widget

**Files:**
- Modify: `lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart`
- Test: `test/widgets/dossedart_wildcard_dialogs_test.dart`

**Interfaces:**
- Consumes: `DossedartTokens`.
- Produces:
  ```dart
  class WcBeforeAfterRows extends StatelessWidget {
    const WcBeforeAfterRows({super.key, required this.rows});
    final List<WcRevealRow> rows;
  }
  class WcRevealRow {
    const WcRevealRow({required this.name, required this.before,
        required this.after, required this.accent});
    final String name; final int before; final int after; final Color accent;
  }
  ```

- [ ] **Step 1: Write the failing test:**
```dart
testWidgets('WcBeforeAfterRows renders name and before → after per row', (t) async {
  await t.pumpWidget(_wrap(const WcBeforeAfterRows(rows: [
    WcRevealRow(name: 'AA', before: 123, after: 100, accent: DossedartTokens.cyan),
    WcRevealRow(name: 'AAA', before: 100, after: 123, accent: DossedartTokens.magenta),
  ])));
  expect(find.text('AA'), findsOneWidget);
  expect(find.textContaining('123'), findsWidgets);
  expect(find.textContaining('100'), findsWidgets);
  expect(find.textContaining('→'), findsWidgets);
});
```
(Reuse the file's existing test `_wrap`/`pump` harness; if none exists, wrap in a `MaterialApp`/`Directionality` per the other dossedart widget tests.)
- [ ] **Step 2: Run to verify it fails.** `flutter test test/widgets/dossedart_wildcard_dialogs_test.dart` — FAIL (widget missing).
- [ ] **Step 3: Implement** a `Column` of rows; each row a `Row[ Text(name, PressStart2P 12, accent), Spacer, Text('$before'), Text(' → ', white54), Text('$after') ]`. Tint the `after` value: `after >= before ? DossedartTokens.green : DossedartTokens.red` (both tokens — palette-compliant). VT323 for the numbers, size ~22. No animations (the parent dialog already animates in).
- [ ] **Step 4: Run to verify it passes.** `flutter test test/widgets/dossedart_wildcard_dialogs_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit:** `git add lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart test/widgets/dossedart_wildcard_dialogs_test.dart && git commit -m "feat(wildcard): before/after reveal rows widget"`

---

### Task 4: Render reveals in event + rewind dialogs; enrich freeze/cut copy

**Files:**
- Modify: `lib/screens/wildcard_game_screen.dart` (`_eventDialog` `:995-1014`; `_rewindDialog` `:1034-1051`; `_cutDialog` `:1016-1032`; new helper `_revealRows`), and the freeze detail string in `lib/models/wildcard_engine.dart` (`:912`)
- Test: `test/screens/wildcard_game_screen_test.dart`

**Interfaces:**
- Consumes: `engine.lastEventResolution.scoreChanges` (Tasks 1/2), `WcBeforeAfterRows`/`WcRevealRow` (Task 3), `dossedartAccent(i)` (`:24`), `players[i].name` (`:66`).
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests** (WILDCARD screen harness):
```dart
testWidgets('SCORE SWAP dialog shows both players before → after', (t) async {
  // pump screen, force a swap via engineForTest.debugForceEvent('scoreSwap'),
  // drive a joker hit via onDartHitForTest, advance to the event overlay.
  expect(find.byType(WcBeforeAfterRows), findsOneWidget);
  expect(find.textContaining('→'), findsWidgets);
});
testWidgets('FREEZE dialog names the frozen player and says skipped', (t) async {
  // force freeze, drive joker hit
  expect(find.textContaining('FROZEN'), findsOneWidget);
});
```
- [ ] **Step 2: Run to verify they fail.** `flutter test test/screens/wildcard_game_screen_test.dart` — FAIL.
- [ ] **Step 3: Implement:**
  - Add a helper on the screen state:
    ```dart
    List<WcRevealRow> _revealRows(List<WcScoreChange> changes) => [
      for (final c in changes)
        WcRevealRow(name: players[c.playerIndex].name.toUpperCase(),
            before: c.before, after: c.after, accent: dossedartAccent(c.playerIndex)),
    ];
    ```
  - In `_eventDialog` (`:995-1014`): when `res?.scoreChanges.isNotEmpty == true`, append `WcBeforeAfterRows(rows: _revealRows(res!.scoreChanges))` after the detail `Text`. Keep the mapped `detail` line above it as the sub-line.
  - FREEZE (empty `scoreChanges`): the mapped detail already names the player — change the engine freeze detail (`wildcard_engine.dart:912`) to `'P$leader FROZEN · skipped next turn (scores 0)'` so it reads clearly through `_mapEventDetail`.
  - In `_rewindDialog` (`:1034-1051`): append `WcBeforeAfterRows(rows: _revealRows(engine.lastEventResolution?.scoreChanges ?? const []))` under the existing copy, so the wipe is shown per player.
  - In `_cutDialog` (`:1016-1032`): CUT! has no `scoreChanges`; name who loses their turn. Render a "LOSES TURN: X, Y" line built in `_cutDialog` from `engine.currentPlayerIndex`/`engine.ranking()` (keeps the engine pure — do NOT compute skipped seats in the engine). Document the choice in a comment.
- [ ] **Step 4: Run to verify they pass.** `flutter test test/screens/wildcard_game_screen_test.dart` → PASS; full suite green + `flutter analyze` clean.
- [ ] **Step 5: Commit:** `git add lib/screens/wildcard_game_screen.dart lib/models/wildcard_engine.dart test/screens/wildcard_game_screen_test.dart && git commit -m "feat(wildcard): event/rewind dialogs show before→after; freeze/cut name who's affected"`

**Note for reviewer (flagged in spec review):** GIFT's redirect and CURSED's bite land at *banking*/on-hit, not at the event moment, so they carry no `scoreChanges` here — GIFT shows a "rest of turn → NAME" line (who benefits) and CURSED keeps its hidden "a curse is loose" copy. A CURSED-*hit* reveal would need a new overlay trigger plumbed through `WildcardDartResult`; left out of this plan as likely-intrusive (interrupts the thrower's own turn). Confirm this scoping.

---

## Part B — HEAVY CROWN

### Task 5: `heavyCrown` modifier def + penalty table

**Files:**
- Modify: `lib/models/wildcard_events.dart`
- Test: `test/models/wildcard_events_test.dart`

**Interfaces:**
- Consumes: `WcModifierDef`, `WcSeverity`, `DossedartTokens`.
- Produces:
  ```dart
  /// Rare leader-only catch-up modifier. NOT part of [wcModifiers] — never rolls
  /// randomly; the engine applies it via a bespoke gate.
  const heavyCrown = WcModifierDef(
    id: 'heavyCrown', name: 'HEAVY CROWN', icon: '👑',
    desc: 'Misses are brutal — play it safe',
    severity: WcSeverity.wild,
  );
  /// True-miss penalty subtracted from the leader's game total at turn end,
  /// indexed by miss count in the turn: 0,1,2,3 -> 0,20,40,80.
  const List<int> kHeavyCrownPenalty = [0, 20, 40, 80];
  /// Tunable gate constants (calibrate on tablet QA).
  const int kHeavyCrownLeadThreshold = 120;   // min lead to qualify
  const int kHeavyCrownChancePct = 25;         // per-qualifying-turn trigger chance
  ```

- [ ] **Step 1: Write the failing tests:**
```dart
test('heavyCrown is not in the random modifier pool', () {
  expect(wcModifiers.any((m) => m.id == 'heavyCrown'), isFalse);
});
test('heavy crown penalty table', () {
  expect(kHeavyCrownPenalty, [0, 20, 40, 80]);
});
```
- [ ] **Step 2: Run to verify they fail.** `flutter test test/models/wildcard_events_test.dart` — FAIL.
- [ ] **Step 3: Implement** — add the consts (do NOT add `heavyCrown` to `wcModifiers`).
- [ ] **Step 4: Run to verify they pass** + `flutter analyze` clean.
- [ ] **Step 5: Commit:** `git add lib/models/wildcard_events.dart test/models/wildcard_events_test.dart && git commit -m "feat(wildcard): HEAVY CROWN modifier def + penalty table"`

---

### Task 6: Engine — HEAVY CROWN gate in `_rollTurnModifier`

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (`_rollTurnModifier` `:644-680`; forced-lookup `:658-662`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces:**
- Consumes: `heavyCrown`, `kHeavyCrownLeadThreshold`, `kHeavyCrownChancePct` (Task 5); `ranking()`.
- Produces: `debugForceModifier('heavyCrown')` must resolve (used by screen + Task 7 tests).

- [ ] **Step 1: Write the failing tests** (seeded):
```dart
test('HEAVY CROWN never fires before round 4', () {
  final e = plain(players: 2, rounds: 10);
  // Give P0 a >=120 lead in rounds 1-3; assert activeModifier?.id != 'heavyCrown' each turn.
});
test('HEAVY CROWN only targets a leader ahead by >= threshold', () {
  // round >=4, P0 leads by 119 -> never crowned across many seeded rolls;
  // by 120 -> can be crowned.
});
test('debugForceModifier heavyCrown sets it as the active modifier', () {
  final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
  e.applyDart(20,1); e.applyDart(20,1); e.applyDart(20,1); // bank P0, roll P1's turn
  expect(e.activeModifier?.id, 'heavyCrown');
});
```
- [ ] **Step 2: Run to verify they fail.** `flutter test test/models/wildcard_engine_test.dart` — FAIL.
- [ ] **Step 3: Implement** in `_rollTurnModifier`:
  - Fix the forced-lookup (`:658-662`) so `heavyCrown` resolves (it's not in `wcModifiers`):
    ```dart
    if (forcedId != null) {
      chosen = forcedId == 'heavyCrown'
          ? heavyCrown
          : wcModifiers.firstWhere((m) => m.id == forcedId);
      _forcedModifierId = null;
    } else {
      chosen = _rollHeavyCrownOrNull() ?? _rollNormalModifier();
    }
    ```
    (Refactor the existing chance-roll body into `_rollNormalModifier()`; keep behavior identical.)
  - Add the gate (non-forced path, AFTER the frozen early-return at `:650`, and it bypasses the modifier-cooldown at `:652-655`):
    ```dart
    WcModifierDef? _rollHeavyCrownOrNull() {
      if (round < 4) return null;
      final rank = ranking();                    // living, totals desc
      if (rank.length < 2) return null;
      if (rank.first != currentPlayerIndex) return null;   // only the leader
      final lead = totals[rank[0]] - totals[rank[1]];
      if (lead < kHeavyCrownLeadThreshold) return null;
      if (_rng.nextInt(100) >= kHeavyCrownChancePct) return null;
      return heavyCrown;
    }
    ```
    Wire it so a crowned turn does NOT also consume the cooldown/normal roll (returning `heavyCrown` short-circuits `??`). Place the crown check so it still runs when `_hadModifierLastTurn` is set (crown ignores cooldown) — move the cooldown check into `_rollNormalModifier`, or check the crown before the cooldown return. Document the ordering with a comment.
- [ ] **Step 4: Run to verify they pass.** `flutter test test/models/wildcard_engine_test.dart` → PASS; full suite green.
- [ ] **Step 5: Commit:** `git add lib/models/wildcard_engine.dart test/models/wildcard_engine_test.dart && git commit -m "feat(wildcard): HEAVY CROWN gate — round>=4, leader by >=120, chance-gated"`

---

### Task 7: Engine — HEAVY CROWN miss penalty at banking

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (`applyDart` true-miss branch `:453-460`; `_bankCurrentTurn` `:590-623`; new field `_missesThisTurn`; undo `:67-130`, `_pushUndo`, `undo`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces:**
- Consumes: `kHeavyCrownPenalty` (Task 5), `heavyCrown` gate (Task 6).
- Produces: new snapshot field `_missesThisTurn` (undo field 31).

- [ ] **Step 1: Write the failing tests:**
```dart
test('HEAVY CROWN: 1/2/3 true misses cost 20/40/80 off the game total', () {
  final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
  e.applyDart(20,1); e.applyDart(20,1); e.applyDart(20,1);   // P0 -> 60, banks
  // now P1 under heavyCrown; give P1 a base total via setup, then miss x3;
  // assert totals[P1] dropped by exactly 80 (floored at 0).
});
test('HEAVY CROWN penalty floors at 0', () {
  // small total, 3 misses -> total 0, not negative.
});
test('HEAVY CROWN penalty only counts TRUE misses, not dimmed 0s', () {
  // a scoring dart of 0 via a dim does NOT add to the miss penalty.
});
test('undo across a HEAVY CROWN turn restores the penalty', () {
  // bank a heavyCrown turn with misses; undo; assert total and _missesThisTurn restored.
});
```
- [ ] **Step 2: Run to verify they fail.** `flutter test test/models/wildcard_engine_test.dart` — FAIL.
- [ ] **Step 3: Implement:**
  - Add `int _missesThisTurn = 0;` field; reset it in `_rollTurnModifier` (alongside `_missedThisTurn` at `:648`) and in `_bankCurrentTurn` scratch-reset (`:617-622`).
  - In the true-miss branch (`:453-460`) increment `_missesThisTurn++;` (independent of the first-miss-only `_missedThisTurn` meter guard).
  - In `_bankCurrentTurn`, after applying `bankedAmount` (`:611-612`) and before scratch-reset:
    ```dart
    if (activeModifier?.id == 'heavyCrown') {
      final penalty = kHeavyCrownPenalty[_missesThisTurn.clamp(0, 3)];
      totals[currentPlayerIndex] =
          math.max(0, totals[currentPlayerIndex] - penalty);
    }
    ```
  - Add `_missesThisTurn` to `_WcUndoEntry` (field 31), `_pushUndo` (`missesThisTurn: _missesThisTurn`), and `undo()` restore.
- [ ] **Step 4: Run to verify they pass.** `flutter test test/models/wildcard_engine_test.dart` → PASS; full suite green + `flutter analyze` clean.
- [ ] **Step 5: Commit:** `git add lib/models/wildcard_engine.dart test/models/wildcard_engine_test.dart && git commit -m "feat(wildcard): HEAVY CROWN miss penalty (-20/-40/-80 off total, floor 0), undo-safe"`

*(No separate screen task: `heavyCrown` is `activeModifier != null`, so the existing announce overlay already shows its icon/name/desc. Add one screen smoke test in this task that a forced heavyCrown turn shows the announce overlay with title `HEAVY CROWN` — put it in `test/screens/wildcard_game_screen_test.dart` and stage that file too.)*

---

## Part C — Chaos tuning

### Task 8: Tame the meter loop

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (joker `:474`; triple `:450`; round-start decay after `:699`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces:**
- Consumes: `_applyMeterChange` (existing).
- Produces: nothing new.

**Findings driving this (from the meter path):** joker hit is `+2` (`:474`), a **triple is already `+2`** (`:450`, not +1 as the spec assumed), a double is `+1` (`:451`), first true miss is `-1` (`:458`). The only downward pressure is a rare miss — hence the ratchet.

- [ ] **Step 1: Write the failing tests:**
```dart
test('joker hit raises the meter by 1 (was 2)', () {
  // force a joker hit at a known chaos level; assert the joker's meter contribution is +1.
});
test('a triple raises the meter by 1 (was 2)', () {
  final e = plain(); final r = e.applyDart(20, 3);
  expect(r.meterDelta, 1); expect(e.chaos, 1);
});
test('meter decays by 1 at the start of each new round', () {
  final e = plain(players: 1, rounds: 3);   // 1 player -> round advances every turn
  // raise chaos via triples, complete a round, assert chaos == prev - 1.
});
test('round-start decay clamps at 0', () { /* chaos 0 stays 0 after a round */ });
```
- [ ] **Step 2: Run to verify they fail.** `flutter test test/models/wildcard_engine_test.dart` — FAIL (current triple/joker = +2).
- [ ] **Step 3: Implement:**
  - Joker `:474`: `_applyMeterChange(2)` → `_applyMeterChange(1)`.
  - Triple `:450`: `_applyMeterChange(2)` → `_applyMeterChange(1)` (update the `// triple: +2` comment to `+1 (QA5 loop-taming)`).
  - Round-start decay: in `_advancePlayer`, immediately after `roundStartTotals = List.of(totals);` (`:699`), add `_applyMeterChange(-1); // QA5: cool the meter between rounds`. (Only the normal round-advance path decays; CUT!/REWIND round changes deliberately do NOT.)
  - Double stays `+1`.
  - Update any existing engine test that asserted the old `+2` triple/joker values (search the test file for `meterDelta` / chaos assertions and re-derive).
- [ ] **Step 4: Run to verify they pass.** `flutter test test/models/wildcard_engine_test.dart` → PASS; `flutter test test/` full suite green.
- [ ] **Step 5: Commit:** `git add lib/models/wildcard_engine.dart test/models/wildcard_engine_test.dart && git commit -m "feat(wildcard): tame chaos loop — joker +1, triple +1, -1 round-start decay"`

**Note for reviewer:** these four numbers are the tunable defaults from the spec; recalibrate on tablet QA. Triple `+2→+1` was added on top of the spec (the spec assumed triple was already +1) — flag if you want triple kept at +2.

---

## Verification

- [ ] `flutter analyze` → 0 issues; `flutter test test/` → all green.
- [ ] Manual tablet pass: force each reveal (swap/robin/gift/freeze/rewind/cut) via dev override and confirm before→after / who's-affected reads clearly; force HEAVY CROWN and confirm the announce + a 3-miss turn dents the total by 80; play a full game and confirm chaos no longer pins at 9–10.
- [ ] superpowers:requesting-code-review against the spec (engine↔screen contract, undo across HEAVY CROWN + reveals, floor-0 everywhere, tokens-only).
- [ ] Hold for Bjørn: push/PR on his signal.

## Self-review notes (applied)

- Spec Part 1 (reveals) → Tasks 1–4; Part 2 (HEAVY CROWN) → Tasks 5–7; Part 3 (chaos tuning) → Task 8. Part 4 (logging) is a SEPARATE plan (`2026-07-13-cross-mode-logging-pass.md`).
- Deviations flagged inline: GIFT/CURSED reveal scoping (Task 4 note); triple +2→+1 beyond spec (Task 8 note); CUT! skipped-seat derivation kept in the screen, engine stays pure (Task 4).
- Type consistency: `WcScoreChange`/`WcRevealRow` names used identically in Tasks 1/3/4; `kHeavyCrownPenalty`/`kHeavyCrownLeadThreshold`/`kHeavyCrownChancePct` defined in Task 5, consumed in Tasks 6/7; `_missesThisTurn` introduced in Task 7 and added to undo in the same task.
