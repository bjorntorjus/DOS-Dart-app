# Event Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A manually started/ended, named event (e.g. "Jobbfest 2026") whose games are rated on a separate 1200-reset table, kept out of the quarterly season, but recorded for history, stats and achievements as usual.

**Architecture:** Swap-and-snapshot — `EventService.start` snapshots every player's season rating into the event record and sets everyone to 1200; `end` restores them. Because `player.rating` *is* the live rating everywhere, the home podium and post-game deltas show the event automatically. History entries get an `eventId`; `seasonStatsFrom`/`replayRatings` skip tagged entries so the season never sees them. `EventService.active` is an in-memory mirror so the synchronous `EloService`/`StatsRecorder` can consult it.

**Tech Stack:** Flutter, SharedPreferences, `flutter_test`. Existing patterns: `SeasonService` (static service, JSON list in one prefs key), `SeasonPlayerRow` (reused for event rows), `BackupService.writeBackupFile`.

**Spec:** `docs/superpowers/specs/2026-08-25-event-mode-design.md`

## Global Constraints

- Code, comments, UI text in **English**; talk to Bjørn in Norwegian.
- Classic screens (`settings_screen.dart`, `home_screen.dart`): colors only via `Theme.of(context).colorScheme.<role>`.
- DOSSEDART screens/widgets: colors only via `DossedartTokens`; fonts `PressStart2P` / `VT323`.
- **No change to the Elo formula.** The only rating-maths change is "during an event, K = `_kNew` for everyone".
- Every step runs tests with `flutter test <file>`; the final task runs the full suite.
- Commit after every task with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.

---

### Task 1: `GameHistoryEntry.eventId`

**Files:**
- Modify: `lib/models/game_history.dart` (class `GameHistoryEntry`, lines 6–55)
- Test: `test/models/game_history_event_id_test.dart` (create)

**Interfaces:**
- Produces: `GameHistoryEntry.eventId` — `final String? eventId`, constructor named param `this.eventId`, JSON key `eventId` (omitted when null).

- [ ] **Step 1: Write the failing test**

```dart
// test/models/game_history_event_id_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';

void main() {
  GameHistoryEntry entry({String? eventId}) => GameHistoryEntry(
        id: '1',
        gameMode: 'x01',
        date: DateTime(2026, 8, 25, 20),
        players: [
          GameHistoryPlayer(
              name: 'Ada', savedPlayerId: 'a', placement: 1, stats: const {}),
        ],
        eventId: eventId,
      );

  test('eventId round-trips through JSON', () {
    final json = jsonDecode(jsonEncode(entry(eventId: 'evt_1').toJson()));
    final back = GameHistoryEntry.fromJson(json as Map<String, dynamic>);
    expect(back.eventId, 'evt_1');
  });

  test('a season game has no eventId and writes no key', () {
    final json = entry().toJson();
    expect(json.containsKey('eventId'), isFalse);
    expect(GameHistoryEntry.fromJson(json).eventId, isNull);
  });

  test('pre-event history without the key decodes to null', () {
    final json = entry().toJson()..remove('eventId');
    expect(GameHistoryEntry.fromJson(json).eventId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/game_history_event_id_test.dart`
Expected: compile error — `No named parameter with the name 'eventId'`.

- [ ] **Step 3: Add the field**

In `lib/models/game_history.dart`, class `GameHistoryEntry`:

```dart
  final List<DartThrow>? throwHistory;

  /// Set when the game was played inside an event (see EventService). Event
  /// games are recorded for history, stats and achievements like any other,
  /// but seasonStatsFrom/replayRatings skip them — they are not season games.
  final String? eventId;

  GameHistoryEntry({
    required this.id,
    required this.gameMode,
    required this.date,
    required this.players,
    this.gameConfig,
    this.durationSeconds,
    this.throwHistory,
    this.eventId,
  });
```

In `toJson()` add after the `throws` line:

```dart
        if (eventId != null) 'eventId': eventId,
```

In `fromJson` add after `throwHistory:`:

