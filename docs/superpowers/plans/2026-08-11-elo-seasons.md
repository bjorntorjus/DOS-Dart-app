# Elo Seasons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the single lifetime Elo rating into quarterly seasons — with the two seasons already played rebuilt retroactively from game history, a browsable archive, and twelve achievements that fire when a season closes.

**Architecture:** Four pure units carry all the logic and are tested without a widget: `SeasonRecord`/`SeasonPlayerRow` (the archive shape), `seasonStatsFrom()` (per-player figures from history in a date range), `replayRatings()` (Elo over an ordered slice of history) and `quarterBoundary()` (calendar arithmetic). Three thin layers sit on top: `SeasonService` (storage + close + migration), one new stats tab, and twelve catalogue entries.

**Tech Stack:** Flutter / Dart, `shared_preferences`, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-11-elo-seasons-design.md`. Plan 1 (backup export) is already merged on this branch and is a prerequisite — the migration refuses to run without it.

## Global Constraints

- Code and comments in **English**. UI strings **English** (a guard test fails the build on Norwegian strings).
- The SEASONS tab is DOSSEDART: **tokens only** (`lib/theme/dossedart_tokens.dart`), `Press Start 2P` / `VT323`, **no border-radius**.
- **A reset writes `SavedPlayer.rating` and nothing else.** `gamesPlayed`, `gamesWon`, `modeStats` and `unlockedAchievementIds` are never touched by a season boundary.
- **Rated modes:** every mode except `wildcard` and `killer`. Cricket writes two history keys — `cricket` and `cricket_cutthroat` — and both are rated.
- **Qualification:** 10 games within the season.
- **Hard reset to 1200** at each boundary. The K-factor is **not** changed: 32 below 20 lifetime games, 16 after.
- Run `flutter analyze lib test` and `flutter test` before each commit.

---

### Task 1: The archive shape

**Files:**
- Create: `lib/models/season.dart`
- Test: `test/models/season_test.dart` (create)

**Interfaces:**
- Produces:
  - `class SeasonPlayerRow { final String playerId; final String name; final double rating; final int games; final int wins; final int dartsThrown; final int dartsHit; final int gamesWithThrows; }` with `double? get winPercent`, `double? get hitPercent`, `bool get qualified`, `toJson`/`fromJson`.
  - `class SeasonRecord { final int number; final DateTime start; final DateTime end; final List<SeasonPlayerRow> rows; }` with `List<SeasonPlayerRow> get ranked`, `List<SeasonPlayerRow> get unqualified`, `String? get winnerName`, `toJson`/`fromJson`.
  - `const int kSeasonQualifyingGames = 10;`

**Context:** `ranked` is qualified rows sorted by rating descending, ties broken by seat-independent name so the order is stable across rebuilds. `unqualified` is everyone else sorted by games descending — they are shown *below* the table with `n/10`, never ranked. `hitPercent` returns null when `gamesWithThrows` is 0, which is how the retroactive seasons report "no throws survive for this stretch" rather than a misleading 0 %.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/season_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/season.dart';

SeasonPlayerRow row(String name, double rating, int games,
        {int wins = 0, int thrown = 0, int hit = 0, int withThrows = 0}) =>
    SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: thrown,
      dartsHit: hit,
      gamesWithThrows: withThrows,
    );

void main() {
  test('qualification is 10 games in the season', () {
    expect(row('A', 1200, 9).qualified, isFalse);
    expect(row('A', 1200, 10).qualified, isTrue);
  });

  test('win percent is null with no games, never a fake zero', () {
    expect(row('A', 1200, 0).winPercent, isNull);
    expect(row('A', 1200, 4, wins: 1).winPercent, 25.0);
  });

  test('hit percent is null when no game in the season stored its throws', () {
    expect(row('A', 1200, 20, thrown: 0, hit: 0, withThrows: 0).hitPercent,
        isNull,
        reason: 'retroactive seasons must say "unknown", not "0 %"');
    expect(
        row('A', 1200, 20, thrown: 200, hit: 150, withThrows: 20).hitPercent,
        75.0);
  });

  test('ranked holds only qualified rows, best rating first', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Low', 1150, 20), row('High', 1290, 20), row('Guest', 1400, 3)],
    );

    expect(s.ranked.map((r) => r.name), ['High', 'Low']);
    expect(s.unqualified.map((r) => r.name), ['Guest'],
        reason: 'a 3-game player must not outrank regulars on a noisy number');
    expect(s.winnerName, 'High');
  });

  test('equal ratings order by name so a rebuild is stable', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Zoe', 1200, 12), row('Adam', 1200, 12)],
    );
    for (var i = 0; i < 10; i++) {
      expect(s.ranked.map((r) => r.name), ['Adam', 'Zoe']);
    }
  });

  test('a season nobody qualified in has no winner', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Guest', 1400, 2)],
    );
    expect(s.ranked, isEmpty);
    expect(s.winnerName, isNull);
  });

  test('a season round-trips through JSON', () {
    final s = SeasonRecord(
      number: 2,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 9, 30),
      rows: [row('A', 1276.5, 35, wins: 18, thrown: 400, hit: 310, withThrows: 35)],
    );

    final back = SeasonRecord.fromJson(s.toJson());

    expect(back.number, 2);
    expect(back.start, DateTime(2026, 7, 1));
    expect(back.rows.single.rating, 1276.5);
    expect(back.rows.single.hitPercent, closeTo(77.5, 0.01));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/season_test.dart`
Expected: FAIL — `lib/models/season.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/models/season.dart` with the two classes and the constant. Notes that matter:

```dart
/// A season is ranked on rating, but only among players who played enough for
/// the number to mean anything. Two games leaves a 60 %-winner at ~1207 and a
/// 20 %-winner at ~1195 — indistinguishable, yet mid-table if ranked.
const int kSeasonQualifyingGames = 10;
```

