# Mid-game Join Fairness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player who joins a game in progress starts from the position of the player currently in last place, instead of from the table average.

**Architecture:** One shared, pure seat-picking helper (`lib/utils/join_seed.dart`) supplies "who is last among the active seats" to all ten modes. Each mode then copies that seat's state in its own `_addSavedPlayerMidGame` (screen-state modes) or `addPlayer` (engine-backed modes). Two modes need more than a copied integer: Cricket also copies per-target marks plus a dead-number guard, and Golf distributes the last-placed stroke total across the holes already played. A shared comparator wrapper adds seat order as the final tiebreak so a joiner never displaces the player they were seeded from.

**Tech Stack:** Flutter / Dart, `flutter_test`. No new dependencies.

## Global Constraints

- Code and comments in **English**. UI strings in **English** (a guard test fails the build on Norwegian strings).
- Colors via `Theme.of(context).colorScheme.<role>` in the classic track; `DossedartTokens` only in the DOSSEDART track. This plan touches no colors.
- "Last" always means **last among *active* seats** — eliminated, finished and removed seats are excluded.
- When no active seat exists, every mode keeps its **current default fallback** unchanged.
- `_midGamePlayerChanges = true`, `_joinedMidGameIds.add(sp.id)`, the undo-history reset, and the stats/Elo suppression that follows a roster change are **unchanged in every mode**.
- Run the full suite (`flutter test`) before each commit; the mode's own test file must stay green.

---

### Task 1: Shared seat-picking helper

**Files:**
- Create: `lib/utils/join_seed.dart`
- Test: `test/utils/join_seed_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `int? worstSeatBy(Iterable<int> activeSeats, Comparator<int> bestFirst)` — the seat that sorts last under `bestFirst`; `null` when `activeSeats` is empty.
  - `int? worstSeat(List<int> values, Iterable<int> activeSeats, {required bool higherIsBetter})` — convenience wrapper for modes whose ranking is a single int list.
  - `Comparator<int> withSeatTiebreak(Comparator<int> bestFirst)` — appends seat order as the final tiebreak.

- [ ] **Step 1: Write the failing test**

```dart
// test/utils/join_seed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/utils/join_seed.dart';