```dart
        eventId: json['eventId'] as String?,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/game_history_event_id_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_history.dart test/models/game_history_event_id_test.dart
git commit -m "feat(event): GameHistoryEntry.eventId

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `EventRecord` model

**Files:**
- Create: `lib/models/event.dart`
- Test: `test/models/event_record_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonPlayerRow` from `lib/models/season.dart`.
- Produces:
  ```dart
  class EventRecord {
    EventRecord({required id, required name, required start, end, required savedRatings, rows = const []});
    final String id; final String name; final DateTime start; final DateTime? end;
    final Map<String, double> savedRatings; final List<SeasonPlayerRow> rows;
    bool get isOpen; List<SeasonPlayerRow> get ranked; String? get winnerName;
    EventRecord copyWith({DateTime? end, List<SeasonPlayerRow>? rows});
    Map<String, dynamic> toJson(); factory EventRecord.fromJson(Map<String, dynamic>);
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/models/event_record_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/season.dart';

SeasonPlayerRow row(String id, double rating, {int games = 1, int wins = 0}) =>
    SeasonPlayerRow(
      playerId: id,
      name: id,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: 0,
      dartsHit: 0,
      gamesWithThrows: 0,
    );

void main() {
  test('open event: isOpen, no rows, no winner', () {
    final e = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: {'a': 1310, 'b': 1090},
    );
    expect(e.isOpen, isTrue);
    expect(e.rows, isEmpty);
    expect(e.winnerName, isNull);
  });

  test('ranked ignores the season qualifying threshold — one game is enough',
      () {
    final e = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      end: DateTime(2026, 8, 25, 23),
      savedRatings: const {},
      rows: [row('a', 1216, games: 1), row('b', 1184, games: 1), row('c', 1216, games: 2)],
    );
    // Rating desc, ties on name.
    expect(e.ranked.map((r) => r.playerId), ['a', 'c', 'b']);
    expect(e.winnerName, 'a');
    expect(e.isOpen, isFalse);
  });

  test('JSON round-trip keeps savedRatings, rows and a null end', () {
    final open = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: {'a': 1310.5},
    );
    final back = EventRecord.fromJson(
        jsonDecode(jsonEncode(open.toJson())) as Map<String, dynamic>);
    expect(back.id, 'evt_1');
    expect(back.name, 'Jobbfest 2026');
    expect(back.end, isNull);
    expect(back.savedRatings, {'a': 1310.5});

    final closed = open.copyWith(end: DateTime(2026, 8, 25, 23), rows: [row('a', 1250)]);
    final back2 = EventRecord.fromJson(
        jsonDecode(jsonEncode(closed.toJson())) as Map<String, dynamic>);
    expect(back2.end, DateTime(2026, 8, 25, 23));
    expect(back2.rows.single.rating, 1250);
    // copyWith never touches identity or the snapshot.
    expect(back2.id, 'evt_1');
    expect(back2.savedRatings, {'a': 1310.5});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/event_record_test.dart`
Expected: compile error — `lib/models/event.dart` does not exist.

- [ ] **Step 3: Write the model**

```dart
// lib/models/event.dart
import 'season.dart';

/// A named, manually bounded rating event — a party night rated on its own
/// 1200-reset table so the quarterly season is untouched.
///
/// Swap-and-snapshot: [savedRatings] holds every player's season rating as it
/// stood when the event started; EventService writes 1200 into `player.rating`
/// for the duration and restores from here at the end. See
/// `docs/superpowers/specs/2026-08-25-event-mode-design.md`.
class EventRecord {
  const EventRecord({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    required this.savedRatings,
    this.rows = const [],
  });

  final String id;
  final String name;
  final DateTime start;

  /// Null while the event is open.
  final DateTime? end;

  /// Season ratings put aside at start, by player id. Players created during
  /// the event are absent and restore to 1200 — which is their untouched
  /// season rating anyway.
  final Map<String, double> savedRatings;

  /// Final table. Empty while open; [SeasonPlayerRow] is reused as-is, its
  /// `qualified` getter is simply never consulted for events.
  final List<SeasonPlayerRow> rows;

  bool get isOpen => end == null;

  /// Everyone with at least one game, best rating first, ties on name. No
  /// qualifying threshold — Bjørn's call: one sick game is allowed to send
  /// you to the sky, and everyone knows one game is not the whole picture.
  List<SeasonPlayerRow> get ranked {
    final out = rows.where((r) => r.games > 0).toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.name.compareTo(b.name);
      });
    return out;
  }

  String? get winnerName => ranked.isEmpty ? null : ranked.first.name;

  EventRecord copyWith({DateTime? end, List<SeasonPlayerRow>? rows}) =>
      EventRecord(
        id: id,
        name: name,
        start: start,
        end: end ?? this.end,
        savedRatings: savedRatings,
        rows: rows ?? this.rows,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
        'savedRatings': savedRatings,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory EventRecord.fromJson(Map<String, dynamic> json) => EventRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        start: DateTime.parse(json['start'] as String),
        end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
        savedRatings: (json['savedRatings'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        rows: ((json['rows'] as List?) ?? const [])
            .map((r) => SeasonPlayerRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/event_record_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/event.dart test/models/event_record_test.dart
git commit -m "feat(event): EventRecord model

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Season maths ignores event games (`seasonStatsFrom`, `replayRatings`, `_qualifiedOnFinalDay`)

**Files:**
- Modify: `lib/stats/season_stats.dart` (function `seasonStatsFrom`)
- Modify: `lib/stats/season_replay.dart` (function `replayRatings`, the `history.where` filter)
- Modify: `lib/services/season_service.dart` (`_qualifiedOnFinalDay`, the `history.where` filter ~line 128)
- Test: `test/stats/season_stats_event_test.dart` (create)

**Interfaces:**
- Produces: `seasonStatsFrom({..., String? eventId})` — `null` = season mode (entries with an eventId are skipped); non-null = event mode (only entries with that eventId count). Date bounds apply in both modes.

- [ ] **Step 1: Write the failing test**

```dart
// test/stats/season_stats_event_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/season_replay.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(DateTime date, List<(String, int)> ps, {String? eventId}) =>
    GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}$eventId',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
      eventId: eventId,
    );

void main() {
  final history = [
    game(DateTime(2026, 8, 20), [('a', 1), ('b', 2)]),
    game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: 'evt_1'),
    game(DateTime(2026, 8, 25, 21), [('b', 1), ('a', 2)], eventId: 'evt_1'),
    game(DateTime(2026, 8, 25, 22), [('a', 1), ('b', 2)], eventId: 'evt_other'),
  ];
  final names = {'a': 'Ada', 'b': 'Bo'};

  test('season mode skips every event game', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 9, 30),
      finalRatings: const {},
      names: names,
    );
    final a = rows.singleWhere((r) => r.playerId == 'a');
    final b = rows.singleWhere((r) => r.playerId == 'b');
    expect(a.games, 1);
    expect(a.wins, 1);
    expect(b.games, 1);
    expect(b.wins, 0);
  });

  test('event mode counts only games with that eventId', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 8, 25),
      end: DateTime(2026, 8, 26),
      finalRatings: const {'b': 1232},
      names: names,
      eventId: 'evt_1',
    );
    final a = rows.singleWhere((r) => r.playerId == 'a');
    final b = rows.singleWhere((r) => r.playerId == 'b');
    expect(b.games, 2);
    expect(b.wins, 2);
    expect(b.rating, 1232);
    expect(a.games, 2);
    expect(a.wins, 0);
  });

  test('event mode still honours the date bounds', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 8, 26),
      end: DateTime(2026, 8, 27),
      finalRatings: const {},
      names: names,
      eventId: 'evt_1',
    );
    expect(rows, isEmpty);
  });

  test('replayRatings ignores event games', () {
    final a = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    final b = SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026));
    replayRatings(history: history, players: [a, b]);
    // Only the 20 Aug season game counts: a beat b once at default K.
    expect(a.rating, closeTo(1216, 0.001));
    expect(b.rating, closeTo(1184, 0.001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/stats/season_stats_event_test.dart`
Expected: compile error — `No named parameter with the name 'eventId'` on `seasonStatsFrom`.

- [ ] **Step 3: Add the filter to `seasonStatsFrom`**

In `lib/stats/season_stats.dart`, extend the signature and the loop:

```dart
List<SeasonPlayerRow> seasonStatsFrom({
  required List<GameHistoryEntry> history,
  required DateTime start,
  required DateTime end,
  required Map<String, double> finalRatings,
  required Map<String, String> names,
  String? eventId,
}) {
```

Update the doc comment above it with one paragraph:

```dart
/// [eventId] selects the table being built. Null is season mode: entries that
/// carry ANY eventId are skipped, because event games are not season games.
/// A value is event mode: only entries with exactly that id count. Date bounds
/// apply either way — one function, no fork.
```

Inside the `for (final entry in history)` loop, right after the date check:

```dart
    if (eventId == null ? entry.eventId != null : entry.eventId != eventId) {
      continue;
    }
```

- [ ] **Step 4: Skip event games in `replayRatings`**

In `lib/stats/season_replay.dart`, inside the `history.where((e) { ... })` filter, add as the first line:

```dart
    if (e.eventId != null) return false; // event games never touch the season
```

- [ ] **Step 5: Skip event games in `_qualifiedOnFinalDay`**

In `lib/services/season_service.dart`, `_qualifiedOnFinalDay`, the `.where((e) => ...)` chain gets one more condition after `EloService.isRatedMode(e.gameMode) &&`:

```dart
            e.eventId == null &&
```

- [ ] **Step 6: Run the new test and the existing season tests**

Run: `flutter test test/stats test/services/season_service_test.dart test/services/season_close_awards_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/stats/season_stats.dart lib/stats/season_replay.dart lib/services/season_service.dart test/stats/season_stats_event_test.dart
git commit -m "feat(event): season maths skips event games; seasonStatsFrom eventId filter

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `EventService` — storage, start, end

**Files:**
- Create: `lib/services/event_service.dart`
- Test: `test/services/event_service_test.dart` (create)

**Interfaces:**
- Consumes: `EventRecord` (Task 2), `seasonStatsFrom(eventId:)` (Task 3), `BackupService.writeBackupFile`, `PlayerStorage.loadPlayers/savePlayers`, `GameHistoryService.load`, `SeasonService.closeDueSeason`.
- Produces:
  ```dart
  class EventService {
    static EventRecord? active;
    static Future<void> load();
    static Future<List<EventRecord>> loadEvents();
    static Future<EventRecord> start(String name, {DateTime? now});
    static Future<EventRecord> end({DateTime? now});
    static Future<EventRecord?> livePreview({DateTime? now});
    @visibleForTesting static void resetForTest();
  }
  ```
  Note: the `closeDueSeason` guard (Task 5) is what makes step 5 of `end()` meaningful; this task only calls it.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/event_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';

GameHistoryEntry game(DateTime date, List<(String, int)> ps, {String? eventId}) =>
    GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}$eventId',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
      eventId: eventId,
    );

Future<void> seed() async {
  await PlayerStorage.savePlayers([
    SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1310),
    SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1090)
      ..archived = true,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('event_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('start snapshots every rating (archived too), resets to 1200, writes a backup',
      () async {
    await seed();
    final e = await EventService.start('Jobbfest 2026', now: DateTime(2026, 8, 25, 19));

    expect(e.isOpen, isTrue);
    expect(e.name, 'Jobbfest 2026');
    expect(e.savedRatings, {'a': 1310, 'b': 1090});
    expect(EventService.active?.id, e.id);

    final players = await PlayerStorage.loadPlayers();
    expect(players.every((p) => p.rating == 1200), isTrue);
    expect(tempDir.listSync().whereType<File>(), isNotEmpty);
    expect((await EventService.loadEvents()).single.isOpen, isTrue);
  });

  test('load() at boot rehydrates the open event', () async {
    await seed();
    await EventService.start('Jobbfest 2026');
    EventService.resetForTest();
    expect(EventService.active, isNull);
    await EventService.load();
    expect(EventService.active?.name, 'Jobbfest 2026');
  });

  test('start refuses while one is open; end refuses without one', () async {
    await seed();
    await expectLater(EventService.end(), throwsA(isA<StateError>()));
    await EventService.start('Jobbfest 2026');
    await expectLater(EventService.start('Another'), throwsA(isA<StateError>()));
  });

  test('start rejects a blank name', () async {
    await seed();
    await expectLater(EventService.start('   '), throwsA(isA<ArgumentError>()));
    expect(EventService.active, isNull);
  });

  test('end builds the table from event games only and restores season ratings',
      () async {
    await seed();
    await GameHistoryService.record(
        game(DateTime(2026, 8, 20), [('a', 1), ('b', 2)]));
    final e = await EventService.start('Jobbfest 2026', now: DateTime(2026, 8, 25, 19));

    // Simulate the evening: Bo wins twice, ratings moved by the game screens.
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: e.id));
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 21), [('b', 1), ('a', 2)], eventId: e.id));
    final mid = await PlayerStorage.loadPlayers();
    mid.singleWhere((p) => p.id == 'b').rating = 1260;
    mid.singleWhere((p) => p.id == 'a').rating = 1140;
    // A player created mid-event: no snapshot entry.
    mid.add(SavedPlayer(id: 'c', name: 'Cy', createdAt: DateTime(2026), rating: 1180));
    await PlayerStorage.savePlayers(mid);

    final closed = await EventService.end(now: DateTime(2026, 8, 25, 23, 30));

    expect(closed.isOpen, isFalse);
    expect(closed.end, DateTime(2026, 8, 25, 23, 30));
    expect(closed.winnerName, 'Bo');
    final bo = closed.rows.singleWhere((r) => r.playerId == 'b');
    expect(bo.games, 2);
    expect(bo.wins, 2);
    expect(bo.rating, 1260);
    // The 20 Aug season game is not in the event table.
    expect(closed.rows.singleWhere((r) => r.playerId == 'a').games, 2);

    final after = {for (final p in await PlayerStorage.loadPlayers()) p.id: p.rating};
    expect(after, {'a': 1310, 'b': 1090, 'c': 1200});
    expect(EventService.active, isNull);
    final stored = await EventService.loadEvents();
    expect(stored.single.isOpen, isFalse);
    expect(stored.single.id, e.id);
  });

  test('livePreview ranks the open event from history so far', () async {
    await seed();
    final e = await EventService.start('Jobbfest 2026', now: DateTime(2026, 8, 25, 19));
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: e.id));
    final players = await PlayerStorage.loadPlayers();
    players.singleWhere((p) => p.id == 'b').rating = 1232;
    await PlayerStorage.savePlayers(players);

    final live = await EventService.livePreview(now: DateTime(2026, 8, 25, 21));
    expect(live, isNotNull);
    expect(live!.isOpen, isTrue);
    expect(live.ranked.first.playerId, 'b');
    expect(live.ranked.first.rating, 1232);
    expect(live.ranked.length, 2);
  });

  test('livePreview is null when no event is open', () async {
    expect(await EventService.livePreview(), isNull);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/event_service_test.dart`
Expected: compile error — `event_service.dart` does not exist.

- [ ] **Step 3: Write the service**

```dart
// lib/services/event_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../stats/season_stats.dart';
import 'backup_service.dart';
import 'game_history_service.dart';
import 'game_logger.dart';
import 'player_storage.dart';
import 'season_service.dart';

/// A manually bounded rating event — see
/// `docs/superpowers/specs/2026-08-25-event-mode-design.md`.
///
/// Swap-and-snapshot: [start] puts every player's season rating aside and sets
/// them all to 1200; [end] restores them. Because `player.rating` IS the live
/// rating everywhere, the home podium and post-game deltas show the event for
/// free. The places that must NOT see event games (season table, replay,
/// rating-history graph, season close) each check [active] or the history
/// entry's `eventId`.
class EventService {
  static const _key = 'events_v1';

  /// In-memory mirror of the open event, or null. Loaded once at boot by
  /// [load] and kept current by [start]/[end]. Exists because
  /// EloService.updateRatings and StatsRecorder.recordGame are synchronous
  /// and cannot await preferences.
  static EventRecord? active;

  @visibleForTesting
  static void resetForTest() => active = null;

  /// Call once at app start, BEFORE SeasonService.closeDueSeason — the close
  /// guard reads [active].
  static Future<void> load() async {
    final all = await loadEvents();
    active = all.where((e) => e.isOpen).lastOrNull;
  }

  static Future<List<EventRecord>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => EventRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Same stance as SeasonService: a broken archive must not block play.
      // Keep the raw text for the backup export to rescue.
      await prefs.setString('${_key}_corrupt', raw);
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> _save(List<EventRecord> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  /// Opens an event. Order matters:
  ///  1. backup file — the only copy of the season ratings outside memory
  ///     until the record is appended, and the recovery path if step 2 or 3
  ///     is interrupted;
  ///  2. snapshot + reset every player (archived included — they may be
  ///     un-archived during the evening);
  ///  3. append the open record and mirror it into [active].
  static Future<EventRecord> start(String name, {DateTime? now}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be blank');
    if (active != null) throw StateError('An event is already open: ${active!.name}');

    await BackupService.writeBackupFile();

    final at = now ?? DateTime.now();
    final players = await PlayerStorage.loadPlayers();
    final event = EventRecord(
      id: 'evt_${at.millisecondsSinceEpoch}',
      name: trimmed,
      start: at,
      savedRatings: {for (final p in players) p.id: p.rating},
    );
    for (final p in players) {
      p.rating = 1200;
    }
    await PlayerStorage.savePlayers(players);

    final all = await loadEvents()..add(event);
    await _save(all);
    active = event;
    return event;
  }

  /// The open event's table as it stands right now — computed, never stored.
  static Future<EventRecord?> livePreview({DateTime? now}) async {
    final open = active;
    if (open == null) return null;
    final players = await PlayerStorage.loadPlayers();
    return open.copyWith(
      rows: seasonStatsFrom(
        history: await GameHistoryService.load(),
        start: open.start,
        end: now ?? DateTime.now(),
        finalRatings: {for (final p in players) p.id: p.rating},
        names: {for (final p in players) p.id: p.name},
        eventId: open.id,
      ),
    );
  }

  /// Closes the open event. Order matters:
  ///  1. final table from the event's own games, with the live (event) ratings;
  ///  2. restore season ratings — players created mid-event have no snapshot
  ///     and get 1200, which is their untouched season rating anyway;
  ///  3. persist the closed record, clear [active];
  ///  4. backup AFTER the restore so the file is the post-event truth. A
  ///     failure here is logged, not thrown — the data is already consistent;
  ///  5. a quarter boundary that passed during the event was held back by
  ///     SeasonService.closeDueSeason's event guard; run it now.
  static Future<EventRecord> end({DateTime? now}) async {
    final open = active;
    if (open == null) throw StateError('No event is open');
    final at = now ?? DateTime.now();

    final players = await PlayerStorage.loadPlayers();
    final closed = open.copyWith(
      end: at,
      rows: seasonStatsFrom(
        history: await GameHistoryService.load(),
        start: open.start,
        end: at,
        finalRatings: {for (final p in players) p.id: p.rating},
        names: {for (final p in players) p.id: p.name},
        eventId: open.id,
      ),
    );

    for (final p in players) {
      p.rating = open.savedRatings[p.id] ?? 1200;
    }
    await PlayerStorage.savePlayers(players);

    final all = await loadEvents();
    final idx = all.indexWhere((e) => e.id == open.id);
    if (idx >= 0) {
      all[idx] = closed;
    } else {
      all.add(closed);
    }
    await _save(all);
    active = null;

    try {
      await BackupService.writeBackupFile();
    } catch (e, st) {
      GameLogger.instance.logError('Post-event backup failed', e, st);
    }

    await SeasonService.closeDueSeason(now: at);
    return closed;
  }
}
```

Check `GameLogger.instance.logError(String, Object, StackTrace)` exists with that signature (it is used in `main.dart` line ~60); if the parameter types differ, match them.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/event_service_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/event_service.dart test/services/event_service_test.dart
git commit -m "feat(event): EventService start/end with swap-and-snapshot ratings

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Live-game hooks — K during event, no rating snapshot, `eventId` on entries, season-close guard

**Files:**
- Modify: `lib/services/elo_service.dart` (`updateRatings`, the `kI`/`kJ` lines ~118–119)
- Modify: `lib/services/stats_recorder.dart` (`recordGame` rating-history block ~104–111; `buildEntry` return ~185)
- Modify: `lib/services/season_service.dart` (`closeDueSeason`, first lines)
- Test: `test/services/event_live_hooks_test.dart` (create)

**Interfaces:**
- Consumes: `EventService.active` (Task 4), `GameHistoryEntry.eventId` (Task 1).
- Produces: no new API. Behavioural contract: while `EventService.active != null` — every player uses `_kNew`; `recordGame` appends no `RatingSnapshot`; persisted entries carry `eventId = active.id`; `closeDueSeason` returns `false`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/event_live_hooks_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/elo_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/season_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

/// Sets EventService.active directly — these tests are about what the live
/// game path does WHILE an event is open, not about opening one.
void openEvent() => EventService.active = EventRecord(
      id: 'evt_test',
      name: 'Test night',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: const {},
    );

SavedPlayer sp(String id, {int games = 0}) =>
    SavedPlayer(id: id, name: id, createdAt: DateTime(2020), gamesPlayed: games);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
  });
  tearDown(EventService.resetForTest);

  group('EloService K during an event', () {
    test('experienced players move at the new-player K (32, not 16)', () {
      openEvent();
      final a = sp('a', games: 100), b = sp('b', games: 100);
      EloService.updateRatings(
          gameMode: 'x01', playerIds: ['a', 'b'], placements: [1, 2], savedPlayers: [a, b]);
      expect(a.rating, closeTo(1216, 0.001));
      expect(b.rating, closeTo(1184, 0.001));
    });

    test('outside an event the experienced K still applies', () {
      final a = sp('a', games: 100), b = sp('b', games: 100);
      EloService.updateRatings(
          gameMode: 'x01', playerIds: ['a', 'b'], placements: [1, 2], savedPlayers: [a, b]);
      expect(a.rating, closeTo(1208, 0.001));
    });
  });

  group('StatsRecorder during an event', () {
    test('no rating snapshot is appended, entry carries the eventId', () async {
      openEvent();
      final a = sp('a'), b = sp('b');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        playerNames: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.ratingHistory, isEmpty);
      expect(a.modeStats['x01']?.played, 1); // stats still recorded
      // GameHistoryService.record is fire-and-forget; let it land.
      await Future<void>.delayed(Duration.zero);
      final history = await GameHistoryService.load();
      expect(history.single.eventId, 'evt_test');
    });

    test('outside an event a snapshot is appended and eventId is null', () async {
      final a = sp('a'), b = sp('b');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        playerNames: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.ratingHistory, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect((await GameHistoryService.load()).single.eventId, isNull);
    });
  });

  group('SeasonService.closeDueSeason during an event', () {
    test('a due boundary does not close while an event is open', () async {
      await PlayerStorage.savePlayers([sp('a')..rating = 1300]);
      await AppSettings.setSeasonNumber(2);
      await AppSettings.setSeasonStart(DateTime(2026, 7, 1));
      openEvent();

      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)), isFalse);
      expect(await SeasonService.loadSeasons(), isEmpty);
      expect((await PlayerStorage.loadPlayers()).single.rating, 1300);

      EventService.resetForTest();
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)), isTrue);
      expect((await SeasonService.loadSeasons()).single.number, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/event_live_hooks_test.dart`
Expected: FAIL — K test gets 1208 not 1216; snapshot test finds `ratingHistory` non-empty and `eventId` null; close test gets `true`.

- [ ] **Step 3: K override in `EloService.updateRatings`**

Add `import 'event_service.dart';` to `lib/services/elo_service.dart`. Replace the two K lines:

```dart
        // During an event everyone moves at the new-player K: the table was
        // just reset to 1200 and an evening holds a handful of games, so the
        // experienced K would barely separate anyone. The formula is untouched.
        final eventK = EventService.active != null;
        final kI = eventK ? _kNew : kFactor(indexToSaved[i]!.gamesPlayed);
        final kJ = eventK ? _kNew : kFactor(indexToSaved[j]!.gamesPlayed);
```

- [ ] **Step 4: Snapshot skip + `eventId` in `StatsRecorder`**

Add `import 'event_service.dart';` to `lib/services/stats_recorder.dart`. Wrap the rating-history block in `recordGame`:

```dart
      // Rating history snapshot — compute placement among ALL saved players.
      // Skipped during an event: the profile graph is the SEASON graph, and
      // the 1200 reset plus event swings would show up as a dip that never
      // happened to the season rating.
      if (EventService.active == null) {
        final sortedByRating = List<SavedPlayer>.from(savedPlayers)
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final ratingPlacement =
            sortedByRating.indexWhere((s) => s.id == sp.id) + 1;
        sp.ratingHistory.add(RatingSnapshot(
            date: now, rating: sp.rating, placement: ratingPlacement));
      }
```

In `buildEntry`'s `return GameHistoryEntry(` add:

```dart
      eventId: EventService.active?.id,
```

- [ ] **Step 5: Guard in `closeDueSeason`**

Add `import 'event_service.dart';` to `lib/services/season_service.dart`. First lines of `closeDueSeason`:

```dart
  static Future<bool> closeDueSeason({DateTime? now}) async {
    // Never mid-event: the live ratings are the EVENT's, and closing would
    // archive them as the season's. EventService.end() calls this again once
    // the season ratings are back.
    if (EventService.active != null) return false;
```

- [ ] **Step 6: Run the new test plus every test touching these services**

Run: `flutter test test/services`
Expected: `All tests passed!` (existing Elo/stats-recorder tests run with `active == null` and are unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/services/elo_service.dart lib/services/stats_recorder.dart lib/services/season_service.dart test/services/event_live_hooks_test.dart
git commit -m "feat(event): event K, no season snapshot, eventId on entries, close guard

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Boot wiring in `main.dart`

**Files:**
- Modify: `lib/main.dart` (~line 68, before `SeasonService.closeDueSeason()`)

**Interfaces:**
- Consumes: `EventService.load()` (Task 4).

- [ ] **Step 1: Add the load call**

Add `import 'services/event_service.dart';` next to the other service imports. Replace the seasons comment block + call:

```dart
  // Events, then seasons, in this order and never during a game:
  //  0. rehydrate the open event (if any) — closeDueSeason's guard reads it;
  //  1. close a season whose quarter ended while the app was shut — cheap,
  //     and a no-op the rest of the time (and while an event is open);
  //  2. decide whether the one-time migration gate has to show instead of
  //     the home screen.
  await EventService.load();
  await SeasonService.closeDueSeason();
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(event): load open event at boot before season close

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Settings › EVENT section

**Files:**
- Create: `lib/widgets/event_tile.dart`
- Modify: `lib/screens/settings_screen.dart` (insert between the ELO RATING card and the TTS header, ~line 285)
- Test: `test/widgets/event_tile_test.dart` (create)

**Interfaces:**
- Consumes: `EventService.active/start/end`, `EventService.livePreview` (for the game count), `BackupService.exportAndShare`.
- Produces: `class EventTile extends StatefulWidget { const EventTile({super.key}); }` — self-contained, owns its own state like `BackupTile`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/event_tile_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/event_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('event_tile');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1310),
    ]);
  });
  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: EventTile())));
    await t.pumpAndSettle();
  }

  testWidgets('idle: Start event opens a dialog; blank name keeps Start disabled',
      (tester) async {
    await pump(tester);
    expect(find.text('Start event'), findsOneWidget);
    expect(find.text('End event'), findsNothing);

    await tester.tap(find.text('Start event'));
    await tester.pumpAndSettle();
    final start = find.widgetWithText(FilledButton, 'Start');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Jobbfest 2026');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(EventService.active?.name, 'Jobbfest 2026');
    expect(find.text('JOBBFEST 2026'), findsOneWidget);
    expect(find.text('End event'), findsOneWidget);
    expect((await PlayerStorage.loadPlayers()).single.rating, 1200);
  });

  testWidgets('open: End event confirms, then restores ratings and returns to idle',
      (tester) async {
    await EventService.start('Jobbfest 2026');
    await pump(tester);
    expect(find.text('JOBBFEST 2026'), findsOneWidget);

    await tester.tap(find.text('End event'));
    await tester.pumpAndSettle();
    expect(find.textContaining('End Jobbfest 2026?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'End'));
    await tester.pumpAndSettle();

    expect(EventService.active, isNull);
    expect(find.text('Start event'), findsOneWidget);
    expect((await PlayerStorage.loadPlayers()).single.rating, 1310);
  });

  testWidgets('open for more than a day shows the reminder', (tester) async {
    await EventService.start('Jobbfest 2026',
        now: DateTime.now().subtract(const Duration(days: 2)));
    await pump(tester);
    expect(find.textContaining('open for 2 days'), findsOneWidget);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/event_tile_test.dart`
Expected: compile error — `event_tile.dart` does not exist.

- [ ] **Step 3: Write the tile**

```dart
// lib/widgets/event_tile.dart
import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/backup_service.dart';
import '../services/event_service.dart';

/// Settings entry point for rating events (party nights on their own table).
///
/// Owns its own state like BackupTile: reads EventService.active, starts and
/// ends events, and re-renders itself — the Settings screen just places it.
class EventTile extends StatefulWidget {
  const EventTile({super.key});

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _busy = false;
  int? _games;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _refreshGames();
  }

  Future<void> _refreshGames() async {
    final live = await EventService.livePreview();
    if (!mounted) return;
    setState(() => _games = live?.rows.fold<int>(0, (n, r) => n + r.games));
  }

  String _started(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _start() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Start event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Event name'),
                onChanged: (_) => setLocal(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Everyone starts at 1200. Games count for stats and '
                'achievements but not for the season. A backup is written first.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    await _run(() => EventService.start(name));
  }

  Future<void> _end(EventRecord open) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End ${open.name}?'),
        content: const Text(
            'Season ratings are restored and the table is archived under '
            'Stats › Seasons.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(EventService.end);
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
      await _refreshGames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Event failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = EventService.active;

    if (open == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A party night on its own rating table. Everyone starts at '
                '1200; the season is not affected.',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.celebration),
                label: const Text('Start event'),
              ),
            ],
          ),
        ),
      );
    }

    final openFor = DateTime.now().difference(open.start);
    final stale = openFor.inHours >= 24;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(open.name.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'started ${_started(open.start)}'
              '${_games == null ? '' : ' · $_games games'}'
              '${stale ? ' · open for ${openFor.inDays} days' : ''}',
              style: TextStyle(
                  fontSize: 13,
                  color: stale ? cs.secondary : cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _end(open),
                  icon: const Icon(Icons.flag),
                  label: const Text('End event'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(BackupService.exportAndShare),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share backup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Place it in Settings**

In `lib/screens/settings_screen.dart`, add `import '../widgets/event_tile.dart';`. Directly after the ELO RATING `Card(...)` closes and before `const SizedBox(height: 24),` + `// TTS section`, insert (copy the header styling from the `'ELO RATING'` Text so it matches):

```dart
                const SizedBox(height: 24),

                // Event section
                Text('EVENT',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const EventTile(),
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/widgets/event_tile_test.dart test/screens` 
Expected: `All tests passed!` (if a settings-screen test asserts an exact child count/order, update it to include the new section).

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/event_tile.dart lib/screens/settings_screen.dart test/widgets/event_tile_test.dart
git commit -m "feat(event): Settings EVENT section — start/end, share backup

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Home leaderboard header shows the event name

**Files:**
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (`_buildLeaderboard`, the `'★ HIGH SCORES ★'` Text ~line 190)
- Modify: `lib/screens/home_screen.dart` (`'Leaderboard'` Text ~line 248)
- Test: `test/screens/home_event_header_test.dart` (create)

**Interfaces:**
- Consumes: `EventService.active?.name`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/home_event_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_home_screen.dart';
import 'package:dart_scoring/screens/home_screen.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/player_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1250),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1150),
    ]);
  });
  tearDown(EventService.resetForTest);

  void open() => EventService.active = EventRecord(
        id: 'evt', name: 'Jobbfest 2026', start: DateTime(2026, 8, 25), savedRatings: const {});

  testWidgets('DOSSEDART home: HIGH SCORES becomes the event name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('★ HIGH SCORES ★'), findsOneWidget);

    open();
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('★ JOBBFEST 2026 ★'), findsOneWidget);
    expect(find.text('★ HIGH SCORES ★'), findsNothing);
  });

  testWidgets('classic home: Leaderboard becomes the event name', (tester) async {
    open();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Jobbfest 2026'), findsOneWidget);
    expect(find.text('Leaderboard'), findsNothing);
  });
}
```

If `DossedartHomeScreen`/`HomeScreen` need extra setup to pump (fonts, services, a `useDossedartDesign` flag), copy the boilerplate from `test/screens/dossedart_stats_screen_test.dart` or the existing home tests in `test/screens`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/home_event_header_test.dart`
Expected: FAIL — `★ JOBBFEST 2026 ★` / `Jobbfest 2026` not found.