`winPercent` → `games == 0 ? null : 100 * wins / games`.
`hitPercent` → `gamesWithThrows == 0 || dartsThrown == 0 ? null : 100 * dartsHit / dartsThrown`.
`qualified` → `games >= kSeasonQualifyingGames`.
`ranked` → rows where `qualified`, sorted by `rating` descending then `name` ascending.
`unqualified` → the rest, sorted by `games` descending then `name`.
`winnerName` → `ranked.isEmpty ? null : ranked.first.name`.
Dates serialise with `toIso8601String()` and parse with `DateTime.parse`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/season_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/models/season.dart test/models/season_test.dart
git commit -m "feat(seasons): the archive shape"
```

---

### Task 2: Rated modes gate

**Files:**
- Modify: `lib/services/elo_service.dart`
- Modify: every `EloService.updateRatings(` call site (10 screens, 2 sites each in several)
- Test: `test/services/elo_rated_modes_test.dart` (create)

**Interfaces:**
- Produces:
  - `const Set<String> kUnratedModes = {'wildcard', 'killer'};`
  - `bool EloService.isRatedMode(String gameMode)`
  - `EloService.updateRatings({required String gameMode, ...})` — the existing named parameters plus a required `gameMode`, returning early when unrated.

**Context:** Putting the gate inside `updateRatings` means a mode cannot be rated by accident from a call site that forgot. WILDCARD already skips the call entirely; that stays harmless, and Killer's two call sites now no-op.

Mode keys are not one-to-one with modes: `cricket_game_screen.dart:607` records `cricket_cutthroat` or `cricket`. Both are rated, so the set lists what is *excluded* rather than what is included — a new mode is rated by default, which is the safer direction.

Find the call sites with `grep -rn "EloService.updateRatings" lib/`. Each screen already has its mode string nearby in the same method (the `StatsRecorder.recordGame(gameMode: ...)` call). Pass the same string.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/elo_rated_modes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/elo_service.dart';

SavedPlayer p(String id, double rating) =>
    SavedPlayer(id: id, name: id, createdAt: DateTime(2026), rating: rating);

void main() {
  test('cricket counts under both of its history keys', () {
    expect(EloService.isRatedMode('cricket'), isTrue);
    expect(EloService.isRatedMode('cricket_cutthroat'), isTrue,
        reason: 'the cutthroat variant writes its own key');
  });

  test('wildcard and killer do not count', () {
    expect(EloService.isRatedMode('wildcard'), isFalse);
    expect(EloService.isRatedMode('killer'), isFalse);
  });

  test('an unknown future mode is rated by default', () {
    expect(EloService.isRatedMode('shuffleboard'), isTrue,
        reason: 'the set lists exclusions, so forgetting one is the safe way');
  });

  test('an unrated game leaves every rating untouched', () {
    final players = [p('a', 1300), p('b', 1100)];
    EloService.updateRatings(
      gameMode: 'killer',
      playerIds: const ['a', 'b'],
      placements: const [1, 2],
      savedPlayers: players,
    );
    expect(players[0].rating, 1300);
    expect(players[1].rating, 1100);
  });

  test('a rated game still moves them', () {
    final players = [p('a', 1300), p('b', 1100)];
    EloService.updateRatings(
      gameMode: 'x01',
      playerIds: const ['a', 'b'],
      placements: const [1, 2],
      savedPlayers: players,
    );
    expect(players[0].rating, greaterThan(1300));
    expect(players[1].rating, lessThan(1100));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/elo_rated_modes_test.dart`
Expected: FAIL — `isRatedMode` undefined and `updateRatings` has no `gameMode` parameter.

- [ ] **Step 3: Write the implementation**

In `lib/services/elo_service.dart`:

```dart
/// Modes that never touch the rating. WILDCARD is chaos by design; Killer is
/// decided in large part by who gets attacked rather than who throws best.
///
/// This lists EXCLUSIONS on purpose: a mode added later is rated unless
/// somebody says otherwise, which fails in the direction that keeps the
/// number complete rather than silently narrow.
const Set<String> kUnratedModes = {'wildcard', 'killer'};

  static bool isRatedMode(String gameMode) =>
      !kUnratedModes.contains(gameMode);
```

Add `required String gameMode,` to `updateRatings` and, immediately after `final n = playerIds.length;`:

```dart
    if (!isRatedMode(gameMode)) return;
```

Then update every call site to pass the mode string the screen already uses for `StatsRecorder.recordGame`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/elo_rated_modes_test.dart && flutter analyze lib && flutter test`
Expected: PASS. A Killer test that asserted a rating change will now fail — that is the intended behaviour change; update the assertion and say so in the commit.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(elo): gate rating on the mode, excluding WILDCARD and Killer"
```

---

### Task 3: Season figures from history

**Files:**
- Create: `lib/stats/season_stats.dart`
- Test: `test/stats/season_stats_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonPlayerRow` (Task 1), `EloService.isRatedMode` (Task 2).
- Produces: `List<SeasonPlayerRow> seasonStatsFrom({required List<GameHistoryEntry> history, required DateTime start, required DateTime end, required Map<String, double> finalRatings, required Map<String, String> names})`

**Context:** Season figures come from **game history filtered by date range**, not from cumulative counters — that is what makes retroactive seasons possible at all, since no snapshot was taken on 30 June.

`start`/`end` are inclusive whole days. Only rated modes count. A player is counted per entry they appear in with a non-null `savedPlayerId`; guests contribute nothing, exactly as they do live.

A win is a **sole** best placement. A shared best is a draw and counts as a game but not a win — the same rule `StatsRecorder` already applies (`stats_recorder.dart:32`).

Darts are counted from `entry.throwHistory` when present: thrown is every dart, hit is `multiplier > 0`. `gamesWithThrows` counts the entries that had any, so `hitPercent` can distinguish "missed everything" from "we do not know". Throws only exist from 18 June 2026 onward, so this is the normal case for season 1, not an edge case.

- [ ] **Step 1: Write the failing test**

```dart
// test/stats/season_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(
  String mode,
  DateTime date,
  List<(String id, int placement)> players, {
  List<DartThrow>? throws,
}) =>
    GameHistoryEntry(
      id: '${mode}_${date.millisecondsSinceEpoch}_${players.first.$1}',
      gameMode: mode,
      date: date,
      players: [
        for (final (id, placement) in players)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: placement, stats: const {})
      ],
      throwHistory: throws,
    );

DartThrow dart(int seat, int mult) => DartThrow(
      playerIndex: seat,
      segment: mult == 0 ? 0 : 20,
      multiplier: mult,
      points: 20 * mult,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
    );

void main() {
  final start = DateTime(2026, 4, 22);
  final end = DateTime(2026, 6, 30);
  final names = {'a': 'Ada', 'b': 'Bo'};
  final ratings = {'a': 1250.0, 'b': 1150.0};

  List<SeasonPlayerRow> run(List<GameHistoryEntry> h) => seasonStatsFrom(
      history: h, start: start, end: end, finalRatings: ratings, names: names);

  test('only games inside the range count', () {
    final rows = run([
      game('x01', DateTime(2026, 4, 21), [('a', 1), ('b', 2)]), // before
      game('x01', DateTime(2026, 5, 10), [('a', 1), ('b', 2)]), // inside
      game('x01', DateTime(2026, 7, 2), [('a', 1), ('b', 2)]), // after
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 1);
  });

  test('the range is inclusive on both days', () {
    final rows = run([
      game('x01', DateTime(2026, 4, 22, 9), [('a', 1), ('b', 2)]),
      game('x01', DateTime(2026, 6, 30, 23), [('a', 1), ('b', 2)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 2);
  });

  test('unrated modes are skipped, both cricket keys are kept', () {
    final rows = run([
      game('killer', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
      game('wildcard', DateTime(2026, 5, 2), [('a', 1), ('b', 2)]),
      game('cricket', DateTime(2026, 5, 3), [('a', 1), ('b', 2)]),
      game('cricket_cutthroat', DateTime(2026, 5, 4), [('a', 1), ('b', 2)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 2);
  });

  test('a shared best placement is a draw, not a win for either', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 5), [('a', 1), ('b', 1)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 1);
    expect(rows.firstWhere((r) => r.playerId == 'a').wins, 0);
    expect(rows.firstWhere((r) => r.playerId == 'b').wins, 0);
  });

  test('darts count from stored throws, a hit is multiplier > 0', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 6), [('a', 1), ('b', 2)],
          throws: [dart(0, 3), dart(0, 0), dart(1, 1)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.dartsThrown, 2);
    expect(a.dartsHit, 1);
    expect(a.gamesWithThrows, 1);
    expect(a.hitPercent, 50.0);
  });

  test('a season with no stored throws reports an unknown hit rate', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 7), [('a', 1), ('b', 2)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.gamesWithThrows, 0);
    expect(a.hitPercent, isNull,
        reason: 'season 1 has no throws before 18 June — unknown, not 0 %');
  });

  test('guests without a saved id contribute nothing', () {
    final rows = run([
      GameHistoryEntry(
        id: 'g',
        gameMode: 'x01',
        date: DateTime(2026, 5, 8),
        players: [
          GameHistoryPlayer(name: 'Guest', placement: 1, stats: const {}),
          GameHistoryPlayer(
              name: 'Ada', savedPlayerId: 'a', placement: 2, stats: const {}),
        ],
      ),
    ]);
    expect(rows.map((r) => r.playerId), ['a']);
    expect(rows.single.wins, 0);
  });

  test('rows carry the final rating and display name', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 9), [('a', 1), ('b', 2)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.rating, 1250.0);
    expect(a.name, 'Ada');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/stats/season_stats_test.dart`
Expected: FAIL — `lib/stats/season_stats.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/stats/season_stats.dart`. Shape:

```dart
/// Per-player figures for one season, derived from game history in a date
/// range rather than from cumulative counters.
///
/// That is not a stylistic choice: retroactive seasons have no snapshot taken
/// at their boundaries, so a cumulative-diff scheme could not build them at
/// all.
List<SeasonPlayerRow> seasonStatsFrom({ ... }) {
  // Whole-day inclusive bounds.
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  ...
}
```

For each entry inside the range whose mode `EloService.isRatedMode`, find the best (lowest) placement and whether it is shared. For each player with a non-null `savedPlayerId`: increment `games`, increment `wins` when their placement equals the best and it is not shared. When `entry.throwHistory` is non-null and non-empty, increment `gamesWithThrows` for every player who appears in it, and count that player's darts by `playerIndex` — `dartsThrown` for each, `dartsHit` when `multiplier > 0`.

Return one row per player id seen, with `rating: finalRatings[id] ?? 1200` and `name: names[id] ?? id`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/stats/season_stats_test.dart`
Expected: PASS — 9 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/stats/season_stats.dart test/stats/season_stats_test.dart
git commit -m "feat(seasons): per-player figures from history in a date range"
```

---

### Task 4: Replay and quarter arithmetic

**Files:**
- Create: `lib/stats/season_replay.dart`
- Test: `test/stats/season_replay_test.dart` (create)

**Interfaces:**
- Consumes: `EloService.updateRatings`, `EloService.isRatedMode`.
- Produces:
  - `void replayRatings({required List<GameHistoryEntry> history, required List<SavedPlayer> players, DateTime? from, DateTime? to})` — resets every player to 1200, then applies each rated game in date order.
  - `DateTime quarterStart(DateTime d)` — the first day of `d`'s calendar quarter.
  - `DateTime nextQuarterStart(DateTime d)` — the first day of the following quarter.

**Context:** The replay is what makes seasons 1 and 2 exist at all. Game history holds `date`, `gameMode` and per player `savedPlayerId` + `placement` — exactly the inputs `updateRatings` takes.

Sorting by date is load-bearing: history is stored newest-first, and Elo is order-dependent, so replaying in stored order would produce a different (wrong) answer.

The K-factor still keys off each player's **lifetime** `gamesPlayed`, which the replay does not touch. That is deliberate — the spec keeps K unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/stats/season_replay_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/season_replay.dart';

GameHistoryEntry game(String mode, DateTime date, List<(String, int)> ps) =>
    GameHistoryEntry(
      id: '$mode${date.day}',
      gameMode: mode,
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
    );

List<SavedPlayer> freshPlayers() => [
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 999),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1500),
    ];