void main() {
  group('worstSeat', () {
    test('higher is better: worst seat holds the lowest value', () {
      expect(worstSeat([40, 12, 25], [0, 1, 2], higherIsBetter: true), 1);
    });

    test('lower is better: worst seat holds the highest value', () {
      expect(worstSeat([40, 12, 25], [0, 1, 2], higherIsBetter: false), 0);
    });

    test('inactive seats are ignored even when they hold the worst value', () {
      // Seat 1 is worst overall but not active; seat 2 is the worst active.
      expect(worstSeat([40, 12, 25], [0, 2], higherIsBetter: true), 2);
    });

    test('ties resolve to the latest seat', () {
      expect(worstSeat([12, 12, 40], [0, 1, 2], higherIsBetter: true), 1);
    });

    test('returns null when no seat is active', () {
      expect(worstSeat([40, 12], const <int>[], higherIsBetter: true), isNull);
    });
  });

  group('withSeatTiebreak', () {
    test('falls back to seat order when the wrapped comparator is equal', () {
      final cmp = withSeatTiebreak((a, b) => 0);
      expect(cmp(1, 3), lessThan(0));
      expect(cmp(3, 1), greaterThan(0));
      expect(cmp(2, 2), 0);
    });

    test('does not override a decisive wrapped comparator', () {
      final cmp = withSeatTiebreak((a, b) => b.compareTo(a));
      expect(cmp(1, 3), greaterThan(0));
    });

    test('makes tied ordering stable across repeated sorts', () {
      // Dart's List.sort is not stable, so an all-equal comparator can permute
      // the list. The seat tiebreak pins it.
      final cmp = withSeatTiebreak((a, b) => 0);
      for (var i = 0; i < 20; i++) {
        final seats = [4, 1, 3, 0, 2]..sort(cmp);
        expect(seats, [0, 1, 2, 3, 4]);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/join_seed_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'dart_scoring/utils/join_seed.dart'` / undefined `worstSeat`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/utils/join_seed.dart

/// Seat-picking for mid-game joiners.
///
/// A joiner is seeded from the active player currently placed LAST in the
/// mode's own ranking — never from the table average, which used to hand a
/// newcomer a better position than the player who had been struggling all
/// game (tester feedback, 2026-08-10).
///
/// No mode re-derives "what is best" here: each one passes the comparator or
/// direction its own ranking already uses.
library;

/// Appends seat order as the final tiebreak to [bestFirst].
///
/// Two purposes. A joiner is seeded from last place and is therefore tied with
/// them; holding the highest seat index, the joiner sorts behind — so the
/// player who earned last place keeps their position and no score is invented.
/// Independently, `List.sort` in Dart is NOT stable, so without this, genuinely
/// tied players order arbitrarily between rebuilds.
Comparator<int> withSeatTiebreak(Comparator<int> bestFirst) => (a, b) {
      final c = bestFirst(a, b);
      return c != 0 ? c : a.compareTo(b);
    };

/// The seat that sorts last among [activeSeats] under [bestFirst] — i.e. the
/// worst-placed active seat. Returns null when [activeSeats] is empty, which
/// callers translate into their mode's default starting state.
///
/// [bestFirst] is wrapped in [withSeatTiebreak], so equal seats resolve to the
/// latest one.
int? worstSeatBy(Iterable<int> activeSeats, Comparator<int> bestFirst) {
  final seats = activeSeats.toList();
  if (seats.isEmpty) return null;
  seats.sort(withSeatTiebreak(bestFirst));
  return seats.last;
}

/// [worstSeatBy] for the modes whose ranking is a single int list indexed by
/// seat: remaining score, total, lives, strokes, segments remaining.
///
/// [higherIsBetter] states the direction — true for point-accumulating modes
/// and for lives, false for countdowns and stroke/segment counts.
int? worstSeat(
  List<int> values,
  Iterable<int> activeSeats, {
  required bool higherIsBetter,
}) =>
    worstSeatBy(
      activeSeats,
      (a, b) => higherIsBetter
          ? values[b].compareTo(values[a])
          : values[a].compareTo(values[b]),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/join_seed_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/join_seed.dart test/utils/join_seed_test.dart
git commit -m "feat(join): shared worst-active-seat helper for mid-game joiners"
```

---

### Task 2: Cricket — copy last place, keep dead numbers dead

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart:1807-1854` (`_addSavedPlayerMidGame`)
- Test: `test/screens/cricket_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeatBy` from Task 1.
- Produces: nothing later tasks depend on. Cricket's existing `addPlayerForTest(SavedPlayer)` accessor (line 415) and `CricketEngine.addPlayer({int initialScore, Map<int,int>? initialMarks})` are used unchanged.

**Context the implementer needs:**
- Cricket's ranking direction already exists in `_computeExitPlacements` (line 437): points descending, or **ascending when `widget.config.isCutthroat`** — in cutthroat, giving points away is good, so the highest score is worst. Then closed-target count descending, then total marks descending.
- `engine.isClosedByAll(target)` returns true when *every* seat has 3 marks on that target. It must be evaluated **before** the joiner is added, or the joiner's own empty marks make it false.
- Active = not in `finishedPlayers`. Removed players are always also in `finishedPlayers`, so that single check covers both (existing comment at line 1808).

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/cricket_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// A joiner starts where the LAST-PLACED active player stands — not at the
/// table average (tester feedback 2026-08-10).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<dynamic> boot(WidgetTester tester, {required bool cutthroat}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: CricketConfig(isCutthroat: cutthroat),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
  }

  testWidgets('standard: joiner copies the LOWEST-scoring active player',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    // P0 leads on points, P1 trails.
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;
    s.engine.marks[0][20] = 3;
    s.engine.marks[1][20] = 3;
    s.engine.marks[0][19] = 3;
    s.engine.marks[1][19] = 1;

    s.addPlayerForTest(SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 29 points. Last place is 12.
    expect(s.engine.scores[2], 12);
    expect(s.engine.marks[2][19], 1, reason: 'copies last place, not average');
  });

  testWidgets('standard: a number closed by everyone stays closed',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;
    // 20 is dead — both players closed it.
    s.engine.marks[0][20] = 3;
    s.engine.marks[1][20] = 3;
    // 18 is closed by the leader only; last place has 1 mark.
    s.engine.marks[0][18] = 3;
    s.engine.marks[1][18] = 1;

    s.addPlayerForTest(SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    expect(s.engine.marks[2][20], 3,
        reason: '20 was closed by all — the joiner must not reopen it');
    expect(s.engine.isClosedByAll(20), isTrue);
    expect(s.engine.marks[2][18], 1,
        reason: '18 was NOT closed by all — copy last place verbatim');
  });

  testWidgets('cutthroat: joiner copies the HIGHEST-scoring active player',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: true);
    // In cutthroat, points are damage taken — highest is worst.
    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;

    s.addPlayerForTest(SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    expect(s.engine.scores[2], 45,
        reason: 'cutthroat flips the direction of "last place"');
  });

  testWidgets('empty table falls back to zero without throwing',
      (tester) async {
    final dynamic s = await boot(tester, cutthroat: false);
    s.finishedPlayersForTest.addAll([0, 1]);

    s.addPlayerForTest(SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    expect(s.engine.scores[2], 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/cricket_join_seed_test.dart`
Expected: FAIL — the first test reports `Expected: 12, Actual: 29` (the current average).

- [ ] **Step 3: Write minimal implementation**

Replace the body of `_addSavedPlayerMidGame` (`lib/screens/cricket_game_screen.dart:1807-1831`, everything above the existing `setState`) with:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average — a
    // joiner should not arrive better off than the player who has been
    // struggling all game (tester feedback 2026-08-10). Active = not in
    // finishedPlayers; removed players are always also in finishedPlayers, so
    // this single check excludes them too.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    // The same ordering _computeExitPlacements uses, so "last" means the same
    // thing here as it does on the result screen — including cutthroat, where
    // the highest score is the worst.
    final worst = worstSeatBy(activeIndices, (a, b) {
      final scoreComp = widget.config.isCutthroat
          ? scores[a].compareTo(scores[b])
          : scores[b].compareTo(scores[a]);
      if (scoreComp != 0) return scoreComp;
      final closedA = targets.where((t) => engine.isClosed(t, a)).length;
      final closedB = targets.where((t) => engine.isClosed(t, b)).length;
      if (closedB != closedA) return closedB.compareTo(closedA);
      final marksA = targets.fold(0, (s, t) => s + (marks[a][t] ?? 0));
      final marksB = targets.fold(0, (s, t) => s + (marks[b][t] ?? 0));
      return marksB.compareTo(marksA);
    });

    final seedPoints = worst == null ? 0 : scores[worst];
    // A target closed by EVERY seat is dead. Copying a last-placed player who
    // never closed it would bring it back to life and let the whole table farm
    // it again — so the joiner is given 3 marks there regardless. Evaluated
    // before the add, or the joiner's own empty marks make isClosedByAll false.
    final newMarks = {
      for (final t in targets)
        t: engine.isClosedByAll(t)
            ? 3
            : (worst == null ? 0 : (marks[worst][t] ?? 0).clamp(0, 3))
    };
```

Add the import at the top of the file, alongside the other `../utils/` imports:

```dart
import '../utils/join_seed.dart';
```

Then rename the two variables the existing `setState` block already reads — `avgPoints` becomes `seedPoints` at both use sites (`Player(... score: avgPoints ...)` and `engine.addPlayer(initialScore: avgPoints, ...)`), and `newMarks` keeps its name.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/cricket_join_seed_test.dart test/models/cricket_engine_test.dart test/screens/midgame_roster_rules_test.dart`
Expected: PASS — all three files.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/cricket_game_screen.dart test/screens/cricket_join_seed_test.dart
git commit -m "fix(cricket): seed mid-game joiners from last place, keep dead numbers dead"
```

---

### Task 3: X01 — joiner inherits the highest remaining score

**Files:**
- Modify: `lib/screens/game_screen.dart:2379-2402` (`_addSavedPlayerMidGame`)
- Test: `test/screens/x01_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing.

**Context:** X01 counts down to zero, so the **highest remaining score is worst** — `higherIsBetter: false`. Active = not in `finishedPlayers`. The existing fallback when nobody is active is `widget.startingScore`; keep it. The `widget.noBust` branch that appends to `_totalDartsPerPlayer` is unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/x01_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the HIGHEST remaining score', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'P0', score: 501),
          Player(name: 'P1', score: 501),
        ],
        startingScore: 501,
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GameScreen>>(find.byType(GameScreen));

    s.playersForTest[0].score = 40;   // nearly finished
    s.playersForTest[1].score = 380;  // last place

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 210. Last place is 380.
    expect(s.playersForTest[2].score, 380);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/x01_join_seed_test.dart`
Expected: FAIL — either `Expected: 380, Actual: 210`, or a missing-accessor compile error if `playersForTest` / `addPlayerForTest` do not exist yet (see Step 3).

- [ ] **Step 3: Write minimal implementation**

If `game_screen.dart` lacks them, add the two test accessors next to the other `@visibleForTesting` members:

```dart
  @visibleForTesting
  List<Player> get playersForTest => players;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);
```

Then replace the average computation in `_addSavedPlayerMidGame`:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). X01 counts down, so the HIGHEST remaining
    // score is the worst position.
    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    final worst = worstSeat(
      [for (final p in players) p.score],
      activePlayers,
      higherIsBetter: false,
    );
    final seedScore = worst == null ? widget.startingScore : players[worst].score;
```

and rename `avgScore` to `seedScore` at its single use site inside `setState`. Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/x01_join_seed_test.dart test/screens/midgame_roster_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart test/screens/x01_join_seed_test.dart
git commit -m "fix(x01): seed mid-game joiners from last place"
```

---

### Task 4: Shanghai — joiner inherits the lowest total

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart:645-675` (`_addSavedPlayerMidGame`)
- Test: `test/screens/shanghai_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing. `ShanghaiEngine.addPlayer({int initialScore = 0})` is used unchanged.

**Context:** Shanghai accumulates points, so the **lowest total is worst** — `higherIsBetter: true`. Active = `!engine.isSkipped(i)`. Current fallback when nobody is active is `0`; keep it.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/shanghai_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the LOWEST total', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const ShanghaiConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester
        .state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));

    s.engine.totalScores[0] = 120;
    s.engine.totalScores[1] = 30;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 75. Last place is 30.
    expect(s.engine.totalScores[2], 30);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/shanghai_join_seed_test.dart`
Expected: FAIL — `Expected: 30, Actual: 75`. If `addPlayerForTest` does not exist, a compile error instead; add the accessor as in Step 3.

- [ ] **Step 3: Write minimal implementation**

Add the accessor if missing:

```dart
  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);
```

Replace the average computation:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Shanghai accumulates, so the LOWEST
    // total is the worst position.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    final worst = worstSeat(engine.totalScores, activeIndices,
        higherIsBetter: true);
    final seedScore = worst == null ? 0 : engine.totalScores[worst];
```

Rename `avgScore` to `seedScore` at both use sites (`Player(... score: ...)` and `engine.addPlayer(initialScore: ...)`). Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/shanghai_join_seed_test.dart test/models/shanghai_engine_test.dart test/screens/shanghai_midgame_stats_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/shanghai_game_screen.dart test/screens/shanghai_join_seed_test.dart
git commit -m "fix(shanghai): seed mid-game joiners from last place"
```

---

### Task 5: Gotcha — joiner inherits the lowest total

**Files:**
- Modify: `lib/screens/gotcha_game_screen.dart:550-573` (`_addSavedPlayerMidGame`)
- Test: `test/screens/gotcha_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing. `GotchaEngine.addPlayer({int initialScore = 0})` clamps to `0..target-1` and is used unchanged — that clamp is what stops a seeded joiner from arriving already-won.

**Context:** Gotcha races **up** to a target, so the **lowest total is worst** — `higherIsBetter: true`. Active = `!engine.isSkipped(i)`. Current fallback is `0`; keep it.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/gotcha_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the LOWEST total', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const GotchaConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    s.engine.totals[0] = 180;
    s.engine.totals[1] = 40;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 110. Last place is 40.
    expect(s.engine.totals[2], 40);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/gotcha_join_seed_test.dart`
Expected: FAIL — `Expected: 40, Actual: 110`.

- [ ] **Step 3: Write minimal implementation**

Add `addPlayerForTest` if missing (same shape as Task 4), then:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Gotcha races up to a target, so the
    // LOWEST total is the worst position.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    final worst = worstSeat(engine.totals, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 0 : engine.totals[worst];
```

Rename `avgScore` to `seedScore` at both use sites. Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/gotcha_join_seed_test.dart test/models/gotcha_engine_test.dart test/screens/gotcha_game_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gotcha_game_screen.dart test/screens/gotcha_join_seed_test.dart
git commit -m "fix(gotcha): seed mid-game joiners from last place"
```

---

### Task 6: Splitscore — joiner inherits the lowest total

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart:1807-1839` (`_addSavedPlayerMidGame`)
- Test: `test/screens/splitscore_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing.

**Context:** Splitscore accumulates points, so the **lowest total is worst** — `higherIsBetter: true`. Active here is `!_removedPlayerIndices.contains(i)` (every player plays every round; there is no mid-game "finished"). The current fallback is the literal `40`; keep it. The `roundScores` backfill loop that appends `null` for already-played rounds is unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/splitscore_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the LOWEST total', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HalveItGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const HalveItConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester
        .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));

    s.totalScoresForTest[0] = 200;
    s.totalScoresForTest[1] = 60;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 130. Last place is 60.
    expect(s.totalScoresForTest[2], 60);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/splitscore_join_seed_test.dart`
Expected: FAIL — `Expected: 60, Actual: 130`.

- [ ] **Step 3: Write minimal implementation**

Add the accessors if missing:

```dart
  @visibleForTesting
  List<int> get totalScoresForTest => totalScores;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);