- [ ] **Step 3: Swap the headers**

`dossedart_home_screen.dart`: add `import '../../services/event_service.dart';` and replace the title Text:

```dart
              Text(
                  EventService.active == null
                      ? '★ HIGH SCORES ★'
                      : '★ ${EventService.active!.name.toUpperCase()} ★',
                  style: _press(11,
                      color: DossedartTokens.cyan, letterSpacing: 1.5)),
```

`home_screen.dart`: add `import '../services/event_service.dart';` and replace `'Leaderboard'` with:

```dart
          EventService.active?.name ?? 'Leaderboard',
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/home_event_header_test.dart test/screens`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_home_screen.dart lib/screens/home_screen.dart test/screens/home_event_header_test.dart
git commit -m "feat(event): home leaderboard header carries the event name

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Stats › SEASONS tab — event cards (closed + live) and history EVENT chip

**Files:**
- Modify: `lib/widgets/dossedart/stats/seasons_tab.dart` (`SeasonsTab` gets `events` + `liveEvent`; new `_EventCard`; `_RankRow`/`_columnHeads` reused)
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_load` loads events + live preview; passes them to `SeasonsTab`; `_HistoryRow` chip)
- Test: `test/widgets/seasons_tab_event_test.dart` (create)

**Interfaces:**
- Consumes: `EventRecord`, `EventService.loadEvents/livePreview`.
- Produces: `SeasonsTab({required seasons, this.events = const [], this.liveEvent})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/seasons_tab_event_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/widgets/dossedart/stats/seasons_tab.dart';

