# Mid-Game Roster Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Games with a mid-game roster change are recorded: joiners count fully, removed players are excluded from that game's stats/Elo/H2H/achievements/history credit, everyone else counts as normal — in all ten modes.

**Architecture:** One mechanism, `excludedSeats: Set<int>`, threaded from each screen into `StatsRecorder.recordGame/buildEntry`, `EloService.updateRatings` and `AchievementService.awardGameEnd`. Seats are never dropped from index-aligned lists — they are skipped. History entries flag removed players (`GameHistoryPlayer.removed`) so every later consumer (season table, replay, profile form, streaks, game detail) can ignore them. `GameResult.statsSkipped` and the post-game banner disappear; the progression chart stays suppressed on a roster change.

**Tech Stack:** Flutter, `flutter_test`. Existing patterns: `_removedPlayerIndices` (Family A screens) / `engine.skippedIndices` (Family B screens), `recordMidGameChanges`.

**Spec:** `docs/superpowers/specs/2026-08-26-midgame-roster-stats-design.md`

## Global Constraints

- Code/comments/UI text English; talk to Bjørn in Norwegian.
- New parameters default to `const {}` so untouched call sites and tests behave identically.
- Never drop a seat from `playerIds`/`placements`/`playerNames`/`modeCounters` — skip it. `DartThrow.playerIndex` and `earnedFeatsByIndex` index by original seat.
- The 8 tests in `test/screens/removed_player_winner_test.dart` and all of `test/screens/midgame_roster_rules_test.dart` must stay green **without edits**.
- Run tests with `timeout 250 flutter test --timeout 60s <files>` (the full suite has a known flake in `dossedart_setup_scaffold_test.dart`; rerun standalone if it is the only red).
- Commit after each task with trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Core — `GameHistoryPlayer.removed`, `excludedSeats` in recorder / Elo / achievements

**Files:**
- Modify: `lib/models/game_history.dart` (`GameHistoryPlayer` ~75–123, `GameHistoryEntry` add getter)
- Modify: `lib/services/stats_recorder.dart` (`recordGame` 17–139, `buildEntry` 156–198)
- Modify: `lib/services/elo_service.dart` (`updateRatings` 64–135)
- Modify: `lib/services/achievement_service.dart` (`awardGameEnd` 107–150)
- Test: `test/services/excluded_seats_test.dart` (create)

**Interfaces (Produces):**
```dart
GameHistoryPlayer({..., bool removed = false});  // JSON 'removed' only when true
List<GameHistoryPlayer> GameHistoryEntry.activePlayers
StatsRecorder.recordGame({..., Set<int> excludedSeats = const {}})
StatsRecorder.buildEntry({..., Set<int> excludedSeats = const {}})
EloService.updateRatings({..., Set<int> excludedSeats = const {}})
AchievementService.awardGameEnd({..., Set<int> excludedSeats = const {}})
```

- [ ] **Step 1: Write the failing test**