```

Replace the average computation:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Splitscore accumulates, so the LOWEST
    // total is the worst position.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !_removedPlayerIndices.contains(i))
        .toList();
    final worst = worstSeat(totalScores, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 40 : totalScores[worst];
```

Rename `avgScore` to `seedScore` at both use sites (`Player(... score: ...)` and `totalScores.add(...)`). Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/splitscore_join_seed_test.dart test/screens/halve_it_halving_test.dart test/screens/halve_it_clutch_undo_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/halve_it_game_screen.dart test/screens/splitscore_join_seed_test.dart
git commit -m "fix(splitscore): seed mid-game joiners from last place"
```

---

### Task 7: ATC — joiner inherits the least-advanced target

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart:1806-1850` (`_computeJoinTarget` + `_addSavedPlayerMidGame`)
- Test: `test/screens/atc_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing.

**Context:** ATC walks a fixed sequence; `_segmentsRemaining(target)` counts how far a player still has to go, so **more remaining is worse** — `higherIsBetter: false`. Copying the last-placed player's `currentTargets[i]` directly is both simpler and exactly right: the whole `_computeJoinTarget` walk (average remaining → step forward from `_startTarget`) is deleted, because there is no longer an average to convert back into a target. Active = not in `finishedPlayers`. Fallback stays `_startTarget`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/atc_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the LEAST-advanced target', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'P0', score: 1),
          Player(name: 'P1', score: 1),
        ],
        config: const AroundTheClockConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));

    s.currentTargetsForTest[0] = 17; // well ahead
    s.currentTargetsForTest[1] = 3;  // last place

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // The old average-of-remaining walk landed near 10. Last place is on 3.
    expect(s.currentTargetsForTest[2], 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/atc_join_seed_test.dart`