SeasonPlayerRow row(String name, double rating, {int games = 1, int wins = 0}) =>
    SeasonPlayerRow(
      playerId: name, name: name, rating: rating, games: games, wins: wins,
      dartsThrown: 0, dartsHit: 0, gamesWithThrows: 0);

void main() {
  final season = SeasonRecord(
    number: 2,
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 9, 30),
    rows: [row('Ada', 1300, games: 12, wins: 8)],
  );
  final closed = EventRecord(
    id: 'evt_1',
    name: 'Jobbfest 2026',
    start: DateTime(2026, 8, 25, 19),
    end: DateTime(2026, 8, 25, 23),
    savedRatings: const {},
    rows: [row('Bo', 1264, games: 3, wins: 3), row('Ada', 1136, games: 3)],
  );

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
    await t.pumpAndSettle();
  }

  testWidgets('closed event card renders above the season, everyone ranked',
      (tester) async {
    await pump(tester, SeasonsTab(seasons: [season], events: [closed]));
    expect(find.text('EVENT · JOBBFEST 2026'), findsOneWidget);
    expect(find.text('SEASON 2'), findsOneWidget);
    expect(find.textContaining('BO'), findsWidgets); // winner in header + row
    // One-game players are ranked, never shown as UNQUALIFIED.
    expect(find.text('UNQUALIFIED'), findsNothing);
    final eventY = tester.getTopLeft(find.text('EVENT · JOBBFEST 2026')).dy;
    final seasonY = tester.getTopLeft(find.text('SEASON 2')).dy;
    expect(eventY, lessThan(seasonY));
  });

  testWidgets('live event card is labelled LIVE and sits on top', (tester) async {
    final live = closed.copyWith(rows: [row('Bo', 1232, games: 1, wins: 1)]);
    final open = EventRecord(
      id: live.id, name: live.name, start: live.start,
      savedRatings: const {}, rows: live.rows);
    await pump(tester, SeasonsTab(seasons: [season], liveEvent: open));
    expect(find.text('EVENT · JOBBFEST 2026 · LIVE'), findsOneWidget);
  });

  testWidgets('no events → tab looks as before', (tester) async {
    await pump(tester, SeasonsTab(seasons: [season]));
    expect(find.textContaining('EVENT ·'), findsNothing);
    expect(find.text('SEASON 2'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/seasons_tab_event_test.dart`
Expected: compile error — `No named parameter with the name 'events'`.

- [ ] **Step 3: Extend `SeasonsTab`**

In `lib/widgets/dossedart/stats/seasons_tab.dart`, add `import '../../../models/event.dart';`. Replace the class:

```dart
class SeasonsTab extends StatelessWidget {
  const SeasonsTab({
    super.key,
    required this.seasons,
    this.events = const [],
    this.liveEvent,
  });

  final List<SeasonRecord> seasons;

  /// Closed events, any order — sorted newest first here.
  final List<EventRecord> events;

  /// The open event with its rows computed so far, or null.
  final EventRecord? liveEvent;

  @override
  Widget build(BuildContext context) {
    final closedEvents = [...events.where((e) => !e.isOpen)]
      ..sort((a, b) => b.start.compareTo(a.start));
    // Newest first. The all-time record (number 0) is the oldest thing there
    // is, so it sorts to the bottom naturally.
    final ordered = [...seasons]..sort((a, b) => b.number.compareTo(a.number));

    final cards = <Widget>[
      if (liveEvent != null) _EventCard(event: liveEvent!),
      for (final e in closedEvents) _EventCard(event: e),
      for (final s in ordered) _SeasonCard(season: s),
    ];

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'NO SEASONS YET',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 2,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => cards[i],
    );
  }
}
```

Move `_columnHeads()` out of `_SeasonCard` into a top-level function `Widget _columnHeads()` (same body) so both cards share it; update `_SeasonCard.build` to call the top-level one. Then add:

```dart
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventRecord event;

  @override
  Widget build(BuildContext context) {
    final ranked = event.ranked;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(
            color: DossedartTokens.cyan.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 10),
          if (ranked.isEmpty)
            Text('NO GAMES YET',
                style: _vt(15, Colors.white.withValues(alpha: 0.4)))
          else ...[
            _columnHeads(),
            const SizedBox(height: 4),
            for (var i = 0; i < ranked.length; i++)
              _RankRow(rank: i + 1, row: ranked[i], seat: i),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    final winner = event.isOpen ? null : event.winnerName;
    final title = 'EVENT · ${event.name.toUpperCase()}${event.isOpen ? ' · LIVE' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _ps(11, DossedartTokens.cyan, 2)),
        const SizedBox(height: 5),
        Text(
          '${_day(event.start)} ${event.start.year}'
          '${winner == null ? '' : '  ·  ${winner.toUpperCase()}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _vt(16, Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}
```

`_day` already exists in this file (used by `_SeasonCard._header`); reuse it. `_ps`/`_vt` are the file-level helpers.

- [ ] **Step 4: Feed events from the stats screen + history chip**

In `lib/screens/dossedart/dossedart_stats_screen.dart`:
- imports: `import '../../models/event.dart';` and `import '../../services/event_service.dart';`
- state: `List<EventRecord> _events = []; EventRecord? _liveEvent;`
- in `_load()`, after `final seasons = ...`:
  ```dart
    final events = await EventService.loadEvents();
    final liveEvent = await EventService.livePreview();
  ```
  and in `setState`: `_events = events; _liveEvent = liveEvent;`
- where `SeasonsTab(seasons: _seasons)` is built: `SeasonsTab(seasons: _seasons, events: _events, liveEvent: _liveEvent)`.
- `_HistoryRow`: after the mode-name `Expanded(child: Text(entry.gameMode, ...))`, insert:
  ```dart
              if (entry.eventId != null) ...[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: DossedartTokens.yellow, width: 1),
                  ),
                  child: const Text('EVENT',
                      style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                          color: DossedartTokens.yellow)),
                ),
              ],
  ```

- [ ] **Step 5: Run tests**

Run: `flutter test test/widgets/seasons_tab_event_test.dart test/screens/dossedart_stats_screen_test.dart test/widgets`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dossedart/stats/seasons_tab.dart lib/screens/dossedart/dossedart_stats_screen.dart test/widgets/seasons_tab_event_test.dart
git commit -m "feat(event): event cards in SEASONS tab, EVENT chip on history rows

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Event achievements — `EventStanding`, `evaluateEventClose`, seven badges, awarded at `end()`

**Files:**
- Modify: `lib/models/event.dart` (append `EventStanding`)
- Modify: `lib/models/achievement.dart` (`AchievementContext` gains `event`)
- Modify: `lib/services/achievement_service.dart` (add `evaluateEventClose`)
- Modify: `lib/data/achievement_catalog.dart` (append seven `x_event_*` entries after the `x_season_*` block)
- Modify: `lib/services/event_service.dart` (`end()` awards before saving players)
- Test: `test/services/event_achievements_test.dart` (create); extend `test/services/event_service_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class EventStanding { EventRecord event; SeasonPlayerRow row; int rank; int eventsWon; bool isFirstEvent; double? seasonRatingAtStart; }
  AchievementContext({required player, outcome, season, event})   // event: EventStanding?
  List<Achievement> AchievementService.evaluateEventClose(SavedPlayer, EventStanding)
  ```
- Badge ids: `x_event_champion`, `x_event_serial`, `x_event_crasher`, `x_event_closing_time`, `x_event_runner_up`, `x_event_wallflower`, `x_event_plus_one`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/event_achievements_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/services/achievement_service.dart';

SeasonPlayerRow row(String id, double rating, {int games = 1}) => SeasonPlayerRow(
      playerId: id, name: id, rating: rating, games: games, wins: 0,
      dartsThrown: 0, dartsHit: 0, gamesWithThrows: 0);

EventRecord event(List<SeasonPlayerRow> rows, {Map<String, double> saved = const {}}) =>
    EventRecord(
      id: 'evt', name: 'Jobbfest 2026', start: DateTime(2026, 8, 25, 19),
      end: DateTime(2026, 8, 25, 23), savedRatings: saved, rows: rows);

Set<String> idsFor(EventStanding s) => AchievementService.forTest(achievementCatalog)
    .evaluateEventClose(SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)), s)
    .map((a) => a.id)
    .toSet();

EventStanding standing({
  required EventRecord event,
  required SeasonPlayerRow row,
  required int rank,
  int eventsWon = 0,
  bool isFirstEvent = false,
  double? seasonRatingAtStart,
}) =>
    EventStanding(
      event: event, row: row, rank: rank, eventsWon: eventsWon,
      isFirstEvent: isFirstEvent, seasonRatingAtStart: seasonRatingAtStart);

void main() {
  final three = event([row('a', 1260), row('b', 1200), row('c', 1140)]);

  test('LIFE OF THE PARTY for the winner, DESIGNATED DRIVER for second', () {
    final winner = idsFor(standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1));
    expect(winner, contains('x_event_champion'));
    expect(winner, isNot(contains('x_event_serial')));
    final second = idsFor(standing(event: three, row: three.rows[1], rank: 2));
    expect(second, contains('x_event_runner_up'));
    expect(second, isNot(contains('x_event_champion')));
  });

  test('SERIAL PARTIER needs a second win', () {
    expect(idsFor(standing(event: three, row: three.rows[0], rank: 1, eventsWon: 2)),
        contains('x_event_serial'));
  });

  test('PARTY CRASHER: won while below 1200 in the season', () {
    expect(
        idsFor(standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1,
            seasonRatingAtStart: 1150)),
        contains('x_event_crasher'));
    expect(
        idsFor(standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1,
            seasonRatingAtStart: 1250)),
        isNot(contains('x_event_crasher')));
    // Created mid-event → no season rating → not an underdog story.
    expect(idsFor(standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1)),
        isNot(contains('x_event_crasher')));
  });

  test('CLOSING TIME at 8 games, not 7', () {
    expect(idsFor(standing(event: three, row: row('a', 1200, games: 8), rank: 2)),
        contains('x_event_closing_time'));
    expect(idsFor(standing(event: three, row: row('a', 1200, games: 7), rank: 2)),
        isNot(contains('x_event_closing_time')));
  });

  test('WALLFLOWER: last of three, but not last of two', () {
    expect(idsFor(standing(event: three, row: three.rows[2], rank: 3)),
        contains('x_event_wallflower'));
    final two = event([row('a', 1216), row('b', 1184)]);
    expect(idsFor(standing(event: two, row: two.rows[1], rank: 2)),
        isNot(contains('x_event_wallflower')));
  });

  test('PLUS ONE on the first event only', () {
    expect(idsFor(standing(event: three, row: three.rows[1], rank: 2, isFirstEvent: true)),
        contains('x_event_plus_one'));
    expect(idsFor(standing(event: three, row: three.rows[1], rank: 2)),
        isNot(contains('x_event_plus_one')));
  });

  test('event badges stay inert without an event standing', () {
    final ctx = AchievementContext(
        player: SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)));
    for (final a in achievementCatalog.where((a) => a.id.startsWith('x_event_'))) {
      expect(a.milestoneTest!(ctx), isFalse, reason: a.id);
    }
  });
}
```

Add `import 'package:dart_scoring/models/achievement.dart';` for `AchievementContext`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/event_achievements_test.dart`
Expected: compile error — `EventStanding` / `evaluateEventClose` undefined.

- [ ] **Step 3: `EventStanding` + context field**

Append to `lib/models/event.dart`:

```dart
/// What an event close hands the achievement evaluator: one player's row plus
/// the context that only makes sense across events.
class EventStanding {
  const EventStanding({
    required this.event,
    required this.row,
    required this.rank,
    required this.eventsWon,
    required this.isFirstEvent,
    required this.seasonRatingAtStart,
  });

  final EventRecord event;
  final SeasonPlayerRow row;

  /// 1-based place. Everyone with a game is ranked, so never null.
  final int rank;

  /// Events this player has won, this one included.
  final int eventsWon;

  /// No row in any earlier closed event.
  final bool isFirstEvent;

  /// The season rating put aside when the event started, or null when the
  /// player was created during the event.
  final double? seasonRatingAtStart;
}
```

In `lib/models/achievement.dart`, add `import 'event.dart';` and extend `AchievementContext`:

```dart
  /// Set only when an event closes — same trick as [season]: the event badges
  /// all test `ctx.event` first and stay inert at game end.
  final EventStanding? event;

  const AchievementContext({
    required this.player,
    this.outcome,
    this.season,
    this.event,
  });
```

- [ ] **Step 4: `evaluateEventClose`**

In `lib/services/achievement_service.dart`, add `import '../models/event.dart';` and after `evaluateSeasonClose`:

```dart
  /// An event closed → unlock the event badges this player just earned.
  /// Mirrors [evaluateSeasonClose]; only the `x_event_` prefix differs.
  List<Achievement> evaluateEventClose(SavedPlayer player, EventStanding standing) {
    final ctx = AchievementContext(player: player, event: standing);
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (!a.id.startsWith('x_event_')) continue;
      if (!(a.milestoneTest?.call(ctx) ?? false)) continue;
      if (_unlock(player, a, emit: true)) newly.add(a);
    }
    return newly;
  }
```

- [ ] **Step 5: The seven badges**

In `lib/data/achievement_catalog.dart`, directly after the `x_season_ghost` entry (before the closing `];`):

```dart
      // ── Events (party nights on their own table) ──────────────────────
      Achievement(
        id: 'x_event_champion',
        name: 'LIFE OF THE PARTY',
        description: 'Win an event',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.celebration),
        milestoneTest: (ctx) => ctx.event?.rank == 1,
      ),
      Achievement(
        id: 'x_event_serial',
        name: 'SERIAL PARTIER',
        description: 'Win two events',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.nightlife),
        milestoneTest: (ctx) {
          final e = ctx.event;
          return e != null && e.rank == 1 && e.eventsWon >= 2;
        },
      ),
      Achievement(
        id: 'x_event_crasher',
        name: 'PARTY CRASHER',
        description: 'Win an event while below 1200 in the season',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.door_front_door),
        milestoneTest: (ctx) {
          final e = ctx.event;
          final before = e?.seasonRatingAtStart;
          return e != null && e.rank == 1 && before != null && before < 1200;
        },
      ),
      Achievement(
        id: 'x_event_closing_time',
        name: 'CLOSING TIME',
        description: 'Play 8 games in one event',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.bedtime),
        milestoneTest: (ctx) => (ctx.event?.row.games ?? 0) >= 8,
      ),
      Achievement(
        id: 'x_event_runner_up',
        name: 'DESIGNATED DRIVER',
        description: 'Finish second in an event',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.directions_car),
        milestoneTest: (ctx) => ctx.event?.rank == 2,
      ),
      Achievement(
        id: 'x_event_wallflower',
        name: 'WALLFLOWER',
        description: 'Finish last in an event of three or more',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.local_florist),
        milestoneTest: (ctx) {
          final e = ctx.event;
          if (e == null) return false;
          final field = e.event.ranked.length;
          return field >= 3 && e.rank == field;
        },
      ),
      Achievement(
        id: 'x_event_plus_one',
        name: 'PLUS ONE',
        description: 'Play your first event',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.person_add),
        milestoneTest: (ctx) => ctx.event?.isFirstEvent ?? false,
      ),