```dart
// test/services/excluded_seats_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';
import 'package:dart_scoring/services/elo_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

SavedPlayer sp(String id, {double rating = 1200}) =>
    SavedPlayer(id: id, name: id, createdAt: DateTime(2020), rating: rating);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameHistoryPlayer.removed', () {
    test('defaults false, round-trips, absent key decodes false', () {
      final p = GameHistoryPlayer(
          name: 'Bo', savedPlayerId: 'b', placement: 0, stats: const {}, removed: true);
      final back = GameHistoryPlayer.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.removed, isTrue);
      final plain = GameHistoryPlayer(name: 'A', placement: 1, stats: const {});
      expect(plain.toJson().containsKey('removed'), isFalse);
      expect(GameHistoryPlayer.fromJson(plain.toJson()).removed, isFalse);
    });

    test('activePlayers drops removed rows', () {
      final e = GameHistoryEntry(id: '1', gameMode: 'x01', date: DateTime(2026), players: [
        GameHistoryPlayer(name: 'A', placement: 1, stats: const {}),
        GameHistoryPlayer(name: 'B', placement: 0, stats: const {}, removed: true),
      ]);
      expect(e.activePlayers.map((p) => p.name), ['A']);
    });
  });

  group('EloService.updateRatings excludedSeats', () {
    test('excluded seat is untouched and the field scales as if it were absent', () {
      // Removed seat 1 carries placement 0 (Family B) — must not "win".
      final a = sp('a'), b = sp('b'), c = sp('c');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', 'b', 'c'],
        placements: [1, 0, 2],
        savedPlayers: [a, b, c],
        excludedSeats: {1},
      );
      expect(b.rating, 1200);
      // Same as a plain two-player game a beats c: ±16 at K=32.
      expect(a.rating, closeTo(1216, 0.001));
      expect(c.rating, closeTo(1184, 0.001));
    });

    test('fewer than two active saved players → no change', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        gameMode: 'x01', playerIds: ['a', 'b'], placements: [1, 0],
        savedPlayers: [a, b], excludedSeats: {1});
      expect(a.rating, 1200);
      expect(b.rating, 1200);
    });
  });

  group('StatsRecorder.recordGame excludedSeats', () {
    test('removed seat gets no stats, no H2H, no snapshot; others count; entry flags it',
        () async {
      final a = sp('a'), b = sp('b'), c = sp('c');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b', 'c'],
        playerNames: ['a', 'b', 'c'],
        placements: [1, 0, 2],
        savedPlayers: [a, b, c],
        modeCounters: {'b': {'darts': 9}, 'a': {'darts': 12}},
        excludedSeats: {1},
      );
      expect(b.modeStats['x01'], isNull);
      expect(b.headToHead, isEmpty);
      expect(b.ratingHistory, isEmpty);
      expect(b.currentWinStreak, 0);
      expect(b.currentLossStreak, 0);

      expect(a.modeStats['x01']!.played, 1);
      expect(a.modeStats['x01']!.won, 1); // seat 1's 0 did not steal the win
      expect(a.headToHead.keys, ['c']);   // no pair with the removed seat
      expect(c.headToHead.keys, ['a']);
      expect(a.ratingHistory, hasLength(1));

      await Future<void>.delayed(Duration.zero);
      final entry = (await GameHistoryService.load()).single;
      expect(entry.players[1].removed, isTrue);
      expect(entry.players[0].removed, isFalse);
      expect(entry.activePlayers.map((p) => p.name), ['a', 'c']);
    });

    test('buildEntry flags excluded seats', () {
      final e = StatsRecorder.buildEntry(
        gameMode: 'x01', playerIds: ['a', null], playerNames: ['a', 'g'],
        placements: [1, 2], excludedSeats: {0});
      expect(e.players[0].removed, isTrue);
      expect(e.players[1].removed, isFalse);
    });
  });

  group('AchievementService.awardGameEnd excludedSeats', () {
    test('removed seat earns nothing; the active winner is the winner', () {
      final svc = AchievementService.forTest(achievementCatalog);
      final a = sp('a'), b = sp('b');
      final got = svc.awardGameEnd(
        mode: GameMode.x01,
        playerIds: ['a', 'b'],
        savedPlayers: [a, b],
        placements: [1, 0],
        ratingsBefore: const {'a': 1200, 'b': 1200},
        ratingsAfter: const {'a': 1216, 'b': 1200},
        excludedSeats: {1},
      );
      expect(got.containsKey(1), isFalse);
      expect(b.unlockedAchievementIds, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

`timeout 250 flutter test --timeout 60s test/services/excluded_seats_test.dart` → compile errors (`removed`, `excludedSeats` unknown).

- [ ] **Step 3: `GameHistoryPlayer.removed` + `activePlayers`**

In `lib/models/game_history.dart`, `GameHistoryPlayer`: add field + ctor param + JSON.

```dart
  /// True when this player was removed mid-game. They stay in [players] so
  /// seat indices (throws, feats) line up, but no consumer credits them —
  /// see GameHistoryEntry.activePlayers.
  final bool removed;
  // ctor: this.removed = false,
  // toJson: if (removed) 'removed': true,
  // fromJson: removed: json['removed'] as bool? ?? false,
```

In `GameHistoryEntry`, after `rounds`:

```dart
  /// Players who finished the game — the only ones a ranking, a win, a
  /// season table or a form line may credit.
  List<GameHistoryPlayer> get activePlayers =>
      players.where((p) => !p.removed).toList();
```

- [ ] **Step 4: `StatsRecorder`**

`recordGame`: add `Set<int> excludedSeats = const {},` to the signature. Replace the best-placement block:

```dart
    // Winner is the lowest placement among ACTIVE seats. Removed seats carry
    // 0 (engine modes) or a stale rank (X01/ATC/…) — either would poison this.
    final activePlacements = [
      for (var i = 0; i < placements.length; i++)
        if (!excludedSeats.contains(i)) placements[i],
    ];
    if (activePlacements.isEmpty) return;
    final bestPlacement = activePlacements.reduce((a, b) => a < b ? a : b);
    final bestIsShared =
        activePlacements.where((p) => p == bestPlacement).length > 1;