void main() {
  group('quarter arithmetic', () {
    test('quarters start in January, April, July and October', () {
      expect(quarterStart(DateTime(2026, 8, 11)), DateTime(2026, 7, 1));
      expect(quarterStart(DateTime(2026, 1, 1)), DateTime(2026, 1, 1));
      expect(quarterStart(DateTime(2026, 12, 31)), DateTime(2026, 10, 1));
    });

    test('the next quarter rolls the year at the end of December', () {
      expect(nextQuarterStart(DateTime(2026, 8, 11)), DateTime(2026, 10, 1));
      expect(nextQuarterStart(DateTime(2026, 11, 2)), DateTime(2027, 1, 1));
    });
  });

  group('replay', () {
    test('every player starts from 1200, whatever they held before', () {
      final players = freshPlayers();
      replayRatings(history: const [], players: players);
      expect(players.every((p) => p.rating == 1200), isTrue);
    });

    test('a rated game moves the winner up and the loser down', () {
      final players = freshPlayers();
      replayRatings(
        history: [game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)])],
        players: players,
      );
      expect(players[0].rating, greaterThan(1200));
      expect(players[1].rating, lessThan(1200));
    });

    test('unrated games leave everyone at 1200', () {
      final players = freshPlayers();
      replayRatings(
        history: [
          game('killer', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
          game('wildcard', DateTime(2026, 5, 2), [('a', 1), ('b', 2)]),
        ],
        players: players,
      );
      expect(players.every((p) => p.rating == 1200), isTrue);
    });

    test('date order decides the outcome, not storage order', () {
      // History is stored newest-first, and Elo is order-dependent.
      final chronological = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('x01', DateTime(2026, 5, 2), [('b', 1), ('a', 2)]),
        game('x01', DateTime(2026, 5, 3), [('a', 1), ('b', 2)]),
      ];
      final forward = freshPlayers();
      replayRatings(history: chronological, players: forward);

      final reversed = freshPlayers();
      replayRatings(
          history: chronological.reversed.toList(), players: reversed);

      expect(reversed[0].rating, closeTo(forward[0].rating, 0.000001));
    });

    test('replaying twice gives the same answer', () {
      final history = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('cricket_cutthroat', DateTime(2026, 5, 2), [('b', 1), ('a', 2)]),
      ];
      final first = freshPlayers();
      replayRatings(history: history, players: first);
      final second = freshPlayers();
      replayRatings(history: history, players: second);
      expect(second[0].rating, first[0].rating);
    });

    test('from and to slice the history', () {
      final history = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('x01', DateTime(2026, 7, 4), [('a', 1), ('b', 2)]),
      ];
      final onlyJuly = freshPlayers();
      replayRatings(
          history: history, players: onlyJuly, from: DateTime(2026, 7, 1));

      final both = freshPlayers();
      replayRatings(history: history, players: both);

      expect(onlyJuly[0].rating, lessThan(both[0].rating),
          reason: 'one win moves less than two');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/stats/season_replay_test.dart`
Expected: FAIL — `lib/stats/season_replay.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
DateTime quarterStart(DateTime d) =>
    DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1);