```

If any `Icons.*` name does not exist in this Flutter version, pick a near neighbour — the glyph is decoration.

- [ ] **Step 6: Award at `end()`**

In `lib/services/event_service.dart`, add `import 'achievement_service.dart';` and `import '../models/saved_player.dart';`. In `end()`, after `final closed = open.copyWith(...)` and BEFORE the ratings restore loop, insert:

```dart
    // Badges read the rows, not live ratings, so the order relative to the
    // restore does not matter — but awarding before the save keeps it to one
    // PlayerStorage write.
    final earlier =
        (await loadEvents()).where((e) => !e.isOpen && e.id != open.id).toList();
    _awardEvent(closed, earlier, players);
```

And add the private helper to the class:

```dart
  static void _awardEvent(
    EventRecord closed,
    List<EventRecord> earlier,
    List<SavedPlayer> players,
  ) {
    final ranked = closed.ranked;
    for (var i = 0; i < ranked.length; i++) {
      final row = ranked[i];
      final player = players.where((p) => p.id == row.playerId).firstOrNull;
      if (player == null) continue;

      var eventsWon = i == 0 ? 1 : 0;
      var playedBefore = false;
      for (final e in earlier) {
        final at = e.ranked.indexWhere((r) => r.playerId == row.playerId);
        if (at == 0) eventsWon++;
        if (at >= 0) playedBefore = true;
      }

      AchievementService.instance.evaluateEventClose(
        player,
        EventStanding(
          event: closed,
          row: row,
          rank: i + 1,
          eventsWon: eventsWon,
          isFirstEvent: !playedBefore,
          seasonRatingAtStart: closed.savedRatings[row.playerId],
        ),
      );
    }
  }
