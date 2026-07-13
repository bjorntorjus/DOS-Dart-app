# WILDCARD QA5 — Reveals, HEAVY CROWN & Chaos Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make WILDCARD's point-moving and turn-flow events legible (before→after reveals), add the rare leader-only HEAVY CROWN catch-up modifier, and tame the runaway chaos-meter loop.

**Architecture:** Extend the pure `WildcardEngine` event-resolution record with structured before/after score changes; the game screen renders those as rows in the existing `WildcardDialog` (no new overlay machinery). HEAVY CROWN is a standalone modifier def applied by a bespoke gate in `_rollTurnModifier` and penalised at banking. Chaos tuning is three constant/arithmetic edits in the engine's meter path.

**Tech Stack:** Flutter, Dart, no new packages. Seeded `math.Random` in every engine test.

## Global Constraints

- **Branch:** `feat/wildcard-qa3` (current WILDCARD QA branch). Release-train: commit locally after every green task; push/PR only on Bjørn's signal.
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

---

## Part A — Event reveals (before→after)

### Task A1: Add `scoreChanges` to the event-resolution record

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (typedefs ~`:133-145`; scoreSwap `:828-860`; robinHood `:862-886`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces (produces):**
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

- [ ] **Step 1: Failing tests** (seeded `math.Random(7)`; force events via `debugForceEvent`):
```dart
test('SCORE SWAP resolution carries before/after for both players', () {
  final e = plain(players: 2)..debugForceEvent('scoreSwap');
  // P0 banks a lead so totals differ, then hit a joker to fire the swap.
  // (Derive the seeded joker number by hand and drive onto it — see harness.)
  // After the swap:
  final ch = e.lastEventResolution!.scoreChanges;
  expect(ch.length, 2);
  final hitter = ch.firstWhere((c) => c.playerIndex == e /*hitter idx*/);
  expect(hitter.before, isNot(hitter.after));         // it actually changed
  expect(ch[0].after, ch[1].before);                  // swap symmetry
  expect(ch[1].after, ch[0].before);
});
test('ROBIN HOOD resolution carries hitter and victim before/after', () {
  final e = plain(players: 2)..debugForceEvent('robinHood');
  // ... drive onto a joker with a clear leader ...
  final ch = e.lastEventResolution!.scoreChanges;
  expect(ch.length, 2);
  // victim.after == victim.before - stolen; hitter.after == hitter.before + stolen
  final victim = ch.firstWhere((c) => c.after < c.before);
  final hitter = ch.firstWhere((c) => c.after > c.before);
  expect(victim.before - victim.after, hitter.after - hitter.before); // conserved
});
```
(Write these as concrete seeded scenarios with literal expected numbers derived by hand from the locked rules — no `expect(x, x)` tautologies. Reuse the existing engine-test harness helpers for driving a specific joker hit.)

- [ ] **Step 2:** Run → FAIL (`scoreChanges` not a member). `flutter test test/models/wildcard_engine_test.dart`.
- [ ] **Step 3:** Implement:
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
  - Every OTHER `lastEventResolution` assignment (gift, cursed, freeze, cut, rewind, the "no target" early-returns) gets `scoreChanges: const <WcScoreChange>[]` so the record stays total. (REWIND fills it in Task A2.)
  - `WcScoreChange` is a value record → no undo-snapshot change needed (it lives inside `lastEventResolution`, already snapshotted at field 29).
- [ ] **Step 4:** Run → PASS + `flutter test test/` full suite green + `flutter analyze` clean.
- [ ] **Step 5:** Commit `feat(wildcard): event resolution carries before/after score changes`

---

### Task A2: REWIND resolution carries per-player before/after

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (rewind case `:948-955`; `_executeRewind` `:986`)
- Test: `test/models/wildcard_engine_test.dart`

- [ ] **Step 1: Failing test:**
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
- [ ] **Step 2:** Run → FAIL (`scoreChanges` empty for rewind).
- [ ] **Step 3:** Implement — in the `rewindEvent` case (`:948-955`), capture before/after around the delegate:
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
- [ ] **Step 4:** Run → PASS + full suite green.
- [ ] **Step 5:** Commit `feat(wildcard): REWIND resolution lists per-player score restore`

---

### Task A3: `WcBeforeAfterRows` reveal widget

**Files:**
- Modify: `lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart`
- Test: `test/widgets/dossedart_wildcard_dialogs_test.dart`

**Interfaces (produces):**
```dart
/// One row per involved player: NAME  before → after, delta-tinted.
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

- [ ] **Step 1: Failing tests:**
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
- [ ] **Step 2:** Run → FAIL (widget missing). `flutter test test/widgets/dossedart_wildcard_dialogs_test.dart`.
- [ ] **Step 3:** Implement a `Column` of rows; each row a `Row[ Text(name, PressStart2P 12, accent), Spacer, Text('$before'), Text(' → ', white54), Text('$after') ]`. Tint the `after` value: `after >= before ? DossedartTokens.green : DossedartTokens.red` (both are tokens — palette-compliant). VT323 for the numbers, size ~22. No animations (keep it cheap; the parent dialog already animates in).
- [ ] **Step 4:** Run → PASS + `flutter analyze` clean.
- [ ] **Step 5:** Commit `feat(wildcard): before/after reveal rows widget`

---

### Task A4: Render reveals in event + rewind dialogs; enrich freeze/cut copy

**Files:**
- Modify: `lib/screens/wildcard_game_screen.dart` (`_eventDialog` `:995-1014`; `_rewindDialog` `:1034-1051`; `_cutDialog` `:1016-1032`; helper `_revealRows`)
- Test: `test/screens/wildcard_game_screen_test.dart`

**Interfaces (consumes):** `engine.lastEventResolution.scoreChanges` (Task A1/A2), `WcBeforeAfterRows`/`WcRevealRow` (Task A3), `dossedartAccent(i)` (`:24`), `players[i].name` (`:66`).

- [ ] **Step 1: Failing tests** (WILDCARD screen harness):
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
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement:
  - Add a helper:
    ```dart
    List<WcRevealRow> _revealRows(List<WcScoreChange> changes) => [
      for (final c in changes)
        WcRevealRow(name: players[c.playerIndex].name.toUpperCase(),
            before: c.before, after: c.after, accent: dossedartAccent(c.playerIndex)),
    ];
    ```
  - In `_eventDialog` (`:995-1014`): when `res?.scoreChanges.isNotEmpty == true`, append `WcBeforeAfterRows(rows: _revealRows(res!.scoreChanges))` after the detail `Text`. Keep the mapped `detail` line above it (it becomes the caption, e.g. "ROBIN HOOD" stays as title; detail like "STEAL 50" reads as sub-line). For FREEZE (empty changes) the mapped detail already names the player — change its copy to end `· skipped next turn` by editing the engine detail in the freeze case (`:912`) to `'P$leader FROZEN · skipped next turn (scores 0)'`.
  - In `_rewindDialog` (`:1034-1051`): append `WcBeforeAfterRows(rows: _revealRows(engine.lastEventResolution?.scoreChanges ?? const []))` under the existing copy, so the wipe is shown per player.
  - In `_cutDialog` (`:1016-1032`): CUT! has no `scoreChanges`; name who loses their turn. The engine's cut detail is `'CUT! · round $roundEnding ends'` — extend the engine cut case (`:938-946`) to append the skipped seats: build `flags` naming each player after the current seat this round, and render them as a short "LOSES TURN: X, Y" line via `_mapEventDetail`. (If deriving skipped seats in the engine is awkward, render the line in `_cutDialog` from `engine.currentPlayerIndex`/`ranking()` instead — pick whichever keeps the engine pure; document the choice.)
- [ ] **Step 4:** Run → PASS + full suite green + analyze clean.
- [ ] **Step 5:** Commit `feat(wildcard): event/rewind dialogs show before→after; freeze/cut name who's affected`

**Note for reviewer (flagged in spec review):** GIFT's redirect and CURSED's bite land at *banking*/on-hit, not at the event moment, so they carry no `scoreChanges` here — GIFT shows a "rest of turn → NAME" line (who benefits) and CURSED keeps its hidden "a curse is loose" copy. A CURSED-*hit* reveal would need a new overlay trigger plumbed through `WildcardDartResult`; left out of this plan as likely-intrusive (interrupts the thrower's own turn). Confirm this scoping.

---

## Part B — HEAVY CROWN

### Task B1: `heavyCrown` modifier def + penalty table

**Files:**
- Modify: `lib/models/wildcard_events.dart`
- Test: `test/models/wildcard_events_test.dart`

**Interfaces (produces):**
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

- [ ] **Step 1: Failing tests:**
```dart
test('heavyCrown is not in the random modifier pool', () {
  expect(wcModifiers.any((m) => m.id == 'heavyCrown'), isFalse);
});
test('heavy crown penalty table', () {
  expect(kHeavyCrownPenalty, [0, 20, 40, 80]);
});
```
- [ ] **Step 2:** Run → FAIL. **Step 3:** Add the consts (do NOT add `heavyCrown` to `wcModifiers`). **Step 4:** PASS + analyze.
- [ ] **Step 5:** Commit `feat(wildcard): HEAVY CROWN modifier def + penalty table`

---

### Task B2: Engine — HEAVY CROWN gate in `_rollTurnModifier`

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (`_rollTurnModifier` `:644-680`; forced-lookup `:658-662`; undo fields `:67-130`)
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces (produces):** `debugForceModifier('heavyCrown')` must work (used by screen + tests).

- [ ] **Step 1: Failing tests** (seeded):
```dart
test('HEAVY CROWN never fires before round 4', () {
  final e = plain(players: 2, rounds: 10);
  // Give P0 a >=120 lead in rounds 1-3; assert activeModifier != heavyCrown each turn.
});
test('HEAVY CROWN only targets a leader ahead by >= threshold', () {
  // round >=4, P0 leads by 119 -> never crowned across many seeded rolls;
  // by 120 -> can be crowned (force via a stubbed RNG that passes the chance).
});
test('debugForceModifier heavyCrown sets it as the active modifier', () {
  final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
  e.applyDart(20,1); e.applyDart(20,1); e.applyDart(20,1); // bank P0, roll P1's turn
  expect(e.activeModifier?.id, 'heavyCrown');
});
```
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement in `_rollTurnModifier`:
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
  - Add the gate (checked only in the non-forced path, AFTER the frozen early-return at `:650`, and it bypasses the modifier-cooldown at `:652-655`):
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
    Wire the gate so a crowned turn does NOT also consume the cooldown/normal roll (returning `heavyCrown` from `_rollHeavyCrownOrNull` short-circuits `??`). Note: place the call so it still runs when `_hadModifierLastTurn` is set (crown ignores cooldown) — i.e. move the cooldown check to inside `_rollNormalModifier`, or check the crown before the cooldown return. Document the ordering with a comment.
- [ ] **Step 4:** Run → PASS + full suite green.
- [ ] **Step 5:** Commit `feat(wildcard): HEAVY CROWN gate — round>=4, leader by >=120, chance-gated`

---

### Task B3: Engine — HEAVY CROWN miss penalty at banking

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (`applyDart` true-miss branch `:453-460`; `_bankCurrentTurn` `:590-623`; new field `_missesThisTurn`; undo `:67-130`, `_pushUndo`, `undo`)
- Test: `test/models/wildcard_engine_test.dart`

- [ ] **Step 1: Failing tests:**
```dart
test('HEAVY CROWN: 1/2/3 true misses cost 20/40/80 off the game total', () {
  final e = plain(players: 2, rounds: 10)..debugForceModifier('heavyCrown');
  e.applyDart(20,1); e.applyDart(20,1); e.applyDart(20,1);   // P0 -> 60, banks
  // now P1 under heavyCrown; give P1 a base total first via setup, then miss x3
  // assert totals[P1] dropped by exactly 80 (floored at 0).
});
test('HEAVY CROWN penalty floors at 0', () {
  // small total, 3 misses -> total 0, not negative.
});
test('HEAVY CROWN penalty only counts TRUE misses, not dimmed 0s', () {
  // a scoring dart of 0 via a dim does NOT add to the miss penalty.
});
test('undo across a HEAVY CROWN turn restores the penalty', () { ... });
```
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement:
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
- [ ] **Step 4:** Run → PASS + full suite green + analyze clean.
- [ ] **Step 5:** Commit `feat(wildcard): HEAVY CROWN miss penalty (-20/-40/-80 off total, floor 0), undo-safe`

*(No screen task: `heavyCrown` is `activeModifier != null`, so the existing `_maybeShowAnnounce` announce overlay already shows its icon/name/desc. Add one screen smoke test that a forced heavyCrown turn shows the announce overlay with title `HEAVY CROWN`.)*

---

## Part C — Chaos tuning

### Task C1: Tame the meter loop

**Files:**
- Modify: `lib/models/wildcard_engine.dart` (joker `:474`; triple `:450`; round-start decay after `:699`)
- Test: `test/models/wildcard_engine_test.dart`

**Findings driving this (from the meter path):** joker hit is `+2` (`:474`), a **triple is already `+2`** (`:450`, not +1 as the spec assumed), a double is `+1` (`:451`), first true miss is `-1` (`:458`). The only downward pressure is a rare miss — hence the ratchet.

- [ ] **Step 1: Failing tests:**
```dart
test('joker hit raises the meter by 1 (was 2)', () {
  // force a joker hit at a known chaos level; assert meterDelta contribution +1.
});
test('a triple raises the meter by 1 (was 2)', () {
  final e = plain(); final r = e.applyDart(20, 3);
  expect(r.meterDelta, 1); expect(e.chaos, 1);
});
test('meter decays by 1 at the start of each new round', () {
  final e = plain(players: 1, rounds: 3);   // 1 player -> round advances every turn
  // raise chaos to e.g. 5 via triples, complete a round, assert chaos == prev - 1.
});
test('round-start decay clamps at 0', () { ... });
```
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement:
  - Joker `:474`: `_applyMeterChange(2)` → `_applyMeterChange(1)`.
  - Triple `:450`: `_applyMeterChange(2)` → `_applyMeterChange(1)` (update the `// triple: +2` comment to `+1 (QA5 loop-taming)`).
  - Round-start decay: in `_advancePlayer`, immediately after `roundStartTotals = List.of(totals);` (`:699`), add `_applyMeterChange(-1); // QA5: cool the meter between rounds`. (Only the normal round-advance path decays; CUT!/REWIND round changes deliberately do NOT — they're chaos events.)
  - Double stays `+1`.
- [ ] **Step 4:** Run → PASS + full suite green. Update any existing engine test that asserted the old `+2` triple/joker values (search the test file for `meterDelta, 2` / chaos assertions and re-derive).
- [ ] **Step 5:** Commit `feat(wildcard): tame chaos loop — joker +1, triple +1, -1 round-start decay`

**Note for reviewer:** these four numbers are the tunable defaults from the spec; recalibrate on tablet QA. Triple `+2→+1` was added on top of the spec (the spec assumed triple was already +1) — flag if you want triple kept at +2.

---

## Verification

- [ ] `flutter analyze` → 0 issues; `flutter test test/` → all green.
- [ ] Manual tablet pass: force each reveal (swap/robin/gift/freeze/rewind/cut) via dev override and confirm before→after / who's-affected reads clearly; force HEAVY CROWN and confirm the announce + a 3-miss turn dents the total by 80; play a full game and confirm chaos no longer pins at 9–10.
- [ ] superpowers:requesting-code-review against the spec (engine↔screen contract, undo across HEAVY CROWN + reveals, floor-0 everywhere, tokens-only).
- [ ] Hold for Bjørn: push/PR on his signal.

## Self-review notes (applied)

- Spec Part 1 (reveals) → A1–A4; Part 2 (HEAVY CROWN) → B1–B3; Part 3 (chaos tuning) → C1. Part 4 (logging) is a SEPARATE plan (`2026-07-13-cross-mode-logging-pass.md`).
- Deviations flagged inline: GIFT/CURSED reveal scoping (A4 note); triple +2→+1 beyond spec (C1 note); CUT! skipped-seat derivation location (A4).
- Type consistency: `WcScoreChange`/`WcRevealRow` names used identically in A1/A3/A4; `kHeavyCrownPenalty`/`kHeavyCrownLeadThreshold`/`kHeavyCrownChancePct` defined in B1, consumed in B2/B3; `_missesThisTurn` introduced in B3 and added to undo in the same task.