Expected: FAIL — `Expected: 3, Actual: 10` (or the nearest target the old walk produced).

- [ ] **Step 3: Write minimal implementation**

Add the accessors if missing:

```dart
  @visibleForTesting
  List<int> get currentTargetsForTest => currentTargets;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);
```

Delete `_computeJoinTarget` entirely (lines 1806-1827) and replace its use:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). More segments remaining is worse, and the
    // last-placed player's target IS the position — no conversion needed,
    // which is why the old average-remaining walk is gone.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    final worst = worstSeatBy(
      activeIndices,
      (a, b) => _segmentsRemaining(currentTargets[a])
          .compareTo(_segmentsRemaining(currentTargets[b])),
    );
    final target = worst == null ? _startTarget : currentTargets[worst];
```

The rest of the method (the `setState` block and `_log.logRoster`) is unchanged — it already reads `target`. Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/atc_join_seed_test.dart test/screens/midgame_roster_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/around_the_clock_game_screen.dart test/screens/atc_join_seed_test.dart
git commit -m "fix(atc): seed mid-game joiners from last place"
```

---

### Task 8: Killer — joiner inherits the fewest lives

**Files:**
- Modify: `lib/screens/killer_game_screen.dart:1812-1862` (`_addSavedPlayerMidGame`)
- Test: `test/screens/killer_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing.

**Context:** **Fewest lives is worst** — `higherIsBetter: true`. Active = `!isEliminated[i] && !_removedPlayerIndices.contains(i)`, which is what the current code already filters on. Everything else in the method — the random unused number, the "no free numbers" snackbar early-return, `isKiller.add(false)` (the joiner must still qualify), `shields.add(0)`, `_undoStack.clear()` — is unchanged. Fallback stays `widget.config.lives`.

**No floor.** If last place is on 1 life, the joiner joins on 1 life. That is the rule, deliberately, and the test below pins it so a future "be nice to joiners" change has to break a test on purpose.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/killer_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<dynamic> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: KillerGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const KillerConfig(lives: 3),
      ),
    ));
    await tester.pumpAndSettle();
    return tester
        .state<State<KillerGameScreen>>(find.byType(KillerGameScreen));
  }

  testWidgets('joiner inherits the FEWEST lives', (tester) async {
    final dynamic s = await boot(tester);
    s.livesForTest[0] = 3;
    s.livesForTest[1] = 1;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Averaging would have produced 2. Last place is on 1 — no floor.
    expect(s.livesForTest[2], 1);
  });

  testWidgets('eliminated players are not treated as last place',
      (tester) async {
    final dynamic s = await boot(tester);
    s.livesForTest[0] = 3;
    s.livesForTest[1] = 0;
    s.isEliminatedForTest[1] = true;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    expect(s.livesForTest[2], 3,
        reason: 'a dead player is not the worst ACTIVE player');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/killer_join_seed_test.dart`
