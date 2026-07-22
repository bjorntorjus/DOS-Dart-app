# Audit Round 5 — Structure & Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kill the flaky test hang for good (F18), delete the four dead widgets (F25), close the highest-risk test gaps — Elo, StatsRecorder, checkout table, Splitscore halving, PlayerStorage corruption (F20) — and wire the orphan Cricket engine into production following the Shanghai pattern (F19).

**Architecture:** F18 uses the existing `ArcadeFrame.disableBeamForTest` static-flag pattern on `VideoService` and `BatterySampler`, activated once globally via a new `test/flutter_test_config.dart`. F19 follows the proven Shanghai fasit: the engine owns all rules state including undo and roster mutation; the screen keeps only presentation state (`throwHistory`, `_turnIdCounter`, audio/meme) and re-derives display from the engine. The engine moves to `lib/models/` where `shanghai_engine.dart` lives.

**Tech Stack:** Flutter (Dart), flutter_test (`flutter_test_config.dart` global wrapper, platform-channel stubs, SharedPreferences mocks).

## Global Constraints

- Branch: `fix/dossedart-x01-cockpit-fixes` (release train). Commit per task, **do not push** — CI runs when Bjørn says so.
- `flutter analyze` must report 0 issues after every task.
- Package import prefix: `package:dart_scoring/...`.
- End every commit message with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- After Task 1 lands, the full `flutter test` suite is expected to be hang-free; from Task 2 onward run `flutter test` (whole suite) as the pre-commit verification instead of per-directory batches.
- F19 regression contract: the cricket screen's `@visibleForTesting` hooks must keep IDENTICAL names and semantics (`registerHitForTest`, `undoForTest`, `addPlayerForTest`, `removePlayerForTest`, `finishedPlayersForTest`, `removedPlayerIndicesForTest`, `currentPlayerIndexForTest`, `winnerIndexForTest`, `computeWinnerForTest`, `buildGameResultForTest`) plus the public `throwHistory` field — four existing test files pin them.
- The existing engine test's public surface must survive: `marks`, `scores`, `finishedPlayers`, `currentPlayerIndex`, `dartsInTurn`, `gameOver`, `winnerIndex` fields and `applyHit`, `checkFinishForPlayer`, `computeOverflow`, `isClosed`, `isClosedByAll`, `allClosedByPlayer` signatures.
- EloService's tunables are STATIC and process-wide: unit tests must not call `EloService.loadSettings()` (it would leak state between tests); the compile-time defaults are K-new 32.0, K-exp 16.0, threshold 20.

## Decisions baked into this plan (flag to Bjørn if he objects)

1. **F29 (Elo guest-scaling) is characterized, not changed:** `scale = 1/(n-1)` counts guests, so a 2-saved+2-guest game moves ratings ~1/3 as much. This matches the doc comment; the new test locks CURRENT behavior with a comment naming F29 so a future product decision has a test to flip.
2. **PlayerStorage gets the F14 hardening** (try/catch + corrupt-backup key), not just tests — audit F14 explicitly said "same pattern worth checking in player_storage.dart", and saved players carry the ratings.
3. **CricketEngine relocates to `lib/models/cricket_engine.dart`** (test to `test/models/`), matching the Shanghai fasit. `lib/engines/x01_engine.dart` and `atc_engine.dart` stay where they are as documented orphans for a future round.
4. **Engine clears its undo stack on any roster change** (Shanghai pattern). This makes the screen's F9 removed-player re-assertion after undo unnecessary — undo can never cross a roster change.

---

### Task 1: F18 — kill the test hang (test flags + global test config + canary)

**Files:**
- Modify: `lib/services/video_service.dart` (~line 14 area)
- Modify: `lib/services/battery_sampler.dart` (~lines 13-26)
- Create: `test/flutter_test_config.dart`
- Test: `test/services/video_service_disable_test.dart` (create), `test/screens/x01_pump_and_settle_canary_test.dart` (create)

**Interfaces:**
- Consumes: existing `ArcadeFrame.disableBeamForTest` static flag (`lib/widgets/dossedart/arcade_frame.dart:20-21`).
- Produces: `VideoService.disableForTest` and `BatterySampler.disableForTest` — `@visibleForTesting static bool`, default `false`. `test/flutter_test_config.dart` sets all three flags for every test under `test/`.

Background: `VideoService._enabled` defaults `true`; `GameAnnouncer.init()` re-reads prefs asynchronously, so a plain `setEnabled(false)` in a config can be overwritten mid-test. A static flag checked at show-time is immune. `BatterySampler` has a 30s `Timer.periodic` started in every game screen's initState; `ArcadeFrame` has a 35s one (already flagged). Any of the three makes `pumpAndSettle` spin to its 10-minute timeout.

- [ ] **Step 1: Write the failing unit test**