DateTime nextQuarterStart(DateTime d) {
  final s = quarterStart(d);
  return s.month == 10 ? DateTime(s.year + 1, 1, 1) : DateTime(s.year, s.month + 3, 1);
}
```

`replayRatings` sets every player's `rating` to 1200, filters history to rated modes inside `[from, to]` (inclusive whole days when given), **sorts ascending by date**, and for each entry calls `EloService.updateRatings` with that entry's mode, its players' `savedPlayerId` list and `placement` list, and the same `players` list throughout so ratings compound.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/stats/season_replay_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/stats/season_replay.dart test/stats/season_replay_test.dart
git commit -m "feat(seasons): rating replay and quarter arithmetic"
```

---

### Task 5: Storage, migration and closing

**Files:**
- Create: `lib/services/season_service.dart`
- Modify: `lib/services/app_settings.dart`
- Test: `test/services/season_service_test.dart` (create)

**Interfaces:**
- Consumes: everything from Tasks 1, 3 and 4, plus `AppSettings.getLastBackupAt()` from plan 1.
- Produces:
  - `Future<List<SeasonRecord>> SeasonService.loadSeasons()`
  - `Future<SeasonRecord?> SeasonService.currentSeasonPreview()` — the open season as it stands right now, not stored.
  - `Future<bool> SeasonService.needsMigration()`
  - `Future<void> SeasonService.migrate()` — throws `StateError` when no backup has been exported.
  - `Future<bool> SeasonService.closeDueSeason()` — true when a boundary was crossed and a season was closed.
  - `AppSettings.getSeasonNumber/setSeasonNumber`, `getSeasonStart/setSeasonStart`, `getSeasonsMigrated/setSeasonsMigrated`.

**Context — the migration order is the spec's, and each step earns its place:**

1. Refuse without a backup. This is the only operation in the app that rewrites every rating.
2. Archive today's ratings as an `all-time` record (`number: 0`). They are the product of history that may predate what game history still holds, so they cannot be reconstructed afterwards.
3. Season 1: replay everything up to **30 June 2026**, store it, dated from the **oldest surviving game**.
4. Season 2: replay from **1 July 2026** onward and leave it open — it is the current quarter, so the live rating after migration is each player's Q3 standing.

`closeDueSeason` runs at app start, never on a timer: when the app opens and the stored season start belongs to an earlier quarter than today, the season closes then — before any game can be started. A boundary crossed at 21:00 on a Friday closes at the next launch.