```

Main loop: first line inside `for (int i = 0; ...)` → `if (excludedSeats.contains(i)) continue;`. H2H inner loop: after `if (i == j) continue;` add `if (excludedSeats.contains(j)) continue;`. Pass `excludedSeats: excludedSeats` into the `buildEntry(...)` call.

`buildEntry`: add `Set<int> excludedSeats = const {},`; in the `List.generate` add `removed: excludedSeats.contains(i),` to the `GameHistoryPlayer(...)`.

- [ ] **Step 5: `EloService.updateRatings`**

Add `Set<int> excludedSeats = const {},`. Replace `final n = playerIds.length; if (n < 2) return;` with:

```dart
    // Field size counts ACTIVE seats only; a removed player is not part of
    // the game being rated and must not shrink everyone's delta.
    final n = playerIds.length - excludedSeats.where((s) => s < playerIds.length).length;
    if (n < 2) return;
```

In the `indexToSaved` build loop, first line: `if (excludedSeats.contains(i)) continue;`.

- [ ] **Step 6: `AchievementService.awardGameEnd`**

Add `Set<int> excludedSeats = const {},`. Replace `best`/`bestIsShared`:

```dart
    final active = [
      for (var i = 0; i < placements.length; i++)
        if (!excludedSeats.contains(i)) placements[i],
    ];
    if (active.isEmpty) return const {};
    final best = active.reduce((a, b) => a < b ? a : b);
    final bestIsShared = active.where((p) => p == best).length > 1;
```

Main loop first line: `if (excludedSeats.contains(i)) continue;`. In the opponents loop add `if (excludedSeats.contains(j)) continue;`. `playerCount: playerIds.length - excludedSeats.length`.

- [ ] **Step 7: Run**

`timeout 250 flutter test --timeout 60s test/services test/models` → all green (existing tests unaffected by the defaults).

- [ ] **Step 8: Commit**

`git add lib/models/game_history.dart lib/services/stats_recorder.dart lib/services/elo_service.dart lib/services/achievement_service.dart test/services/excluded_seats_test.dart` → `feat(stats): excludedSeats — removed players skip stats/Elo/H2H/badges; history flags them`

---

### Task 2: History consumers ignore removed rows

**Files:**
- Modify: `lib/stats/season_stats.dart` (loop 44–69)
- Modify: `lib/stats/season_replay.dart` (58–64)
- Modify: `lib/services/season_service.dart` (`_qualifiedOnFinalDay` ~133)
- Modify: `lib/stats/profile_stats.dart` (form 20–40)
- Modify: `lib/screens/stats_screen.dart` (~1105–1122 streaks, ~1160–1168 checkouts)
- Modify: `lib/screens/dossedart/game_detail_screen.dart` (27–33)
- Test: `test/stats/removed_rows_test.dart` (create)

- [ ] **Step 1: Failing test**

```dart
// test/stats/removed_rows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/profile_stats.dart';
import 'package:dart_scoring/stats/season_replay.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(DateTime date, List<(String, int, bool)> ps) => GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl, removed) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {}, removed: removed)
      ],
    );