Expected: FAIL — first test `Expected: 1, Actual: 2`.

- [ ] **Step 3: Write minimal implementation**

Add the accessors if missing:

```dart
  @visibleForTesting
  List<int> get livesForTest => lives;

  @visibleForTesting
  List<bool> get isEliminatedForTest => isEliminated;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);
```

Replace the average computation (keep the `activeIndices` list exactly as it is):

```dart
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Fewest lives is the worst position, and
    // there is deliberately NO floor: joining a game where everyone is nearly
    // out is a bad deal, and the rule says so honestly.
    final worst = worstSeat(lives, activeIndices, higherIsBetter: true);
    final seedLives = worst == null ? widget.config.lives : lives[worst];
```

Rename `avgLives` to `seedLives` at its single use site (`lives.add(...)`). Add the import:

```dart
import '../utils/join_seed.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/killer_join_seed_test.dart test/screens/killer_kills_undo_test.dart test/screens/midgame_roster_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/killer_game_screen.dart test/screens/killer_join_seed_test.dart
git commit -m "fix(killer): seed mid-game joiners from last place"
```

---

### Task 9: 1UP — joiner inherits the fewest lives

**Files:**
- Modify: `lib/models/one_up_engine.dart:348-359` (`addPlayer`)
- Modify: `lib/screens/one_up_game_screen.dart:657-676` (`_addSavedPlayerMidGame`) and the `addInfoText` at line 651
- Test: `test/models/one_up_engine_test.dart` (extend)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: `OneUpEngine.addPlayer({int? initialLives})` — `null` keeps the current behaviour of `startingLives`, so no other caller changes.

**Context:** **Fewest lives is worst** — `higherIsBetter: true`. The engine already exposes `aliveIndices` (`!isSkipped(i) && livesLeft[i] > 0`), which is exactly the active set. Everything else `addPlayer` does — the zeroed counters and `_undoStack.clear()` — is unchanged. The screen's `addInfoText` currently reads `'Joins next round with ${widget.config.lives} lives'` and must stop promising full lives.

- [ ] **Step 1: Write the failing test**

Append to `test/models/one_up_engine_test.dart`:

```dart
  group('mid-game join seeding', () {
    test('addPlayer takes explicit initial lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.livesLeft[0] = 3;
      e.livesLeft[1] = 1;

      e.addPlayer(initialLives: 1);

      expect(e.livesLeft[2], 1);
      expect(e.playerCount, 3);
    });

    test('addPlayer without initialLives still grants the starting lives', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.addPlayer();
      expect(e.livesLeft[2], 3);
    });

    test('a joiner gets zeroed counters, not the copied seat\'s', () {
      final e = OneUpEngine(playerCount: 2, startingLives: 3);
      e.livesLost[1] = 2;
      e.roundsWon[1] = 4;

      e.addPlayer(initialLives: 1);

      expect(e.livesLost[2], 0);
      expect(e.roundsWon[2], 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/one_up_engine_test.dart`
Expected: FAIL — `No named parameter with the name 'initialLives'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/models/one_up_engine.dart`:

```dart
  /// Adds a seat mid-game. [initialLives] seeds the joiner from the
  /// last-placed active player (tester feedback 2026-08-10); null keeps the
  /// original behaviour of granting a full set of [startingLives].
  void addPlayer({int? initialLives}) {
    _undoStack.clear();
    livesLeft.add(initialLives ?? startingLives);
    livesLost.add(0);
    targetsSet.add(0);
    highestTurn.add(0);
    turnsSurvived.add(0);
    lastDartSaves.add(0);
    elimsDealt.add(0);
    roundsWon.add(0);
    // _order is rebuilt at the next round boundary and picks them up.
  }
```

In `lib/screens/one_up_game_screen.dart`, add the import `import '../utils/join_seed.dart';` and replace the body of `_addSavedPlayerMidGame` above its `_log.logRoster` call:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not a full set of lives
    // (tester feedback 2026-08-10). Fewest lives is the worst position, and
    // there is deliberately no floor.
    final worst = worstSeat(engine.livesLeft, engine.aliveIndices,
        higherIsBetter: true);
    final seedLives =
        worst == null ? widget.config.lives : engine.livesLeft[worst];
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: 0,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer(initialLives: seedLives);
    });