**Idempotency matters more than it looks.** A migration interrupted after season 1 must resume, not reset season 1 a second time — so the flag is written last, and `migrate()` returns immediately when it is already set.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/season_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/season_service.dart';

GameHistoryEntry game(String mode, DateTime date, List<(String, int)> ps) =>
    GameHistoryEntry(
      id: '$mode${date.microsecondsSinceEpoch}',
      gameMode: mode,
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
    );

Future<void> seed({int juneGames = 12, int julyGames = 12}) async {
  await PlayerStorage.savePlayers([
    SavedPlayer(
        id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1310,
        gamesPlayed: 40, gamesWon: 20)
      ..unlockedAchievementIds.add('x_natural_talent'),
    SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1090),
  ]);
  for (var i = 0; i < juneGames; i++) {
    await GameHistoryService.record(
        game('x01', DateTime(2026, 5, 1 + i), [('a', 1), ('b', 2)]));
  }
  for (var i = 0; i < julyGames; i++) {
    await GameHistoryService.record(
        game('x01', DateTime(2026, 7, 1 + i), [('b', 1), ('a', 2)]));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migration refuses to run until a backup exists', () async {
    await seed();
    expect(await SeasonService.needsMigration(), isTrue);
    await expectLater(SeasonService.migrate(), throwsA(isA<StateError>()));
    expect(await SeasonService.loadSeasons(), isEmpty);
  });

  test('migration builds an all-time row plus two seasons', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final seasons = await SeasonService.loadSeasons();

    expect(seasons.map((s) => s.number), [0, 1]);
    expect(seasons.first.rows.firstWhere((r) => r.playerId == 'a').rating, 1310,
        reason: 'the all-time row preserves the pre-migration rating');
    expect(seasons.last.start, DateTime(2026, 5, 1),
        reason: 'season 1 starts at the oldest surviving game');
    expect(seasons.last.end, DateTime(2026, 6, 30));
  });

  test('season 2 is left open and is the live rating', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();

    expect(await AppSettings.getSeasonNumber(), 2);
    expect(await AppSettings.getSeasonStart(), DateTime(2026, 7, 1));
    // Bo won every July game, so Bo leads the open season.
    final players = await PlayerStorage.loadPlayers();
    final bo = players.firstWhere((p) => p.id == 'b');
    final ada = players.firstWhere((p) => p.id == 'a');
    expect(bo.rating, greaterThan(ada.rating));
  });

  test('a reset writes rating and nothing else', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final ada = (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'a');

    expect(ada.gamesPlayed, 40, reason: 'lifetime counters are untouched');
    expect(ada.gamesWon, 20);
    expect(ada.unlockedAchievementIds, contains('x_natural_talent'),
        reason: 'unlocks are never revoked by a reset');
  });

  test('migrating twice changes nothing', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final after = await SeasonService.loadSeasons();
    final rating =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'a').rating;

    await SeasonService.migrate();

    expect((await SeasonService.loadSeasons()).length, after.length);
    expect(
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'a').rating,
        rating);
    expect(await SeasonService.needsMigration(), isFalse);
  });

  test('an empty history migrates without throwing', () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026))]);
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();

    expect((await PlayerStorage.loadPlayers()).single.rating, 1200);
  });

  group('closing on a boundary', () {
    Future<void> migrated() async {
      await seed();
      await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));
      await SeasonService.migrate();
    }

    test('a season inside its own quarter does not close', () async {
      await migrated();
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 9, 30, 23)),
          isFalse);
      expect(await AppSettings.getSeasonNumber(), 2);
    });

    test('crossing into the next quarter closes it, once', () async {
      await migrated();

      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 1)),
          isTrue);
      expect(await AppSettings.getSeasonNumber(), 3);
      expect((await SeasonService.loadSeasons()).map((s) => s.number),
          [0, 1, 2]);
      expect((await PlayerStorage.loadPlayers()).every((p) => p.rating == 1200),
          isTrue);

      // Opening the app again must not close a second time.
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)),
          isFalse);
      expect((await SeasonService.loadSeasons()).length, 3);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/season_service_test.dart`
Expected: FAIL — `lib/services/season_service.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Add to `AppSettings`: `season_number` (int, default 1), `season_start` (ISO string, nullable) and `seasons_migrated` (bool, default false), following the existing getter/setter pairs.

Create `lib/services/season_service.dart` with the storage key `seasons_v1` holding a JSON list of `SeasonRecord`. `closeDueSeason` takes `{DateTime? now}` so the boundary can be tested without a clock injection framework — production calls it with no argument.

`migrate()`:

```dart
  static Future<void> migrate() async {
    if (await AppSettings.getSeasonsMigrated()) return;
    if (await AppSettings.getLastBackupAt() == null) {
      throw StateError('Export a backup before migrating — this rewrites '
          'every rating and cannot be undone.');
    }
    ...
  }
```

Season 1's `start` is the earliest date in history, or 1 April 2026 when history is empty; its `end` is 30 June 2026. After storing season 1, replay from 1 July, set `season_number` to 2 and `season_start` to `quarterStart(DateTime(2026, 7, 1))`, then set the migrated flag **last**.