void main() {
  // Bo was removed (placement 0, Family-B style); Ada beat Cy.
  final history = [
    game(DateTime(2026, 8, 20), [('a', 1, false), ('b', 0, true), ('c', 2, false)]),
  ];

  test('seasonStatsFrom: removed row gets no game, active rows rank normally', () {
    final rows = seasonStatsFrom(
      history: history, start: DateTime(2026, 7, 1), end: DateTime(2026, 9, 30),
      finalRatings: const {}, names: const {});
    expect(rows.where((r) => r.playerId == 'b'), isEmpty);
    expect(rows.singleWhere((r) => r.playerId == 'a').wins, 1);
    expect(rows.singleWhere((r) => r.playerId == 'c').wins, 0);
  });

  test('replayRatings excludes removed seats (0 does not win)', () {
    final a = SavedPlayer(id: 'a', name: 'a', createdAt: DateTime(2026));
    final b = SavedPlayer(id: 'b', name: 'b', createdAt: DateTime(2026));
    final c = SavedPlayer(id: 'c', name: 'c', createdAt: DateTime(2026));
    replayRatings(history: history, players: [a, b, c]);
    expect(b.rating, 1200);
    expect(a.rating, closeTo(1216, 0.001));
    expect(c.rating, closeTo(1184, 0.001));
  });

  test('profile form skips a game the player was removed from', () {
    expect(recentForm(history, 'b'), isEmpty);
    expect(recentForm(history, 'a').single.outcome, FormOutcome.win);
    expect(recentForm(history, 'c').single.outcome, FormOutcome.loss);
  });
}
```

Check the real name of the form function in `lib/stats/profile_stats.dart` (the one iterating `sorted` history and returning `FormResult`s) and use it instead of `recentForm` if it differs.

- [ ] **Step 2: Run** → fails (b gets a row / wins).

- [ ] **Step 3: Edits**

`season_stats.dart`, inside the entry loop: build `placements` from `entry.activePlayers`; keep the seat loop but add `if (entry.players[seat].removed) continue;` as its first line (the `id == null` check follows).

`season_replay.dart`, in the `for (final entry in games)`:
```dart
    EloService.updateRatings(
      gameMode: entry.gameMode,
      playerIds: entry.players.map((p) => p.savedPlayerId).toList(),
      placements: entry.players.map((p) => p.placement).toList(),
      savedPlayers: players,
      excludedSeats: {
        for (var i = 0; i < entry.players.length; i++)
          if (entry.players[i].removed) i,
      },
    );
```

`season_service.dart` `_qualifiedOnFinalDay`: `e.players.any((p) => p.savedPlayerId == row.playerId)` → `e.activePlayers.any(...)`.

`profile_stats.dart` form: `final me = e.players.where(...)` → `e.activePlayers.where(...)`; `best`/`sharedBest` over `e.activePlayers`.

`stats_screen.dart`: streaks — `playerGames` filter and `gp` lookup and `bestPlacement` all over `e.activePlayers`/`game.activePlayers`; checkouts — `game.activePlayers.where(...)`.

`game_detail_screen.dart`: `final ranked = [...entry.activePlayers]..sort(...)`; `hasFeats` over `entry.activePlayers`; `_FeatsGrid(players: entry.activePlayers)` (line ~72) — check its widget does not index by seat (it takes the list it is given).

- [ ] **Step 4: Run** `timeout 250 flutter test --timeout 60s test/stats test/services test/screens/dossedart_stats_screen_test.dart test/screens/game_detail_screen_test.dart` (adjust to the detail test's real filename) → green.

- [ ] **Step 5: Commit** → `feat(stats): history consumers ignore removed players`

---

### Task 3: Post-game — drop `statsSkipped` and the banner

**Files:**
- Modify: `lib/models/game_result.dart` (remove `statsSkipped` field + ctor param + doc mention)
- Modify: `lib/screens/post_game_screen.dart` (line ~99 `showDetails`; ~168–171 banner; delete `_RosterNotice` ~305–332)
- Modify: `lib/screens/game_screen.dart` (two `statsSkipped:` args, ~1410 and ~1585 — remove the line only; the rest of X01 is Task 4)
- Test: `test/screens/post_game_dossedart_test.dart` (~111–121), `test/screens/post_game_details_test.dart` (~28–35, 65–70)

- [ ] **Step 1:** In the two tests delete the `statsSkipped` cases/params (the "DETAILS is inert when statsSkipped" test goes away; keep the rest). Add to `post_game_details_test.dart`:
```dart
  testWidgets('DETAILS is offered whenever a detailEntry exists', (tester) async { /* build resultWith(detailEntry: someEntry), expect find.text('DETAILS') enabled */ });