```dart
// test/services/video_service_disable_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/video_service.dart';

/// F18 (audit 2026-07-06): VideoService is enabled by default and its
/// prefs re-read can re-enable it mid-test. The static test flag must
/// short-circuit showing regardless of _enabled.
void main() {
  testWidgets('disableForTest suppresses the overlay even when enabled',
      (tester) async {
    VideoService.instance.setEnabled(true);
    VideoService.disableForTest = true;
    addTearDown(() => VideoService.disableForTest = false);

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    await VideoService.instance.showRandomFromFolder(ctx, 'winner');
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (`disableForTest` is not defined): `flutter test test/services/video_service_disable_test.dart`

- [ ] **Step 3: Add the flags**

`lib/services/video_service.dart` — next to `_enabled`:

```dart
  /// F18: hard off-switch for tests. Checked at show-time so the async
  /// prefs re-read in init() cannot re-enable videos mid-test.
  @visibleForTesting
  static bool disableForTest = false;
```

and as the FIRST line of both `showRandomFromFolder` and `showVideo`:

```dart
    if (disableForTest) return;
```

(Add `import 'package:flutter/foundation.dart';` if not present.)

`lib/services/battery_sampler.dart` — same pattern:

```dart
  /// F18: prevents the 30s periodic timer from blocking pumpAndSettle.
  @visibleForTesting
  static bool disableForTest = false;
```

and first line of `start(...)`: `if (disableForTest) return;`

- [ ] **Step 4: Create the global test config**

```dart
// test/flutter_test_config.dart
import 'dart:async';

import 'package:dart_scoring/services/battery_sampler.dart';
import 'package:dart_scoring/services/video_service.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Applied automatically by flutter_test to EVERY test under test/.
/// Neutralizes the three unbounded-timer sources that made pumpAndSettle
/// hang for up to 10 minutes (audit F18): the VideoOverlay spinner, the
/// 35s ArcadeFrame beam and the 30s BatterySampler tick.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VideoService.disableForTest = true;
  ArcadeFrame.disableBeamForTest = true;
  BatterySampler.disableForTest = true;
  await testMain();
}
```

Check `test/widgets/dossedart/dossedart_crt_frame_test.dart` — it resets `disableBeamForTest = false` in tearDown; change that tearDown to reset it to `true` (the new global baseline) so it doesn't leak a beam into later tests in the same file run.

- [ ] **Step 5: Canary test**

```dart
// test/screens/x01_pump_and_settle_canary_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F18 canary: pumpAndSettle on a live game screen must terminate.
/// Before the global test config this hung 1-in-N runs (RNG video roll).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TtsService.instance.resetForTesting();
  });
  tearDown(() => TtsService.instance.resetForTesting());

  testWidgets('pumpAndSettle terminates after throws on X01', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501), Player(name: 'P1', score: 501)],
        startingScore: 501,
        masterOut: 'double',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final dynamic state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    for (var i = 0; i < 6; i++) {
      await state.onDartHitForTest(20, 1);
      await tester.pump();
    }
    await tester.pumpAndSettle(); // must terminate — that IS the assertion
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
```

- [ ] **Step 6: Verify**

Run: `flutter test test/services/video_service_disable_test.dart test/screens/x01_pump_and_settle_canary_test.dart` → PASS.
Run the FULL suite: `flutter test` → all pass, no hang (this is the first full-suite run the project can trust; if a specific file still hangs, fix its cause the same flag way and note it in the report).
Run: `flutter analyze` → 0 issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/video_service.dart lib/services/battery_sampler.dart test/flutter_test_config.dart test/services/video_service_disable_test.dart test/screens/x01_pump_and_settle_canary_test.dart test/widgets/dossedart/dossedart_crt_frame_test.dart
git commit -m "fix(test): global test config neutralizes video overlay + periodic timers (F18)"
```

---

### Task 2: F25 — delete the four dead widgets

**Files:**
- Delete: `lib/widgets/checkout_widget.dart`, `lib/widgets/clock_progress.dart`, `lib/widgets/cricket_scoreboard.dart`, `lib/widgets/halve_it_scoreboard.dart`
- Modify: `test/design/color_role_guard_test.dart:9-17` (shrink allowlist)

**Interfaces:** none produced; verified zero references in lib/, test/ (only the guard allowlist mentions them).