`closeDueSeason` compares `quarterStart(now)` with the stored season start; when they differ, it builds the closing record from `seasonStatsFrom` over `[seasonStart, now-1 day]`, appends it, replays nothing (the live ratings are the season's result), resets every rating to 1200, bumps the number and sets the new start.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/season_service_test.dart`
Expected: PASS — 9 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/season_service.dart lib/services/app_settings.dart test/services/season_service_test.dart
git commit -m "feat(seasons): storage, gated migration and quarter close"
```

---

### Task 6: Season achievements and rating recalibration

**Files:**
- Modify: `lib/models/achievement.dart`
- Modify: `lib/data/achievement_catalog.dart`
- Modify: `lib/services/achievement_service.dart`
- Test: `test/services/season_achievements_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonRecord`/`SeasonPlayerRow` (Task 1).
- Produces:
  - `class SeasonStanding { final SeasonRecord season; final SeasonPlayerRow row; final int? rank; final int? previousRank; final int seasonsWon; final int podiums; final bool isFirstSeason; final bool qualifiedOnFinalDay; }`
  - `AchievementContext` gains `final SeasonStanding? season;`
  - `List<Achievement> AchievementService.evaluateSeasonClose(SavedPlayer, SeasonStanding)`

**Context:** Season achievements are **lifetime unlocks like every other** — only the trigger is new. Extending `AchievementContext` with a nullable `season` keeps one evaluation path: existing achievements read `ctx.player`/`ctx.outcome` and never see a season, and the twelve new ones return false when `ctx.season` is null, so they cannot fire at game end.

The twelve, with `x_season_` ids and globally unique names:

| id | name | test |
|---|---|---|
| `x_season_champion` | SEASON CHAMPION | `rank == 1` |
| `x_season_dynasty` | DYNASTY | `rank == 1 && previous season also won` |
| `x_season_untouchable` | UNTOUCHABLE | `rank == 1 && lead over 2nd >= 100` |
| `x_season_podium` | PODIUM REGULAR | `podiums >= 3` |
| `x_season_climb` | THE CLIMB | `previousRank != null && previousRank - rank >= 3` |
| `x_season_rookie` | ROOKIE SEASON | `isFirstSeason && row.qualified` |
| `x_season_iron_arm` | IRON ARM | `row.games >= 40` |
| `x_season_just_in_time` | JUST IN TIME | `qualifiedOnFinalDay` |
| `x_season_nine_and_out` | NINE AND OUT | `row.games == 9` |
| `x_season_almost_famous` | ALMOST FAMOUS | `rank == 2` |
| `x_season_participation` | PARTICIPATION TROPHY | `rank != null && rank == ranked.length && ranked.length > 1` |
| `x_season_ghost` | GHOST | `row.games > 0 && !row.qualified` |

Recalibration in the same catalogue, because quarterly resets made the old thresholds unreachable — `GRANDMASTER` at 1550 needs 92 clean wins inside one quarter:

| id | was | becomes |
|---|---|---|
| `x_master` | `rating >= 1450` | `rating >= 1400` |
| `x_grandmaster` | `rating >= 1550` | `rating >= 1450` |
| `x_the_floor` | `rating <= 100` | `rating <= 1100` |

Update each description string to match. Players already holding them keep them — unlocks are never revoked.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/season_achievements_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/services/achievement_service.dart';

SeasonPlayerRow row(String name, double rating, int games) => SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: 0,
      dartsThrown: 0,
      dartsHit: 0,
      gamesWithThrows: 0,
    );

SeasonRecord season(int n, List<SeasonPlayerRow> rows) => SeasonRecord(
    number: n, start: DateTime(2026, 7, 1), end: DateTime(2026, 9, 30), rows: rows);

SavedPlayer player() =>
    SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));

Set<String> idsFor(SeasonStanding s) =>
    AchievementService.evaluateSeasonClose(player(), s).map((a) => a.id).toSet();

void main() {
  final winner = row('Ada', 1300, 20);
  final second = row('Bo', 1180, 20);

  test('winning a season unlocks the champion badge', () {
    final ids = idsFor(SeasonStanding(
      season: season(2, [winner, second]),
      row: winner,
      rank: 1,
      previousRank: null,
      seasonsWon: 1,
      podiums: 1,
      isFirstSeason: false,
      qualifiedOnFinalDay: false,
    ));
    expect(ids, contains('x_season_champion'));
    expect(ids, isNot(contains('x_season_almost_famous')));
  });

  test('UNTOUCHABLE needs a 100-point lead', () {
    SeasonStanding standing(double runnerUp) => SeasonStanding(
          season: season(2, [winner, row('Bo', runnerUp, 20)]),
          row: winner,
          rank: 1,
          previousRank: null,
          seasonsWon: 1,
          podiums: 1,
          isFirstSeason: false,
          qualifiedOnFinalDay: false,
        );
    expect(idsFor(standing(1180)), contains('x_season_untouchable'));
    expect(idsFor(standing(1250)), isNot(contains('x_season_untouchable')));
  });

  test('THE CLIMB needs three places and a previous season', () {
    SeasonStanding standing(int? prev) => SeasonStanding(
          season: season(2, [winner, second]),
          row: winner,
          rank: 1,
          previousRank: prev,
          seasonsWon: 0,
          podiums: 0,
          isFirstSeason: false,
          qualifiedOnFinalDay: false,
        );
    expect(idsFor(standing(4)), contains('x_season_climb'));
    expect(idsFor(standing(3)), isNot(contains('x_season_climb')));
    expect(idsFor(standing(null)), isNot(contains('x_season_climb')),
        reason: 'a first season has nothing to climb from');
  });

  test('NINE AND OUT is exactly nine, and GHOST covers the rest', () {
    Set<String> at(int games) => idsFor(SeasonStanding(
          season: season(2, [row('Ada', 1200, games)]),
          row: row('Ada', 1200, games),
          rank: null,
          previousRank: null,
          seasonsWon: 0,
          podiums: 0,
          isFirstSeason: false,
          qualifiedOnFinalDay: false,
        ));
    expect(at(8), isNot(contains('x_season_nine_and_out')));
    expect(at(9), contains('x_season_nine_and_out'));
    expect(at(9), contains('x_season_ghost'));
    expect(at(10), isNot(contains('x_season_nine_and_out')));
    expect(at(10), isNot(contains('x_season_ghost')));
    expect(at(0), isNot(contains('x_season_ghost')),
        reason: 'someone who never played did not haunt the season');
  });

  test('season badges cannot fire at game end', () {
    // ctx.season is null there, so every season test must return false.
    for (final a in AchievementService.catalog
        .where((a) => a.id.startsWith('x_season_'))) {
      expect(a.milestoneTest!(AchievementContext(player: player())), isFalse,
          reason: a.id);
    }
  });

  test('the rating badges were recalibrated to the season range', () {
    Achievement byId(String id) =>
        AchievementService.catalog.firstWhere((a) => a.id == id);
    bool fires(String id, double rating) => byId(id).milestoneTest!(
        AchievementContext(
            player: SavedPlayer(
                id: 'a', name: 'A', createdAt: DateTime(2026), rating: rating)));

    expect(fires('x_master', 1400), isTrue);
    expect(fires('x_master', 1399), isFalse);
    expect(fires('x_grandmaster', 1450), isTrue);
    expect(fires('x_grandmaster', 1449), isFalse);
    expect(fires('x_the_floor', 1100), isTrue);
    expect(fires('x_the_floor', 1101), isFalse);
  });

  test('every season badge has a unique name and no mode suffix', () {
    final season = AchievementService.catalog
        .where((a) => a.id.startsWith('x_season_'))
        .toList();
    expect(season.length, 12);
    expect(season.map((a) => a.name).toSet().length, 12);
    final allNames = AchievementService.catalog.map((a) => a.name).toList();
    expect(allNames.toSet().length, allNames.length,
        reason: 'names are globally unique — no "(mode)" dupes');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/season_achievements_test.dart`
Expected: FAIL — `SeasonStanding` and `evaluateSeasonClose` are undefined.

- [ ] **Step 3: Write the implementation**

Add `SeasonStanding` to `lib/models/season.dart` (it is season data, not achievement data), add `final SeasonStanding? season;` to `AchievementContext` with a default of null, add the twelve entries to the catalogue with `category: AchievementCategory.milestone` for the top four and `quirky` for the bottom four, and add:

```dart
  /// Season badges are lifetime unlocks like every other — only the trigger is
  /// new. Called once per player when a season closes.
  static List<Achievement> evaluateSeasonClose(
      SavedPlayer player, SeasonStanding standing) {
    final ctx = AchievementContext(player: player, season: standing);
    return catalog
        .where((a) => a.id.startsWith('x_season_'))
        .where((a) => !player.unlockedAchievementIds.contains(a.id))
        .where((a) => a.milestoneTest?.call(ctx) ?? false)
        .toList();
  }
```

Expose the catalogue as `AchievementService.catalog` if it is currently private.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/season_achievements_test.dart && flutter test`
Expected: PASS. An existing achievement test asserting the old 1450/1550/100 thresholds will fail — update it to the new numbers rather than reverting the catalogue.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(seasons): twelve season achievements + recalibrated rating badges"
```

---

### Task 7: The SEASONS tab

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart`
- Create: `lib/widgets/dossedart/stats/seasons_tab.dart`
- Test: `test/screens/seasons_tab_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonService.loadSeasons()`, `SeasonService.currentSeasonPreview()`, `SeasonRecord`.

**Context:** The stats screen has a `TabController(length: 4)` at line 59 and labels `['PROFILE', 'MODES', 'HEATMAP', 'HISTORY']` at line 128. Both go to 5 with `'SEASONS'` appended, and a fifth child is added to the `TabBarView`.

The tab lists seasons newest first: number, date range and winner, with the open season at the top marked as running. Opening one shows the table — rank, name, rating, games, win %, hit % — with unqualified players beneath it as `UNQUALIFIED · n/10`. `hitPercent` of null renders as `—`, which is the normal case for season 1.

The `all-time` record (`number: 0`) is labelled `ALL-TIME · BEFORE SEASONS` rather than `SEASON 0`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/seasons_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/widgets/dossedart/stats/seasons_tab.dart';

SeasonPlayerRow row(String name, double rating, int games,
        {int wins = 0, int thrown = 0, int hit = 0, int withThrows = 0}) =>
    SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: thrown,
      dartsHit: hit,
      gamesWithThrows: withThrows,
    );

Future<void> pump(WidgetTester tester, List<SeasonRecord> seasons) async {
  tester.view.physicalSize = const Size(820, 1180);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SeasonsTab(seasons: seasons))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists seasons newest first with their winner', (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20), row('Bo', 1150, 20)]),
      SeasonRecord(
          number: 2,
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 9, 30),
          rows: [row('Bo', 1280, 20), row('Ada', 1160, 20)]),
    ]);

    expect(find.textContaining('SEASON 2'), findsOneWidget);
    expect(find.textContaining('SEASON 1'), findsOneWidget);
    final s2 = tester.getTopLeft(find.textContaining('SEASON 2')).dy;
    final s1 = tester.getTopLeft(find.textContaining('SEASON 1')).dy;
    expect(s2, lessThan(s1), reason: 'newest first');
  });

  testWidgets('the all-time record is not called season 0', (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 0,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 8, 11),
          rows: [row('Ada', 1276, 71)]),
    ]);

    expect(find.textContaining('ALL-TIME'), findsOneWidget);
    expect(find.textContaining('SEASON 0'), findsNothing);
  });

  testWidgets('unqualified players sit below the table with their count',
      (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20), row('Guest', 1400, 4)]),
    ]);

    expect(find.textContaining('UNQUALIFIED'), findsOneWidget);
    expect(find.textContaining('4/10'), findsOneWidget);
    // A 4-game player on 1400 must not be shown as the winner.
    expect(find.textContaining('GUEST'), findsOneWidget);
  });

  testWidgets('an unknown hit rate renders as a dash, not zero',
      (tester) async {
    await pump(tester, [
      SeasonRecord(
          number: 1,
          start: DateTime(2026, 4, 22),
          end: DateTime(2026, 6, 30),
          rows: [row('Ada', 1290, 20, wins: 10)]),
    ]);

    expect(find.text('0%'), findsNothing,
        reason: 'no throws stored means unknown, not a 0 % hit rate');
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('no seasons yet shows an empty state, not a crash',
      (tester) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('NO SEASONS'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/seasons_tab_test.dart`
Expected: FAIL — `lib/widgets/dossedart/stats/seasons_tab.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Build `SeasonsTab({required List<SeasonRecord> seasons})` as a pure `StatelessWidget` taking data — no service lookups — so it pumps in isolation. Rows collapse/expand on tap, or render expanded; either is fine as long as the assertions above hold.

Then wire it into `dossedart_stats_screen.dart`: `TabController(length: 5)`, `labels: const ['PROFILE', 'MODES', 'HEATMAP', 'HISTORY', 'SEASONS']`, load seasons with `SeasonService.loadSeasons()` in the existing load path, and append `SeasonsTab(seasons: _seasons)` to the `TabBarView` children.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/seasons_tab_test.dart && flutter analyze lib test && flutter test`
Expected: PASS. `dossedart_stats_screen_test.dart` may assert four tabs — update it to five.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(seasons): SEASONS tab in the stats screen"
```

---

### Task 8: Run the migration and the quarterly close at app start

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/screens/season_migration_screen.dart`
- Test: `test/screens/season_migration_screen_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonService.needsMigration/migrate/closeDueSeason`, `BackupService.exportAndShare`, `AppSettings.getLastBackupAt`.

**Context:** Two things happen at app start, in this order and never during a game:

1. `SeasonService.closeDueSeason()` — cheap, and a no-op unless a quarter boundary was crossed while the app was shut.
2. `SeasonService.needsMigration()` — when true, the migration screen is shown instead of the home screen.

The migration screen states what will happen, and offers **only** "Export backup" until `AppSettings.getLastBackupAt()` is non-null. Once it is, the second button unlocks. This is deliberate friction on the one operation that rewrites every rating, and the copy says so rather than hiding it.

Copy, exact:
- Title: `SEASONS`
- Body: `Ratings become quarterly. Everything played so far becomes Season 1, and this quarter becomes Season 2. Your games, stats and achievements are not affected.`
- Gate line, before a backup: `Export a backup first — this rewrites every rating and cannot be undone.`
- Buttons: `EXPORT BACKUP`, then `START SEASONS`

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/season_migration_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/screens/season_migration_screen.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/season_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('season_migration_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    BackupService.disableShareForTest = false;
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(home: SeasonMigrationScreen(onDone: () {})));
    await tester.pumpAndSettle();
  }

  testWidgets('without a backup, only the export is offered', (tester) async {
    await open(tester);

    expect(find.text('EXPORT BACKUP'), findsOneWidget);
    expect(
        find.textContaining('Export a backup first'), findsOneWidget);

    // START SEASONS must not do anything yet.
    await tester.tap(find.text('START SEASONS'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await SeasonService.needsMigration(), isTrue);
  });

  testWidgets('with a backup, the migration can run', (tester) async {
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));
    await open(tester);

    expect(find.textContaining('Export a backup first'), findsNothing);

    await tester.tap(find.text('START SEASONS'));
    await tester.pumpAndSettle();

    expect(await SeasonService.needsMigration(), isFalse);
  });

  testWidgets('the copy says what happens to stats and achievements',
      (tester) async {
    await open(tester);
    expect(
        find.textContaining(
            'Your games, stats and achievements are not affected'),
        findsOneWidget);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/season_migration_screen_test.dart`
Expected: FAIL — `lib/screens/season_migration_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Build `SeasonMigrationScreen({required VoidCallback onDone})` in the DOSSEDART language (tokens, `Press Start 2P` / `VT323`, no border-radius), holding `DateTime? _lastBackupAt` loaded in `initState` and refreshed after an export. `START SEASONS` is dimmed and inert until `_lastBackupAt != null`, mirroring the post-game action bar's rendered-but-dimmed rule. On success it calls `onDone`.

In `main.dart`, before deciding the home widget, `await SeasonService.closeDueSeason();` then `await SeasonService.needsMigration()` and show `SeasonMigrationScreen` when true.

- [ ] **Step 4: Run the full suite**

Run: `flutter analyze lib test && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(seasons): gated migration screen, and close a due season at app start"
```

---

## Self-Review

**Spec coverage.** §2 seasons and quarter boundaries → Tasks 4, 5, 8. §3 K unchanged → nothing changes it; Task 2 touches only the mode gate. §4 rated modes including both cricket keys → Task 2. §5 migration order → Task 5, surfaced by Task 8. §6 backup gate → Tasks 5 and 8. §7 qualification → Task 1 (`qualified`, `ranked`, `unqualified`) and Task 7 (display). §8 archive from history, hit % from stored counters → Tasks 1 and 3. §9 viewing → Task 7. §10 twelve achievements and recalibration → Task 6. §11 what a reset touches → asserted in Task 5. §12 testing → every bullet has a home. §13 storage caps → nothing raises them.

**One spec item deliberately deferred:** §8's `dartsThrown`/`dartsHit` stored on `GameHistoryPlayer.stats` at record time. Task 3 reads throws from the entry instead, which is correct for the retroactive seasons and for every game until the 100-entry pruning bites — at 93 recorded games that is far off. Adding the stored counters is a small follow-up that changes no interface here, and doing it now would mean writing a counter nothing reads for months. Flagged rather than silently dropped.

**Placeholder scan.** No TBDs. Every task carries real test code and either full implementation or an explicit shape plus the rules the implementer must satisfy.

**Type consistency.** `SeasonPlayerRow`/`SeasonRecord`/`kSeasonQualifyingGames` from Task 1 are used unchanged in 3, 5, 6 and 7. `isRatedMode` from Task 2 is used in 3 and 4. `replayRatings`/`quarterStart`/`nextQuarterStart` from Task 4 are used in 5. `SeasonStanding` is defined in Task 6 alongside the season model and consumed only there. `closeDueSeason({DateTime? now})` is tested with the parameter in Task 5 and called without it in Task 8.

**Ordering risk.** Task 2 changes a shared signature (`updateRatings` gains a required parameter) and will touch ~14 call sites; it is second so everything after builds on the final shape.