```
(copy the existing positive-case pattern in that file.)
- [ ] **Step 2:** `game_result.dart`: remove `final bool statsSkipped;`, `this.statsSkipped = false,` and the "ignored entirely when [statsSkipped] is true" sentence. `post_game_screen.dart`: `final showDetails = result.detailEntry != null;`; delete the `if (result.statsSkipped) ...[ ... ]` block and the `_RosterNotice` class. `game_screen.dart`: delete both `statsSkipped: _midGamePlayerChanges,` lines.
- [ ] **Step 3:** `flutter analyze` (no other references remain — grep `statsSkipped` must return nothing in lib/ and test/). Run `timeout 250 flutter test --timeout 60s test/screens/post_game_dossedart_test.dart test/screens/post_game_details_test.dart test/widgets/post_game_widgets_test.dart`.
- [ ] **Step 4:** Commit → `refactor(post-game): drop statsSkipped and the roster banner`

---

### Task 4–7: Family A screens (one task each, same recipe)

| Task | File | Removed set | Notes from the map |
|---|---|---|---|
| 4 | `lib/screens/game_screen.dart` (X01) | `_removedPlayerIndices` | `_updateStats` 664–800; loops at 673–678, 680–701, 707–765, 775–780; Elo 767; `_awardMilestones` 782/807+; recordGame 784; `_buildDetailEntry` 1453 (drop the `return null` on the flag; pass `excludedSeats`); `_showEarlyTerminationPostGame` results loop 1374 (skip removed); dialog copy 2485; addInfoText 1906 & 2431 |
| 5 | `lib/screens/around_the_clock_game_screen.dart` | `_removedPlayerIndices` | `_updateStats` 1006–1104; loops 1024–1032, 1038–1061; Elo 1063; awardGameEnd 1078; recordGame 1087; copy 1985; addInfoText 1871 & 1886 |
| 6 | `lib/screens/halve_it_game_screen.dart` (Splitscore) | `_removedPlayerIndices` | `_updateStats` 431–440 → `_updateStatsInternal` 490–630; winner scan 501–512 (skip removed!); loops 514–535, 540–583; Elo 585; awardGameEnd 603; recordGame 613; copy 1932; addInfoText 1832 & 1847 |
| 7 | `lib/screens/killer_game_screen.dart` | `_removedPlayerIndices` | `_updateStats` 701–845; loops 720–728, 734–794; Elo 796 (unrated anyway); awardGameEnd 818; recordGame 828; copy 1953; addInfoText 1833 & 1848 |

**Recipe (each task):**

- [ ] **Step 1:** Replace the early-return block
  ```dart
      if (_midGamePlayerChanges) {
        await StatsRecorder.recordMidGameChanges(joinedIds: ..., leftIds: ...);
        return;
      }
  ```
  with an unconditional counters call (it no-ops on empty sets) **before** `PlayerStorage.loadPlayers()`, and a local:
  ```dart
      // Join/leave counters first: they load+save players themselves, and the
      // block below holds its own copy of the list.
      await StatsRecorder.recordMidGameChanges(
          joinedIds: _joinedMidGameIds, leftIds: _leftMidGameIds);
      // Removed players are excluded from this game's stats, Elo, H2H and
      // badges; joiners count fully (spec 2026-08-26). Seats are skipped, not
      // dropped — throws and feats index by seat.
      final excludedSeats = Set<int>.unmodifiable(_removedPlayerIndices);
  ```
  (X01 uses `_recordMidGameCounters()` — keep calling that instead.)
- [ ] **Step 2:** In every loop over players/seats listed in the table, add `if (excludedSeats.contains(pi)) continue;` (use the loop's own index name) as the first statement — SavedPlayer updates, `modeCounters`, ratings capture before and after. Do **not** touch `_buildPlacements()`.
- [ ] **Step 3:** Pass `excludedSeats: excludedSeats` to `EloService.updateRatings`, `AchievementService.awardGameEnd` (X01: into `_awardMilestones`, which forwards it), `StatsRecorder.recordGame`, and (X01) `StatsRecorder.buildEntry` in `_buildDetailEntry` — remove that method's `if (_midGamePlayerChanges) return null;`.
- [ ] **Step 4:** Splitscore only — winner scan 501–512: skip removed seats. X01 only — `_showEarlyTerminationPostGame` results loop: `if (_removedPlayerIndices.contains(i)) continue;`.
- [ ] **Step 5:** Copy. Dialog: `'Statistics will not be recorded for this game.'` → `"They are left out of this game's statistics and rating. Everyone else still counts."`. `addInfoText`: delete the sentence `Rating is skipped for this game once you add or remove a player.` (and its leading space).
- [ ] **Step 6:** Test — add `test/screens/<mode>_midgame_counts_test.dart` following `test/screens/shanghai_midgame_stats_test.dart`'s harness (pump the screen with 3 saved players seeded via `PlayerStorage.savePlayers`, play a couple of darts with the screen's `*ForTest` seams, remove seat 2 via the screen's test seam or `_performRemovePlayer` seam, finish/`updateStatsForTest()`), then assert: history has ONE entry, `entry.players[2].removed == true`, `activePlayers.length == 2`; removed player's `gamesPlayed == 0` and `rating == 1200`; the two others have `gamesPlayed == 1` and ratings `!= 1200` (X01/ATC/Splitscore; Killer is unrated — assert modeStats instead). If the screen has no test seam for removal, add a `@visibleForTesting void removePlayerForTest(int i)` that calls the existing remove handler — the Family-B screens already have exactly this.
- [ ] **Step 7:** Run that test + `test/screens/removed_player_winner_test.dart` + `test/screens/midgame_roster_rules_test.dart` + the mode's existing screen tests → green. `flutter analyze <file>`.
- [ ] **Step 8:** Commit → `feat(<mode>): roster changes count — removed seats excluded, joiners count`

---

### Task 8–13: Family B screens (one task each)

| Task | File | Excluded set | Notes |
|---|---|---|---|
| 8 | `lib/screens/cricket_game_screen.dart` | `engine.skippedIndices` | early-return 556–562; SavedPlayer loop 574–583 needs skip (`gamesPlayed++` today!); modeCounters 586–619 needs skip; Elo 621; awardGameEnd 642; recordGame 651; copy 1982; addInfoText 1851 & 1866 |
| 9 | `lib/screens/shanghai_game_screen.dart` | `engine.skippedIndices` (or `{for i if engine.isSkipped(i)}`) | early-return 370–381; modeCounters already skips; Elo 407; awardGameEnd 425; recordGame 437; copy 729; addInfoText 670 & 685; **flip `test/screens/shanghai_midgame_stats_test.dart`** (see below) |
| 10 | `lib/screens/golf_game_screen.dart` | `engine.skippedIndices` | early-return 532–540; Elo 571; awardGameEnd 585; recordGame 598; `detailEntry` 642–653 — build it regardless of the flag, pass `excludedSeats` |
| 11 | `lib/screens/gotcha_game_screen.dart` | `engine.skippedIndices` | early-return 359–370; Elo 400; awardGameEnd 415; recordGame 427; copy 621; addInfoText 588 |
| 12 | `lib/screens/one_up_game_screen.dart` | `engine.skippedIndices` | early-return 458–466; Elo 500; awardGameEnd 514; recordGame 525 |
| 13 | `lib/screens/wildcard_game_screen.dart` | `engine.skippedIndices` | early-return 647–657; awardGameEnd 680; recordGame 692; `detailEntry` 739–751 build regardless, pass `excludedSeats`; copy 884; addInfoText 849 |

**Recipe:** Steps 1, 3, 5, 7, 8 of the Family-A recipe, with `final excludedSeats = Set<int>.unmodifiable(engine.skippedIndices);` (use the engine's actual accessor name — `skippedIndices` getter or build from `isSkipped(i)`). Step 2 only where the table says a loop still lacks a skip (Cricket). Step 6: Shanghai — rewrite the existing `'mid-game removal writes no game-history entry'` test into `'mid-game removal writes ONE entry with the removed seat flagged'`: seed 3 saved players, same actions, then `expect(history.single.players[2].removed, isTrue)`, `expect(history.single.activePlayers.length, 2)`, removed player's `gamesPlayed == 0`, the others `1`. Cricket — add `test/screens/cricket_midgame_counts_test.dart` per the Family-A Step 6 pattern. Other Family-B screens: the shared unit tests (Task 1) plus the screens' existing tests suffice; verify `flutter analyze` and the mode's screen tests.

Fix any test that asserted the skip (`golf_postgame_undo_test.dart` ~141–181 only asserts the flag is true — still true; leave it).

---

### Task 14: Verification, version, APK

- [ ] `grep -rn "statsSkipped\|STATISTICS NOT RECORDED\|Statistics will not be recorded\|Rating is skipped" lib test` → nothing.
- [ ] `flutter analyze` → clean.
- [ ] Full suite (`timeout 1500 flutter test --timeout 90s > log`); if only `dossedart_setup_scaffold_test` is red, rerun it standalone.
- [ ] Bump `pubspec.yaml` → `1.25.0+57`, `lib/app_version.dart` → `'v1.25.0'`; commit `chore: bump to 1.25.0+57 (roster changes count, home polish, mid-game create)`.
- [ ] `flutter build apk --release`; report path + size.