⚠️ One nuance: `checkout_widget.dart` consumes `checkoutTable`/`straightOutCheckout` from `lib/data/checkout_table.dart` — the TABLE stays (X01's `game_screen.dart:1166-1171` uses it); only the widget dies.

- [ ] **Step 1: Delete the four files** (`git rm lib/widgets/checkout_widget.dart lib/widgets/clock_progress.dart lib/widgets/cricket_scoreboard.dart lib/widgets/halve_it_scoreboard.dart`)

- [ ] **Step 2: Shrink the guard allowlist** — remove the four `lib/widgets/...` lines and the `// Dead widgets — deleted in audit Round 5 (F25), not worth fixing:` comment, leaving:

```dart
  const allowlist = <String>{
    'lib/utils/player_colors.dart', // avatar palette
    'lib/widgets/heatmap_board.dart', // data-viz gradient
  };
```

- [ ] **Step 3: Verify** — `flutter analyze` → 0 issues (proves nothing referenced them); `flutter test` → all pass.

- [ ] **Step 4: Commit**

```bash
git add -A lib/widgets test/design/color_role_guard_test.dart
git commit -m "chore: delete four dead widgets and shrink the color-guard allowlist (F25)"
```

---

### Task 3: F20a — EloService unit tests

**Files:**
- Test: `test/services/elo_service_test.dart` (create)

**Interfaces:**
- Consumes: `EloService.kFactor(int)`, `EloService.updateRatings({playerIds, placements, savedPlayers})`, `SavedPlayer(id:, name:, createdAt:, rating:, gamesPlayed:)`. Do NOT call `EloService.loadSettings()` (static-state leak). Defaults: K-new 32, K-exp 16, threshold 20, floor 100, default rating 1200.

These are characterization tests of current behavior — expected to pass without production changes; a failure is a real Elo bug to escalate (BLOCKED), not silently fix.

- [ ] **Step 1: Write the tests**

```dart
// test/services/elo_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/elo_service.dart';

/// F20 (audit 2026-07-06): the app's headline number had zero tests.
/// These characterize EloService with its compile-time defaults
/// (K-new 32, K-exp 16, threshold 20, floor 100). loadSettings() is
/// deliberately never called — it mutates process-wide static state.
void main() {
  SavedPlayer sp(String id, {double rating = 1200, int games = 0}) =>
      SavedPlayer(id: id, name: id, createdAt: DateTime(2020))
        ..rating = rating
        ..gamesPlayed = games;

  group('kFactor', () {
    test('new player (< 20 games) gets K=32', () {
      expect(EloService.kFactor(0), 32.0);
      expect(EloService.kFactor(19), 32.0);
    });
    test('experienced player (>= 20 games) gets K=16', () {
      expect(EloService.kFactor(20), 16.0);
      expect(EloService.kFactor(500), 16.0);
    });
  });

  group('updateRatings — two equal players', () {
    test('winner +16, loser -16 at default K (zero-sum)', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        playerIds: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.rating, closeTo(1216, 0.001));
      expect(b.rating, closeTo(1184, 0.001));
    });

    test('draw moves nothing', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        playerIds: ['a', 'b'],
        placements: [1, 1],
        savedPlayers: [a, b],
      );
      expect(a.rating, 1200);
      expect(b.rating, 1200);
    });
  });

  test('each player uses their OWN K — asymmetric deltas', () {
    final newbie = sp('n', games: 0); // K=32
    final vet = sp('v', games: 100); // K=16
    EloService.updateRatings(
      playerIds: ['n', 'v'],
      placements: [1, 2],
      savedPlayers: [newbie, vet],
    );
    expect(newbie.rating, closeTo(1216, 0.001)); // 32 * 0.5
    expect(vet.rating, closeTo(1192, 0.001)); // 16 * 0.5
  });

  test('rating floor: a heavy loss never drops a player below 100', () {
    // Losing to an evenly-matched opponent costs ~16 points; from 105
    // that lands at ~88.8, which the floor clamps to 100. (A loss to a
    // much higher-rated player costs almost nothing — expected score ≈ 0 —
    // so that scenario cannot exercise the floor.)
    final low = sp('low', rating: 105), weak = sp('weak', rating: 100);
    EloService.updateRatings(
      playerIds: ['low', 'weak'],
      placements: [2, 1],
      savedPlayers: [low, weak],
    );
    expect(low.rating, 100);
    expect(weak.rating, greaterThan(100)); // winner still gains normally
  });

  group('guests', () {
    test('a game with fewer than two saved players changes nothing', () {
      final a = sp('a');
      EloService.updateRatings(
        playerIds: ['a', null, null],
        placements: [1, 2, 3],
        savedPlayers: [a],
      );
      expect(a.rating, 1200);
    });

    test('F29 characterization: guests dilute the 1/(n-1) scale', () {
      // 2 saved + 2 guests: scale = 1/3 instead of 1/1, so the single
      // saved-vs-saved pair moves ratings a third as much as a pure
      // 2-player game. This matches the doc comment on updateRatings;
      // audit F29 questions whether guests SHOULD count in the divisor.
      // If that product decision changes, flip this expectation.
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        playerIds: ['a', null, 'b', null],
        placements: [1, 2, 3, 4],
        savedPlayers: [a, b],
      );
      expect(a.rating, closeTo(1200 + 16.0 / 3, 0.001));
      expect(b.rating, closeTo(1200 - 16.0 / 3, 0.001));
    });
  });

  test('unknown ids are treated as guests', () {
    final a = sp('a');
    EloService.updateRatings(
      playerIds: ['a', 'ghost'],
      placements: [1, 2],
      savedPlayers: [a],
    );
    expect(a.rating, 1200);
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/services/elo_service_test.dart` → PASS expected (characterization). If a test fails, report BLOCKED with the exact failure — that is a live Elo bug for Bjørn, not something to patch silently.

- [ ] **Step 3: Verify + commit** — `flutter analyze` → 0.

```bash
git add test/services/elo_service_test.dart
git commit -m "test(elo): characterize K-factor, deltas, floor, guest scaling (F20/F29)"
```

---

### Task 4: F20b — StatsRecorder tests (H2H, rating history, max:/min: merge)

**Files:**
- Test: `test/services/stats_recorder_h2h_test.dart` (create)

**Interfaces:**
- Consumes: `StatsRecorder.recordGame(gameMode:, playerIds:, playerNames:, placements:, savedPlayers:, modeCounters:)`; `SavedPlayer.headToHead` (`Map<String, H2HRecord>` with `wins/losses/draws`), `SavedPlayer.ratingHistory` (`List<RatingSnapshot>` with `rating`, `placement`), `ModeStats.get(key)`. Mirror the harness style of `test/services/streak_tracking_test.dart` (local `sp()` factory + `play()` wrapper; `SharedPreferences.setMockInitialValues({})` in setUp; `TestWidgetsFlutterBinding.ensureInitialized()`).

Cover exactly these behaviors (write one `test()` per bullet, following the harness):

1. **H2H accumulation:** three games between `a` and `b` — a wins, b wins, draw ([1,1]) → `a.headToHead['b']` is wins 1 / losses 1 / draws 1, and `b.headToHead['a']` mirrors it (1/1/1).
2. **H2H skips guests:** a game `['a', null]` leaves `a.headToHead` empty.
3. **Shared best placement = draw, nobody gets `won`:** placements [1,1,2] → neither leader's `modeStats['x01'].won` increments; third player's loss streak increments.
4. **Rating-history snapshot:** after two `recordGame` calls, `a.ratingHistory.length == 2`, each snapshot's `rating` equals `a.rating` at call time, and `placement` is a's 1-based rank by rating among ALL passed savedPlayers (construct three players with distinct ratings and assert the middle one gets placement 2).
5. **Counter merge:** two games with `modeCounters: {'a': {'max:biggestHalving': X, 'min:bestLeg': Y, 'doublesHit': Z}}` — `max:` keeps the larger across games, `min:` keeps the smaller (and first real value wins over unset 0), plain key sums. Assert via `modeStats['halveIt'].get('biggestHalving')` etc. after game one AND game two.

- [ ] **Step 1: Write the tests** per the list above (complete `recordGame` calls with all required params; `gameMode: 'x01'` except the counter test which uses `'halveIt'`).
- [ ] **Step 2: Run** — `flutter test test/services/stats_recorder_h2h_test.dart` → PASS expected (characterization; failures = BLOCKED escalation).
- [ ] **Step 3: Verify + commit** — `flutter analyze` → 0.

```bash
git add test/services/stats_recorder_h2h_test.dart
git commit -m "test(stats): lock H2H, rating-history snapshots and max/min counter merge (F20)"
```

---

### Task 5: F20c — checkout-table validation + Splitscore halving tests

**Files:**
- Test: `test/data/checkout_table_test.dart` (create)
- Test: `test/screens/halve_it_halving_test.dart` (create)

**Interfaces:**
- Consumes: `checkoutTable` (`Map<int, String>`, labels `S<n>`/`D<n>`/`T<n>`/`Bull`), `straightOutCheckout(int)` from `package:dart_scoring/data/checkout_table.dart`; Splitscore hooks `onDartHitForTest(segment, multiplier)`, `totalScoresForTest`, `currentPlayerIndexForTest`, `currentRoundIndexForTest` on `HalveItGameScreen`'s state.

- [ ] **Step 1: checkout-table test**

```dart
// test/data/checkout_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/checkout_table.dart';

/// F20 (audit 2026-07-06): 257 lines of checkout data had no test that
/// suggestions are legal, sum correctly, and end on a double.
int _dartPoints(String label, {required bool isLast}) {
  if (label == 'Bull') {
    // 'Bull' is overloaded: as the FINAL dart of a double-out combo it is
    // the double bull (50); table entries never use it as a 25 setup dart
    // except where the sum proves otherwise — resolve by trying 50 first
    // in the caller. Here we just signal with a negative marker.
    throw StateError('Bull handled by caller');
  }
  final kind = label[0];
  final n = int.parse(label.substring(1));
  if (n < 1 || n > 20) fail('illegal segment in "$label"');
  switch (kind) {
    case 'S':
      return n;
    case 'D':
      return 2 * n;
    case 'T':
      return 3 * n;
    default:
      fail('illegal dart label "$label"');
  }
}

/// Returns every possible total for a combo, accounting for Bull = 25 or 50.
List<int> _possibleTotals(List<String> darts) {
  var totals = <int>[0];
  for (final d in darts) {
    final opts = d == 'Bull' ? [25, 50] : [_dartPoints(d, isLast: false)];
    totals = [for (final t in totals) for (final o in opts) t + o];
  }
  return totals;
}

void main() {
  test('every entry is legal, sums to its key, and ends on a double', () {
    expect(checkoutTable, isNotEmpty);
    checkoutTable.forEach((score, combo) {
      final darts = combo.split(' ');
      expect(darts.length, inInclusiveRange(1, 3),
          reason: '$score: "$combo" has ${darts.length} darts');
      // Last dart must be a double: D<n> or Bull-as-50.
      final last = darts.last;
      expect(last == 'Bull' || last.startsWith('D'), isTrue,
          reason: '$score: "$combo" does not end on a double');
      // Sum: at least one Bull-resolution must hit the key, and the
      // resolution must use Bull=50 for the final dart.
      final totals = _possibleTotals(darts);
      expect(totals, contains(score),
          reason: '$score: "$combo" cannot sum to $score');
      if (last == 'Bull') {
        final headTotals = _possibleTotals(darts.sublist(0, darts.length - 1));
        expect(headTotals, contains(score - 50),
            reason: '$score: "$combo" must finish on the DOUBLE bull (50)');
      }
    });
  });

  test('bogey numbers are absent by design', () {
    for (final bogey in [159, 162, 163, 165, 166, 168, 169]) {
      expect(checkoutTable.containsKey(bogey), isFalse,
          reason: '$bogey is a classic impossible double-out');
    }
    expect(checkoutTable.containsKey(170), isTrue);
    expect(checkoutTable.containsKey(2), isTrue);
  });

  group('straightOutCheckout', () {
    test('null out of range', () {
      expect(straightOutCheckout(0), isNull);
      expect(straightOutCheckout(-5), isNull);
      expect(straightOutCheckout(181), isNull);
    });
    test('suggestions sum to the score for 1..180', () {
      for (var score = 1; score <= 180; score++) {
        final combo = straightOutCheckout(score);
        expect(combo, isNotNull, reason: 'no straight-out for $score');
        expect(_possibleTotals(combo!.split(' ')), contains(score),
            reason: '$score: "$combo" does not sum');
      }
    });
  });
}
```

(If a table entry genuinely fails, that is REAL data corruption — fix the single entry to the standard checkout for that score and call it out in the report; do not weaken the test.)

- [ ] **Step 2: Splitscore halving widget test** — mirror the pump/setup of `test/screens/halve_it_keypad_test.dart` (its `_pumpSplitscore` helper: players + `HalveItConfig`; copy the channel stubs it uses). Then:

```dart
// test/screens/halve_it_halving_test.dart  (setup copied from halve_it_keypad_test.dart)
// Test 1: miss the round target for all three darts of P1's turn via
// onDartHitForTest(<segment that is NOT the round target>, 1) after first
// banking some points in earlier turns is unnecessary — start simple:
//   - P1 hits the round-1 target once (score > 0), turn ends after 3 darts.
//   - Next round(s): make P1 MISS all 3 darts → assert
//     totalScoresForTest[0] == before ~/ 2  (floor division: 45 -> 22).
// Test 2: halving an odd score floors (seed an odd total first, e.g. via
// single hits summing odd, then miss a full turn and assert score ~/ 2).
// Read the round target via the state's config/rounds getters — the keypad
// test shows how rounds are laid out; segment 0 (miss button) with
// multiplier 0 via onDartHitForTest(0, 0) is a guaranteed miss.
```

Write the two `testWidgets` concretely against the real hooks (`onDartHitForTest`, `totalScoresForTest`, `currentRoundIndexForTest`); the implementer reads `halve_it_keypad_test.dart` and `halve_it_game_screen.dart:292-308` (`_finishTurn`) to pick a deterministic round-target/miss sequence. Assert BOTH the halved total (`~/ 2`) and, via `buildGameResultForTest()` or the round-scores surface if exposed, that a halved round is recorded as the negative amount lost (the `-lost` sentinel) — if no hook exposes round cells, assert only the total and note it.

- [ ] **Step 3: Run** — `flutter test test/data/checkout_table_test.dart test/screens/halve_it_halving_test.dart` → PASS.
- [ ] **Step 4: Verify + commit** — `flutter analyze` → 0; `flutter test` → green.

```bash
git add test/data/checkout_table_test.dart test/screens/halve_it_halving_test.dart
git commit -m "test(data,splitscore): validate checkout table; lock the halving rule (F20)"
```

---

### Task 6: F20d — PlayerStorage corrupt-JSON hardening (F14 pattern)

**Files:**
- Modify: `lib/services/player_storage.dart:8-16`
- Test: `test/services/player_storage_corrupt_test.dart` (create)

**Interfaces:**
- Consumes: the F14 reference implementation in `lib/services/game_history_service.dart:6-33` (`_corruptKey` backup + `lastLoadFailed` flag) and its test `test/services/game_history_corrupt_test.dart`.
- Produces: `PlayerStorage.lastLoadFailed` (static bool) and backup key `'saved_players_corrupt'`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/player_storage_corrupt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';

/// F14/F20 (audit 2026-07-06): a corrupt saved_players blob must not crash
/// the app or be silently lost — mirror game_history_service's backup-key
/// pattern. Legacy JSON with missing optional fields must load with defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt JSON returns [] and preserves the raw blob', () async {
    const raw = '{ this is not valid json ]';
    SharedPreferences.setMockInitialValues({'saved_players': raw});

    final players = await PlayerStorage.loadPlayers();

    expect(players, isEmpty);
    expect(PlayerStorage.lastLoadFailed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_players_corrupt'), raw,
        reason: 'raw data must be preserved for recovery, not discarded');
  });

  test('legacy JSON without newer fields loads with defaults', () async {
    const legacy =
        '[{"id":"p1","name":"Old Timer","createdAt":"2024-01-01T00:00:00.000"}]';
    SharedPreferences.setMockInitialValues({'saved_players': legacy});

    final players = await PlayerStorage.loadPlayers();

    expect(PlayerStorage.lastLoadFailed, isFalse);
    expect(players, hasLength(1));
    final p = players.first;
    expect(p.rating, 1200.0);
    expect(p.modeStats, isEmpty);
    expect(p.headToHead, isEmpty);
    expect(p.ratingHistory, isEmpty);
    expect(p.currentWinStreak, 0);
  });

  test('healthy load resets lastLoadFailed', () async {
    SharedPreferences.setMockInitialValues({'saved_players': '[]'});
    await PlayerStorage.loadPlayers();
    expect(PlayerStorage.lastLoadFailed, isFalse);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`lastLoadFailed` undefined / corrupt input throws).

- [ ] **Step 3: Implement** in `player_storage.dart`, mirroring game_history_service verbatim in style:

```dart
  static const String _corruptKey = 'saved_players_corrupt';

  /// True when the last [loadPlayers] hit undecodable data (audit F14).
  static bool lastLoadFailed = false;

  static Future<List<SavedPlayer>> loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) {
      lastLoadFailed = false;
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final players = jsonList
          .map((j) => SavedPlayer.fromJson(j as Map<String, dynamic>))
          .toList();
      lastLoadFailed = false;
      return players;
    } catch (_) {
      // Preserve the unparseable blob instead of losing every player and
      // rating on the next save (audit 2026-07-06, F14 pattern).
      lastLoadFailed = true;
      await prefs.setString(_corruptKey, jsonStr);
      return [];
    }
  }
```

- [ ] **Step 4: Run → PASS; then `flutter test` full suite + `flutter analyze`** (callers of loadPlayers must be unaffected — same signature).

- [ ] **Step 5: Commit**

```bash
git add lib/services/player_storage.dart test/services/player_storage_corrupt_test.dart
git commit -m "fix(storage): preserve corrupt saved_players blob instead of throwing (F14/F20)"
```

---

### Task 7: F19a — grow CricketEngine (undo, roster, safety) and relocate to lib/models/

**Files:**
- Move: `lib/engines/cricket_engine.dart` → `lib/models/cricket_engine.dart` (git mv, then edit)
- Move: `test/engines/cricket_engine_test.dart` → `test/models/cricket_engine_test.dart` (git mv, update import)
- Test: extend `test/models/cricket_engine_test.dart` with new groups

**Interfaces:**
- Consumes: existing engine API (constructor `CricketEngine({required targets, required isCutthroat, required playerCount})`, fields `marks/scores/finishedPlayers/currentPlayerIndex/dartsInTurn/gameOver/winnerIndex`, methods `applyHit/checkFinishForPlayer/computeOverflow/isClosed/isClosedByAll/allClosedByPlayer`) — ALL preserved unchanged.
- Produces (Task 8 relies on these exact names):
  - `bool get canUndo`
  - `void undo()` — restores the full pre-dart state (marks deep copy, scores, finishedPlayers, currentPlayerIndex, dartsInTurn, gameOver, winnerIndex)
  - `void clearUndoStack()`
  - `void addPlayer()` — grows `marks` (fresh `{target: 0}` map) and `scores` (0), clears the undo stack
  - `void removePlayer(int index)` — adds to `_skipped` and (if absent) to `finishedPlayers`, advances off the player when current, sets `gameOver = true` when `activePlayerCount <= 1`, clears the undo stack
  - `bool isSkipped(int index)` / `Set<int> get skippedIndices`
  - `int get activePlayerCount` — players neither finished nor skipped
  - `int? winnerIndexExcludingSkipped()` — first entry of `finishedPlayers` not in `_skipped`, else null
- Constructor change: `marks`/`scores` become GROWABLE (`List.generate(playerCount, ...)` — do not use `List.filled`).

Design notes (the Shanghai fasit, `lib/models/shanghai_engine.dart`):
- Undo = internal snapshot stack pushed at the TOP of `applyHit` (before any mutation). Snapshot class `_CricketUndoEntry` holds deep copies: `List<Map<int,int>>.generate(marks.length, (i) => Map.of(marks[i]))`, `List.of(scores)`, `List.of(finishedPlayers)`, plus the four scalars.
- Roster changes clear the undo stack (decision 4 in the header) — undo can never cross an add/remove.
- `_advancePlayer` gets the wrap-guard the screen has (`cricket_game_screen.dart:359-380`): break when the scan wraps to its start index; also skip `_skipped` players. The current engine do/while (`:151-155`) infinite-loops when everyone is finished — that is the F7 bug being retired.
- `checkFinishForPlayer` must ignore skipped players exactly the way the screen's `_checkWinner` (`cricket_game_screen.dart:141-172`) does — read that method and port its comparison set (opponent scores / all-closed checks exclude removed players). The existing engine tests must still pass; the new behavior only differs when `_skipped` is non-empty.

- [ ] **Step 1: git mv both files, update the test's import** to `package:dart_scoring/models/cricket_engine.dart`, run `flutter test test/models/cricket_engine_test.dart` → existing tests PASS (pure relocation).
- [ ] **Step 2: Write the failing tests for the new API** — add groups to `test/models/cricket_engine_test.dart`:

```dart
  group('undo', () {
    test('undo restores marks, scores, rotation and dartsInTurn', () {
      final e = CricketEngine(targets: [20, 19, 25], isCutthroat: false, playerCount: 2);
      expect(e.canUndo, isFalse);
      e.applyHit(20, 3); // close 20
      e.applyHit(20, 1); // overflow +20
      expect(e.scores[0], 20);
      e.undo();
      expect(e.scores[0], 0);
      expect(e.marks[0][20], 3);
      expect(e.dartsInTurn, 1);
      e.undo();
      expect(e.marks[0][20], 0);
      expect(e.canUndo, isFalse);
    });

    test('undo across a turn boundary restores the previous player', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 2);
      e.applyHit(5, 1);
      e.applyHit(5, 1);
      e.applyHit(5, 1); // turn ends -> player 1
      expect(e.currentPlayerIndex, 1);
      e.undo();
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 2);
    });

    test('undo restores a finish (finishedPlayers/gameOver/winnerIndex)', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 2);
      e.marks[0][20] = 2;
      e.scores[0] = 100;
      e.applyHit(20, 1); // closes last target with higher score -> finishes
      expect(e.finishedPlayers, contains(0));
      e.undo();
      expect(e.finishedPlayers, isEmpty);
      expect(e.gameOver, isFalse);
      expect(e.winnerIndex, isNull);
    });
  });

  group('roster', () {
    test('addPlayer grows state and clears undo', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 2);
      e.applyHit(20, 1);
      expect(e.canUndo, isTrue);
      e.addPlayer();
      expect(e.scores.length, 3);
      expect(e.marks.length, 3);
      expect(e.marks[2][20], 0);
      expect(e.canUndo, isFalse);
    });

    test('removePlayer marks skipped+finished, advances, clears undo', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 3);
      e.applyHit(20, 1);
      e.removePlayer(0); // current player removed
      expect(e.isSkipped(0), isTrue);
      expect(e.finishedPlayers, contains(0));
      expect(e.currentPlayerIndex, isNot(0));
      expect(e.canUndo, isFalse);
      expect(e.activePlayerCount, 2);
      expect(e.gameOver, isFalse);
    });

    test('removal down to one active player ends the game (F7)', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 3);
      e.removePlayer(1);
      e.removePlayer(2);
      expect(e.gameOver, isTrue);
    });

    test('rotation skips removed players without looping (F7)', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 3);
      e.removePlayer(1); // two active remain: 0 and 2
      expect(e.currentPlayerIndex, 0);
      e.applyHit(5, 1);
      e.applyHit(5, 1);
      e.applyHit(5, 1); // turn ends -> must skip removed 1, land on 2
      expect(e.currentPlayerIndex, 2);
      e.applyHit(5, 1);
      e.applyHit(5, 1);
      e.applyHit(5, 1); // wraps back to 0 — and must not hang doing it
      expect(e.currentPlayerIndex, 0);
    });

    test('winnerIndexExcludingSkipped skips removed players', () {
      final e = CricketEngine(targets: [20], isCutthroat: false, playerCount: 3);
      e.removePlayer(0); // goes into finishedPlayers first
      e.finishedPlayers.add(1); // real finisher
      expect(e.winnerIndexExcludingSkipped(), 1);
    });
  });
```

- [ ] **Step 3: Run — expect FAIL** (undo/addPlayer/removePlayer undefined).
- [ ] **Step 4: Implement** the new API per the design notes (snapshot push at top of `applyHit`; growable lists; wrap-guarded `_advancePlayer` skipping finished+skipped; `removePlayer` semantics matching `cricket_game_screen.dart:1765-1795`; skipped-aware `checkFinishForPlayer` matching `:141-172`).
- [ ] **Step 5: Run → all engine tests (old + new) PASS.** `flutter analyze` → 0.
- [ ] **Step 6: Commit**

```bash
git add -A lib/engines lib/models/cricket_engine.dart test/
git commit -m "feat(cricket): engine gains undo, roster mutation and safe rotation; moves to models/ (F19)"
```

---

### Task 8: F19b — wire cricket_game_screen.dart to the engine

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` (major)
- Regression net (must pass UNCHANGED): `test/models/cricket_engine_test.dart`, `test/screens/cricket_turn_id_test.dart`, `test/screens/midgame_roster_rules_test.dart`, `test/screens/removed_player_winner_test.dart`, `test/screens/classic_menu_audio_test.dart` + full suite.

**Interfaces:**
- Consumes: the Task-7 engine API exactly as named there.
- Produces: a screen where ALL rules state lives in the engine. The screen keeps: `players` (names/avatars), `throwHistory` + `_turnIdCounter` (stats/labels), `lastThrowLabel`, `_gameFullyOver` + post-game flow, roster STAT sets (`_joinedMidGameIds`, `_leftMidGameIds`, `_midGamePlayerChanges`), audio/meme/announcer/logging.

Follow the Shanghai wiring (`shanghai_game_screen.dart` — engine field 53-57, `_onHit` 185-251, `_onUndo` 504-528, roster 596-648) step by step:

- [ ] **Step 1: Engine field + delegating views.** Add `late CricketEngine engine;` created in `initState` from `targets`, `widget.config.isCutthroat`, `players.length`. DELETE the screen fields `marks`, `scores`, `currentPlayerIndex`, `dartsInTurn`, `finishedPlayers`, `winnerIndex`, `_removedPlayerIndices`, `_undoStack` and the `_CricketUndoData` class. To keep the 1800-line UI code compiling without touching every read, add delegating getters with the SAME names:

```dart
  List<Map<int, int>> get marks => engine.marks;
  List<int> get scores => engine.scores;
  int get currentPlayerIndex => engine.currentPlayerIndex;
  int get dartsInTurn => engine.dartsInTurn;
  List<int> get finishedPlayers => engine.finishedPlayers;
  int? get winnerIndex => engine.winnerIndexExcludingSkipped();
  Set<int> get _removedPlayerIndices => engine.skippedIndices;
```

(Any remaining WRITE to these names is a compile error — that is the point: each one is a rules mutation that must become an engine call. Fix each individually, don't add setters.)

- [ ] **Step 2: `_registerHit` (174-343) → engine-backed.** Capture `playerIdxBefore = engine.currentPlayerIndex`, `scoreBefore = engine.scores[playerIdxBefore]`, `marksBefore = engine.marks[playerIdxBefore][segment]` as needed for the `DartThrow`/log/announcer lines, then call `final result = engine.applyHit(segment, multiplier);` inside `setState` and DELETE the inline scoring/overflow/cutthroat block (224-264), the `dartsInTurn++`, the finish diffing (295-321) and the `_advancePlayer()` call — the engine did all of it. Consume `result.scored`, `result.closedTarget`, `result.turnEnded`, `result.playerFinished` for labels/sounds/announcements. Keep: undo-related turnId bookkeeping (`DartThrow(..., turnId: _turnIdCounter)`), `_turnIdCounter++` when `result.turnEnded` (mirrors old `_advancePlayer`'s bump), meme/video/announcer/log calls, `_checkGameEndAndMaybeShowPostGame` flow driven by `result.playerFinished`/`engine.gameOver`/`_winnerAndPlacement` helpers. Delete `_isClosed`/`_isClosedByAll`/`_allClosedByPlayer` (128-139) and redirect their UI callers to `engine.isClosed(...)` etc. Delete `_checkWinner` (141-172) — `applyHit` already runs `checkFinishForPlayer`. Delete the screen's `_advancePlayer` (359-380) after moving its announcer/log side effects: announce next player when `result.turnEnded && !engine.gameOver` (`_announcer.announceNextPlayer(players[engine.currentPlayerIndex].name)`), matching Shanghai's `_onHit` tail.
- [ ] **Step 3: `_undo` (382-420) → Shanghai's `_onUndo` shape:**

```dart
  void _undo() {
    if (_gameFullyOver) return;
    if (!engine.canUndo) return;
    if (throwHistory.isEmpty) return;
    setState(() {
      engine.undo();
      final lastThrow = throwHistory.removeLast();
      _turnIdCounter = lastThrow.turnId; // reuse the original turnId (regression: cricket_turn_id_test)
      lastThrowLabel = throwHistory.isEmpty ? null : /* keep the existing label rebuild */;
    });
  }
```

(Port the existing label rebuild; DELETE the marks/scores/finishedPlayers restoration, the F9 removed re-assertion (394-396) and the winner recompute — the engine restores rules state, and undo can no longer cross roster changes because the engine clears its stack.)

- [ ] **Step 4: Roster methods delegate.** `_addSavedPlayerMidGame` (1723-1762): keep players-list/stat-set/log handling, replace the manual `marks.add`/`scores.add`/undo-clear with `engine.addPlayer()`. `_performRemovePlayer` (1765-1795): keep stat sets/logs/announcements, replace state mutation with `final wasCurrent = engine.currentPlayerIndex == playerIndex; engine.removePlayer(playerIndex); if (engine.gameOver) { /* existing ≤1-active end-game flow */ }` — the ≤1-active detection now comes from the engine.
- [ ] **Step 5: ForTest hooks — bodies delegate, signatures identical.** `removedPlayerIndicesForTest => engine.skippedIndices`, `computeWinnerForTest() => engine.winnerIndexExcludingSkipped()`, `winnerIndexForTest => engine.winnerIndexExcludingSkipped()`, rest unchanged in name. `_winnerIndexExcludingRemoved` (434-439) deletes in favor of the engine call; `_computeExitPlacements`/`_buildGameResult`/`_updateStats` keep working off the delegating getters — verify each still compiles against engine-backed state.
- [ ] **Step 6: Verify hard.** `flutter test test/models/cricket_engine_test.dart test/screens/cricket_turn_id_test.dart test/screens/midgame_roster_rules_test.dart test/screens/removed_player_winner_test.dart test/screens/classic_menu_audio_test.dart` → ALL PASS UNCHANGED (do not edit these tests; a failure means the wiring broke a pinned behavior — fix the wiring). Then full `flutter test` + `flutter analyze` → green/0.
- [ ] **Step 7: Commit**

```bash
git add lib/screens/cricket_game_screen.dart
git commit -m "refactor(cricket): screen delegates all rules state to CricketEngine (F19)"
```

---

### Final verification (after all tasks)

- [ ] `flutter analyze` → 0 issues.
- [ ] Full `flutter test` → green, no hang (run it TWICE to shake out RNG-flake ghosts).
- [ ] `grep -rn "engines/cricket_engine" lib/ test/` → nothing (relocated); `grep -rn "cricket_scoreboard\|halve_it_scoreboard\|checkout_widget\|clock_progress" lib/ test/` → nothing.
- [ ] Do NOT push — Bjørn triggers CI. Tablet smoke test covers rounds 1-5 together.