```

- [ ] **Step 7: Extend the service test**

In `test/services/event_service_test.dart`, add `import 'package:dart_scoring/data/achievement_catalog.dart';` and `import 'package:dart_scoring/services/achievement_service.dart';`, register the catalog in `setUp` (`AchievementService.instance.registerCatalog(achievementCatalog);`), and in the `end builds the table…` test append:

```dart
    final ids = {
      for (final p in await PlayerStorage.loadPlayers())
        p.id: p.unlockedAchievementIds
    };
    expect(ids['b'], containsAll(['x_event_champion', 'x_event_plus_one']));
    expect(ids['a'], contains('x_event_runner_up'));
    expect(ids['a'], isNot(contains('x_event_champion')));
```

- [ ] **Step 8: Run tests**

Run: `flutter test test/services test/data test/models`
Expected: `All tests passed!` (a catalog-uniqueness test, if one exists, must still pass — the seven names are new).

- [ ] **Step 9: Commit**

```bash
git add lib/models/event.dart lib/models/achievement.dart lib/services/achievement_service.dart lib/data/achievement_catalog.dart lib/services/event_service.dart test/services/event_achievements_test.dart test/services/event_service_test.dart
git commit -m "feat(event): seven event badges awarded when an event ends

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Full verification, version bump, APK

**Files:**
- Modify: `pubspec.yaml` (`version:` line), `lib/app_version.dart` (`kAppVersion`)

- [ ] **Step 1: Analyze and run the full suite**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!` and `All tests passed!`. Fix anything red before moving on — do not bump on a red suite.

- [ ] **Step 2: Bump the version in BOTH places**

Current is `1.23.0+54`. Set `version: 1.24.0+55` in `pubspec.yaml` and `kAppVersion = '1.24.0'` (match the existing string format in `lib/app_version.dart` exactly — check whether it carries the build number).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml lib/app_version.dart
git commit -m "chore: bump to 1.24.0+55 (event mode + badges, achievements sort)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Build the APK**

Run: `flutter build apk --release`
Expected: `build/app/outputs/flutter-apk/app-release.apk` written. Report the path and size.