```

Change the `addInfoText` at line 651 from `'Joins next round with ${widget.config.lives} lives'` to:

```dart
      addInfoText: 'Joins next round with the last-placed player\'s lives',
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/one_up_engine_test.dart test/screens/one_up_game_screen_test.dart test/screens/one_up_postgame_undo_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/one_up_engine.dart lib/screens/one_up_game_screen.dart test/models/one_up_engine_test.dart
git commit -m "fix(1up): seed mid-game joiners from last place"
```

---

### Task 10: Golf — distribute the last-placed stroke total

**Files:**
- Modify: `lib/models/golf_engine.dart:437-451` (`addPlayer`) and add a top-level helper
- Modify: `lib/screens/golf_game_screen.dart:861-882` (`_addSavedPlayerMidGame`) and the `addInfoText` at line 855
- Test: `test/models/golf_engine_test.dart` (extend)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces:
  - `List<int> distributeStrokes(int total, int holes)` — top-level in `golf_engine.dart`; `holes` values summing exactly to `total`.
  - `GolfEngine.addPlayer({int? seedTotal})` — `null` keeps the PAR backfill, so no other caller changes.

**Context:** Golf is **lowest total wins**, so the **highest stroke total is worst** — `higherIsBetter: false`. `addPlayer` currently backfills `backfillHoles` (= `currentHole`, or all `holes` during sudden death) with `3` each.

Naive averaging is wrong: 22 strokes over 5 holes rounds to 4, totalling 20 — the joiner ends up **better** than the player they were seeded from. Distributing the remainder fixes it: `base = total ~/ holes`, `remainder = total % holes`, and `remainder` holes get `base + 1`.

No clamping is needed. A real total over `holes` holes lies between `holes × 1` and `holes × 6`, so `base` lands in 1–6, and `base + 1` can only reach 7 when `base` is already 6 — which requires an exact `holes × 6` total, where the remainder is zero and no hole is bumped. The test below pins this instead of a runtime clamp.

- [ ] **Step 1: Write the failing test**

Append to `test/models/golf_engine_test.dart`:

```dart
  group('distributeStrokes', () {
    test('an exact division gives every hole the same score', () {
      expect(distributeStrokes(15, 5), [3, 3, 3, 3, 3]);
    });

    test('a remainder is spread, and the total is exact', () {
      final row = distributeStrokes(22, 5);
      expect(row.reduce((a, b) => a + b), 22);
      expect(row.where((s) => s == 5).length, 2);
      expect(row.where((s) => s == 4).length, 3);
    });

    test('every value stays inside the legal 1-6 stroke range', () {
      for (var holes = 1; holes <= 18; holes++) {
        for (var total = holes; total <= holes * 6; total++) {
          final row = distributeStrokes(total, holes);
          expect(row.reduce((a, b) => a + b), total,
              reason: 'total=$total holes=$holes');
          expect(row.every((s) => s >= 1 && s <= 6), isTrue,
              reason: 'total=$total holes=$holes produced $row');
        }
      }
    });

    test('zero holes yields an empty row', () {
      expect(distributeStrokes(0, 0), isEmpty);
    });
  });

  group('mid-game join seeding', () {
    test('a seeded joiner matches the last-placed total exactly', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      // Play 5 holes: seat 0 is sharp, seat 1 is the worst.
      for (var h = 0; h < 5; h++) {
        e.scorecards[0][h] = 3;
        e.scorecards[1][h] = h == 0 ? 6 : 4;
      }
      e.currentHole = 5;

      e.addPlayer(seedTotal: e.total(1));

      expect(e.total(2), e.total(1));
      expect(e.scorecards[2].sublist(5).every((s) => s == null), isTrue,
          reason: 'unplayed holes stay empty');
    });

    test('addPlayer without seedTotal still backfills PAR', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      e.currentHole = 4;
      e.addPlayer();
      expect(e.scorecards[2].sublist(0, 4), [3, 3, 3, 3]);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/golf_engine_test.dart`
Expected: FAIL — `Undefined name 'distributeStrokes'`.

- [ ] **Step 3: Write minimal implementation**

Add near `golfTerm` at the top of `lib/models/golf_engine.dart`:

```dart
/// Splits [total] strokes across [holes] holes so the sum is EXACT.
///
/// Averaging and rounding would let a seeded joiner land better than the
/// player they were seeded from — 22 over 5 rounds to 4, totalling 20. The
/// remainder is spread across the first `total % holes` holes instead.
///
/// Every value is a legal 1-6 hole score without clamping: a real total lies
/// between `holes` and `holes * 6`, so `base` is 1-6, and `base + 1` can only
/// reach 7 when `base` is 6 — which means an exact `holes * 6` total, where
/// the remainder is zero and nothing is bumped.
List<int> distributeStrokes(int total, int holes) {
  if (holes <= 0) return <int>[];
  final base = total ~/ holes;
  final remainder = total % holes;
  return [for (var h = 0; h < holes; h++) h < remainder ? base + 1 : base];
}
```

Replace `addPlayer`:

```dart
  /// Adds a seat mid-game. [seedTotal] backfills the holes already played so
  /// the joiner's total matches the last-placed active player (tester feedback
  /// 2026-08-10); null keeps the original PAR backfill.
  void addPlayer({int? seedTotal}) {
    final row = List<int?>.filled(holes, null, growable: true);
    final backfillHoles = inSuddenDeath ? holes : currentHole;
    final backfill = seedTotal == null
        ? List<int>.filled(backfillHoles, 3)
        : distributeStrokes(seedTotal, backfillHoles);
    for (var h = 0; h < backfillHoles; h++) {
      row[h] = backfill[h];
    }
    scorecards.add(row);
    aces.add(0);
    bogeys.add(0);
    firstDartHits.add(0);
    dartsThrown.add(0);
    bestHole.add(null);
    playoffStrokes.add(null);
    _undoStack.clear();
  }
```

In `lib/screens/golf_game_screen.dart`, add `import '../utils/join_seed.dart';` and seed the call:

```dart
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not PAR (tester feedback
    // 2026-08-10). Golf is lowest-total-wins, so the HIGHEST stroke total is
    // the worst position.
    final activeIndices = [
      for (var i = 0; i < players.length; i++)
        if (!engine.isSkipped(i)) i
    ];
    final worst = worstSeat(
      [for (var i = 0; i < players.length; i++) engine.total(i)],
      activeIndices,
      higherIsBetter: false,
    );
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(
        Player(
          name: sp.name,
          score: 0,
          savedPlayerId: sp.id,
          avatarPath: sp.avatarPath,
        ),
      );
      engine.addPlayer(seedTotal: worst == null ? null : engine.total(worst));
    });
```

The `_log.logRoster` call that follows is unchanged. Change the `addInfoText` at line 855 from `'Joins at hole ${engine.holeNumber} — earlier holes count as par.'` to:

```dart
          'Joins at hole ${engine.holeNumber} — earlier holes match the last-placed player.',
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/golf_engine_test.dart test/screens/golf_game_screen_test.dart test/screens/golf_postgame_undo_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/golf_engine.dart lib/screens/golf_game_screen.dart test/models/golf_engine_test.dart
git commit -m "fix(golf): seed mid-game joiners from last place instead of par"
```

---

### Task 11: WILDCARD — adopt the shared rule, amend §7.2

**Files:**
- Modify: `lib/screens/wildcard_game_screen.dart:811-825` (`_addSavedPlayerMidGame`)
- Modify: `lib/models/wildcard_engine.dart:1192-1196` (the `addPlayer` doc comment)
- Modify: the WILDCARD spec in `docs/superpowers/specs/` — the §7.2 "joiners always start at 0" rule
- Test: `test/screens/wildcard_join_seed_test.dart` (create)

**Interfaces:**
- Consumes: `worstSeat` from Task 1.
- Produces: nothing. `WildcardEngine.addPlayer({int initialScore = 0})` already accepts a score — it exists "only for API symmetry" today and now becomes load-bearing.

**Context:** WILDCARD accumulates points, so the **lowest total is worst** — `higherIsBetter: true`. Active = `!engine.isSkipped(i)`. The old §7.2 rule pinned joiners to 0 to avoid the *table average*; it predates the last-place rule, and cross-mode consistency wins. Because the lowest active total is always ≥ 0, this change can only ever be **more** generous than the old behaviour.

Find the spec file with `grep -rln "7.2" docs/superpowers/specs/ | xargs grep -ln -i wildcard` and update the rule text plus any table row that states the 0 behaviour.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/wildcard_join_seed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('joiner inherits the LOWEST total, not 0', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const WildcardConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    s.engine.totals[0] = 300;
    s.engine.totals[1] = 85;

    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    expect(s.engine.totals[2], 85,
        reason: 'spec §7.2 amended 2026-08-10 — joiners follow the shared rule');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/wildcard_join_seed_test.dart`
Expected: FAIL — `Expected: 85, Actual: 0`.

- [ ] **Step 3: Write minimal implementation**

Add `addPlayerForTest` if missing, add `import '../utils/join_seed.dart';`, and replace the method and its doc comment:

```dart
  /// WILDCARD joiners follow the shared last-place rule (spec §7.2, amended
  /// 2026-08-10). The original "always 0" existed to reject the table AVERAGE
  /// the other cockpits used; the last-place rule did not exist yet, and the
  /// lowest active total is always >= 0, so this can only be more generous.
  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final activeIndices = [
      for (var i = 0; i < players.length; i++)
        if (!engine.isSkipped(i)) i
    ];
    final worst = worstSeat(engine.totals, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 0 : engine.totals[worst];
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: 0,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer(initialScore: seedScore);
    });
  }
```

Update the engine's `addPlayer` doc comment (`lib/models/wildcard_engine.dart:1192-1195`) to drop the "always start at 0 … exists only for API symmetry" claim:

```dart
  /// Add a mid-game joiner seeded with [initialScore] — the last-placed active
  /// player's total (spec §7.2, amended 2026-08-10). Clears the undo stack:
  /// snapshots hold the old list lengths.
```

Then update the WILDCARD spec's §7.2 text to state the last-place rule and note the amendment date.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/wildcard_join_seed_test.dart test/models/wildcard_engine_test.dart test/screens/wildcard_game_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/wildcard_game_screen.dart lib/models/wildcard_engine.dart docs/superpowers/specs test/screens/wildcard_join_seed_test.dart
git commit -m "fix(wildcard): seed mid-game joiners from last place, amend spec 7.2"
```

---

### Task 12: Seat tiebreak in the ranking comparators

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart:437-448` (`_computeExitPlacements`'s sort)
- Modify: the ranking sort in each remaining mode (see Step 3 for the discovery command)
- Test: `test/screens/join_tiebreak_test.dart` (create)

**Interfaces:**
- Consumes: `withSeatTiebreak` from Task 1.
- Produces: nothing.

**Context:** A joiner seeded from last place is tied with them on every ranking criterion. Without a final tiebreak the two order arbitrarily — `List.sort` in Dart is not stable — so the player who earned last place can be pushed below a newcomer who has thrown nothing. Wrapping each comparator in `withSeatTiebreak` puts the higher seat index (always the joiner) last.

`WildcardEngine.ranking()` (line 340) **already** ends in a seat-index comparison — leave it alone and note it in the commit message.

Shared placement *numbers* on a genuine tie are unchanged: a joiner who catches up over many rounds and finishes level has earned the shared rank. Only the ordering moves.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/join_tiebreak_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// A joiner is seeded from last place and is therefore tied with them. The
/// player who earned last place must keep their position.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  testWidgets('a zero-dart joiner never outranks the seat it copied',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          Player(name: 'P0', score: 0),
          Player(name: 'P1', score: 0),
        ],
        config: const CricketConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));

    s.engine.scores[0] = 45;
    s.engine.scores[1] = 12;
    s.addPlayerForTest(const SavedPlayer(id: 'x', name: 'Late'));
    await tester.pump();

    // Repeated because an unstable sort can pass once by luck.
    for (var i = 0; i < 20; i++) {
      final order = s.exitPlacementOrderForTest;
      expect(order.indexOf(1), lessThan(order.indexOf(2)),
          reason: 'P1 earned last place; the joiner sits below them');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/join_tiebreak_test.dart`
Expected: FAIL — either a compile error for the missing `exitPlacementOrderForTest` accessor, or an intermittent ordering failure across the 20 iterations.

- [ ] **Step 3: Write minimal implementation**

Add to `cricket_game_screen.dart`, next to the other `@visibleForTesting` members:

```dart
  /// Seat indices in ranked order — the ordering _computeExitPlacements sorts
  /// by, exposed for the tiebreak regression test.
  @visibleForTesting
  List<int> get exitPlacementOrderForTest {
    final placements = _computeExitPlacements();
    return List.generate(players.length, (i) => i)
      ..sort((a, b) {
        final c = placements[a].compareTo(placements[b]);
        return c != 0 ? c : a.compareTo(b);
      });
  }
```

Wrap Cricket's comparator (`lib/screens/cricket_game_screen.dart:437`):

```dart
    remaining.sort(withSeatTiebreak((a, b) {
      final scoreComp = widget.config.isCutthroat
          ? scores[a].compareTo(scores[b])
          : scores[b].compareTo(scores[a]);
      if (scoreComp != 0) return scoreComp;
      final closedA = targets.where((t) => engine.isClosed(t, a)).length;
      final closedB = targets.where((t) => engine.isClosed(t, b)).length;
      if (closedB != closedA) return closedB.compareTo(closedA);
      final marksA = targets.fold(0, (s, t) => s + (marks[a][t] ?? 0));
      final marksB = targets.fold(0, (s, t) => s + (marks[b][t] ?? 0));
      return marksB.compareTo(marksA);
    }));
```

and add `import '../utils/join_seed.dart';` (already present from Task 2).

Then apply the same wrap to every other mode's ranking sort. Find them with:

```bash
grep -rn "sort(" lib/screens/*_game_screen.dart lib/models/*_engine.dart | grep -v "_undoStack"
```

For each hit that orders **seats for standings or placements** (not checkout candidates, not history by date, not TTS voice lists), wrap the comparator in `withSeatTiebreak(...)`. Skip `WildcardEngine.ranking()` — it already ends in `a.compareTo(b)`. Add the import to each file touched: engines use `import '../utils/join_seed.dart';`, screens the same.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: PASS. If a placement test now fails, read it before changing it — a comparator that previously relied on the unstable sort order was already fragile, but a *changed shared rank* would mean the wrap was applied to the tie-sharing logic rather than the sort, which is wrong.

- [ ] **Step 5: Commit**

```bash
git add lib test/screens/join_tiebreak_test.dart
git commit -m "fix(standings): seat-order tiebreak so a joiner never displaces last place"
```

---

### Task 13: Align the add-player sheet copy

**Files:**
- Modify: the `addInfoText` argument in every `showMidGamePlayerSheet` / `showDossedartPlayerSheet` call site that still describes averaging or full lives
- Test: covered by the existing English-strings guard test; no new test

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Killer's sheet says *"New players get a random unused number and must qualify by hitting their double."* — still true, leave it. 1UP's and Golf's were updated in Tasks 9 and 10. The remaining modes use the generic *"Rating is skipped for this game once you add or remove a player."*, which stays accurate. This task exists to sweep anything the earlier tasks missed and to add the one new sentence testers asked about.

- [ ] **Step 1: Find every call site**

```bash
grep -rn "addInfoText" lib/screens lib/widgets
```

- [ ] **Step 2: Add the rule to the generic message**

For each mode whose `addInfoText` is only the rating sentence, prepend the rule so players see why they start where they do:

```dart
      addInfoText:
          'A new player starts level with whoever is in last place. '
          'Rating is skipped for this game once you add or remove a player.',
```

Leave Killer's number/qualify sentence in place and append the same first sentence to it.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: PASS — including the Norwegian-strings guard.

- [ ] **Step 4: Commit**

```bash
git add lib/screens
git commit -m "docs(ui): tell players a joiner starts level with last place"
```

---

## Self-Review

**Spec coverage.** §1 the rule → Tasks 1-11. §2 ties → Task 12. §3 per-mode table → Tasks 2-11, one row each: X01 (3), Cricket (2), Shanghai (4), Gotcha (5), Splitscore (6), ATC (7), Killer (8), 1UP (9), Golf (10), WILDCARD (11). §4 Cricket dead-number guard → Task 2 Step 3. §5 Golf distribution → Task 10. §6 WILDCARD §7.2 amendment → Task 11. §7 engine-vs-screen split → honoured: engine changes only where the mode has one and the state lives there (1UP lives, Golf scorecard, WILDCARD doc). §8 testing → every bullet has a test: per-mode seeding (Tasks 2-11), Cricket both directions (Task 2), dead-number guard (Task 2), Golf distribution (Task 10), tie ordering (Tasks 1 and 12), empty-table fallback (Task 2), no lives floor (Task 8). §9 out of scope → nothing in this plan touches removal, Elo, or scoring rules.

**Type consistency.** `worstSeat` / `worstSeatBy` / `withSeatTiebreak` keep the same signatures from Task 1 through Task 12. `seedScore` / `seedLives` / `seedTotal` are used consistently. `OneUpEngine.addPlayer({int? initialLives})` and `GolfEngine.addPlayer({int? seedTotal})` are both nullable-optional, so existing callers compile untouched.

**Known soft spot.** Tasks 3-8 say "add the accessor if missing" for `@visibleForTesting` getters, because those screens were not all read line-by-line while planning. The accessor bodies are given in full, so this is a two-second check per task, not a design gap.
