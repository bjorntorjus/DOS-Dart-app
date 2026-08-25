# Event mode — design (2026-08-25)

**Origin:** a work party is coming up. Games will be played all evening, and Bjørn wants to crown a
"Jobbfest 2026" winner **without** the evening touching the running quarterly season. Everyone
should start level, the people far behind get a fair shot, and the people on top have to earn it
again. Everything *else* the evening produces — game history, per-mode stats, a 180, achievements —
should be recorded as usual.

**Scope:** a manually started/ended **event** that swaps the live rating out for an event rating,
keeps event games out of the season table, and archives a named event table with a winner — plus
seven event badges (§9). No change to the Elo formula, no timer.

Decisions taken in the brainstorm (all Bjørn's):

- Table = **Elo + wins/games** side by side. **No qualifying threshold** — one game and you are in.
  It is meant to be fun, and everyone understands one game is not the whole picture.
- Activated from **Settings** — this is used a few times a year, by the person who owns the tablet.
- **Swap-and-snapshot** (§2): season ratings are put aside at start and restored at end, so every
  existing rating surface (home podium, post-game delta, stats) shows the event automatically.
- **Backup written automatically** at start and at end.

---

## 1. Lifecycle

```
Settings → EVENT → [Start event]  →  name dialog  →  backup file written
                                      → season ratings snapshotted, everyone set to 1200
                                      → EventService.active != null

… games are played; the home podium and every rating delta are the event's …

Settings → EVENT → [End event]    →  confirm dialog
                                      → final table computed from history (eventId)
                                      → season ratings restored (new players → 1200)
                                      → backup file written
                                      → event archived, shown under STATS › SEASONS
                                      → any season close that was waiting runs now
```

- **Exactly one event can be open at a time.** Start is disabled while one is open.
- **No timer.** The event ends when someone ends it. A safety net, not a rule: if the app boots
  while an event has been open for more than 24 hours, the Settings tile is highlighted and the
  home leaderboard header still shows the event name — nothing closes on its own. (Season closing
  chose the same "never mid-evening" stance; this follows it.)
- **Ending is final.** There is no re-open — a second party is a second event.

## 2. Swap-and-snapshot

At start, `EventRecord.savedRatings` = `{playerId: rating}` for **every** saved player (archived
included — they may be un-archived during the evening). Then `player.rating = 1200` for all.

At end, for every saved player: `rating = savedRatings[id] ?? 1200`. The `?? 1200` covers players
created during the event: they have no season rating yet, and 1200 is what a new player gets anyway.

Consequences that fall out for free — and are the reason for this approach:

- Home podium (both `HomeScreen` and `DossedartHomeScreen` sort on `player.rating`) shows the event
  standings.
- Post-game rating deltas (`ratingsBefore/After`) are event deltas.
- The stats screen's player ranking is the event ranking while it runs.

Things that must be **protected explicitly** because the swap would otherwise leak into the season:

| Surface | Rule during an event |
|---|---|
| `GameHistoryEntry` | gets `eventId` (nullable string, JSON key `eventId`, omitted when null) |
| `seasonStatsFrom` | skips entries whose `eventId != null` — event games are not season games |
| `replayRatings` (migration) | skips event entries for the same reason |
| `_qualifiedOnFinalDay` | skips event entries |
| `StatsRecorder` rating-history snapshot | **not** appended while an event is active — the profile graph is the season graph and must not show a 1200 dip |
| `SeasonService.closeDueSeason` | returns `false` while an event is open; `EventService.end()` calls it after restoring ratings so a boundary that passed during the party closes then |
| `SeasonService.currentSeasonPreview` | unchanged — it filters via `seasonStatsFrom`, and `finalRatings` is only read at close, after the restore |

Everything else in `StatsRecorder` — mode stats, win/loss streaks, head-to-head, modeCounters
(180s, PBs), achievements via `AchievementService`, game history — runs exactly as normal. That is
the "a 180 that night still counts" requirement, and it needs no code.

**K-factor during an event:** `EloService.updateRatings` uses `kFactor(gamesPlayed)`, which for
the regulars (>20 games) is the low K=16. With everyone reset to 1200 and only a handful of games
in an evening, K=16 barely moves the table. During an event, **every player uses the new-player K**
(`_kNew`, default 32) regardless of games played — the "one sick game sends you to the sky"
feel Bjørn asked for, without inventing a new constant or touching the formula.

## 3. Data model

`lib/models/event.dart`:

```dart
class EventRecord {
  final String id;            // uuid-ish, e.g. 'evt_<millis>'
  final String name;          // 'Jobbfest 2026', trimmed, non-empty
  final DateTime start;
  final DateTime? end;        // null while open
  final Map<String, double> savedRatings;   // season ratings put aside at start
  final List<SeasonPlayerRow> rows;         // empty while open; final table when closed

  bool get isOpen => end == null;

  /// Everyone with ≥1 game, best rating first, ties on name. No qualification.
  List<SeasonPlayerRow> get ranked;
  String? get winnerName;
}
```

`SeasonPlayerRow` is reused as-is: it already carries rating, games, wins, hit %. Its `qualified`
getter is simply never consulted for events.

Storage: one SharedPreferences key `events` holding a JSON list of `EventRecord`, newest last. The
open event (if any) lives in the same list with `end == null`. Corrupt JSON is salvaged to
`events_corrupt` and treated as empty, matching how `SeasonService.loadSeasons` behaves.

## 4. Services

`lib/services/event_service.dart` — static, same shape as `SeasonService`:

```dart
class EventService {
  /// In-memory mirror of the open event. Loaded once at boot, updated by
  /// start()/end(). Exists because EloService.updateRatings and
  /// StatsRecorder.recordGame are synchronous and cannot await prefs.
  static EventRecord? active;

  static Future<void> load();                       // main.dart, before runApp
  static Future<List<EventRecord>> loadEvents();    // all, incl. open
  static Future<EventRecord> start(String name);    // throws StateError if one is open
  static Future<EventRecord> end();                 // throws StateError if none is open
}
```

`start(name)`:
1. `BackupService.writeBackupFile()` — a file in the documents dir, no share sheet. If the write
   throws, start is aborted and the error surfaces in Settings; nothing has been touched yet.
2. Load players; build `savedRatings`; set all to 1200; save players.
3. Append the open record; set `active`.

`end()`:
1. Load players + history. `rows = seasonStatsFrom(history, …, eventId: active.id, finalRatings:
   current ratings)` — see §5 for the parameter.
2. Restore ratings (§2); save players.
3. Write the closed record back into the list (same id); `active = null`.
4. `BackupService.writeBackupFile()` — after the restore, so the file is the post-event truth. A
   failure here is logged, not thrown: the event is already closed and the data is consistent.
5. `await SeasonService.closeDueSeason()`.

`EloService.updateRatings`: `final kI = EventService.active != null ? _kNew : kFactor(...)`.
Nothing else changes.

`StatsRecorder.recordGame`: skip the `ratingHistory.add` block when `EventService.active != null`;
`buildEntry` sets `eventId: EventService.active?.id`.

`SeasonService.closeDueSeason`: early `return false` when `EventService.active != null`.

## 5. `seasonStatsFrom` gains an `eventId` filter

```dart
List<SeasonPlayerRow> seasonStatsFrom({
  required List<GameHistoryEntry> history,
  required DateTime start,
  required DateTime end,
  required Map<String, double> finalRatings,
  required Map<String, String> names,
  String? eventId,     // null: season mode, entries WITH an eventId are skipped
                       // set:  event mode, ONLY entries with this eventId count
});
```

Date bounds still apply in both modes (an event's are `start`..`now`). Same win/draw rule, same
throws-known bookkeeping — one function, no fork.

## 6. UI

### Settings › EVENT (new section, between ELO RATING and TEXT-TO-SPEECH)

Card with:

- No event open: `Start event` button → dialog with a text field (`Event name`, prefilled empty,
  Start disabled while blank) and a one-line note: *"Everyone starts at 1200. Games count for
  stats and achievements but not for the season. A backup is written first."*
- Event open: `● JOBBFEST 2026 · started 25 Aug 19:12 · 7 games`, `End event` button → confirm
  dialog (*"End Jobbfest 2026? Season ratings are restored and the table is archived."*), plus a
  `Share backup` button (calls `BackupService.exportAndShare`).
- Over 24 h open: the header line adds `· open for 2 days` in `secondary`.

Classic-theme screen → `colorScheme` roles only, like the rest of `settings_screen.dart`.

### Home leaderboard header

While an event is open, the leaderboard title becomes the event name:

- `DossedartHomeScreen`: `★ HIGH SCORES ★` → `★ JOBBFEST 2026 ★` (uppercased, same style).
- `HomeScreen`: `Leaderboard` → `Jobbfest 2026`.

That is the whole in-game signal that "we are in an event". Setup screens are not touched.

### Stats › SEASONS tab

Closed events render as cards **above** the season cards, newest first, followed by the seasons as
today. Card header: `EVENT · JOBBFEST 2026 · 25 AUG 2026`; the table has the same PLAYER / RATING
/ GP / WIN / HIT columns and rank rows as `_SeasonCard` (reuse `_RankRow`; extract it if the
private scope gets in the way). No UNQUALIFIED block — everybody with a game is ranked. Winner
gets the same treatment rank 1 gets in a season card.

While an event is open it also appears at the top as a **live card** (`EVENT · JOBBFEST 2026 ·
LIVE`), rows computed from history the same way the season preview is, so people can check the
table between games.

### Game history rows

`_HistoryRow` shows a small `EVENT` chip (DossedartTokens, `yellow`) after the mode name when
`entry.eventId != null`. Game detail is unchanged.

## 7. Boot

`main.dart`, before `closeDueSeason()`: `await EventService.load()`. Order matters — the close
guard reads `EventService.active`.

## 8. Edge cases

- **Player added mid-event:** starts at 1200 as any new player; not in `savedRatings`; restored to
  1200 at end (= their untouched season rating). Correct by construction.
- **Player archived mid-event:** unaffected; snapshot covers everyone.
- **App killed mid-start:** step order is backup → players saved with 1200 → record appended. A
  kill between players-save and append leaves everyone on 1200 with no event — the backup file
  from step 1 has the season ratings. Acceptable for a manual, rare operation; documented here so
  nobody "fixes" it into a two-phase commit.
- **Quarter boundary during the party:** season close waits (§2), then runs at `end()`. The
  season table it builds excludes the event games; final ratings are the restored season ones.
- **Unrated modes (Wildcard, Killer) during an event:** as in a season — recorded, not rated. They
  still count in `games` for the event row? **No** — `seasonStatsFrom` already skips unrated modes
  and the event reuses it. Consistent with the season table.
- **Restore from backup taken *during* an event:** `events` is captured by the generic settings
  sweep in `BackupService`, so an open event round-trips with the ratings that belong to it.

## 9. Event achievements

Bjørn (mid-plan): *"man må hedres for å vinne et slikt event."* Same mechanism as the season badges:
`EventService.end()` hands every player with a row an `EventStanding`, and
`AchievementService.evaluateEventClose` runs the `x_event_*` entries against it. Lifetime unlocks,
unique names, one evaluation path — every event badge tests `ctx.event` first so it stays inert at
game end, exactly like the season badges test `ctx.season`.

```dart
class EventStanding {
  final EventRecord event;
  final SeasonPlayerRow row;
  final int rank;                 // 1-based among ranked (everyone with a game is ranked)
  final int eventsWon;            // events this player has won, this one included
  final bool isFirstEvent;        // no row in any earlier closed event
  final double? seasonRatingAtStart;  // event.savedRatings[playerId]; null if created mid-event
}
```

| id | name | tier | test |
|---|---|---|---|
| `x_event_champion` | LIFE OF THE PARTY | gold | `rank == 1` |
| `x_event_serial` | SERIAL PARTIER | gold | `rank == 1 && eventsWon >= 2` |
| `x_event_crasher` | PARTY CRASHER | silver | `rank == 1 && (seasonRatingAtStart ?? 1200) < 1200` — won the night while below par in the season |
| `x_event_closing_time` | CLOSING TIME | silver | `row.games >= 8` — still throwing when the lights come on |
| `x_event_runner_up` | DESIGNATED DRIVER | bronze | `rank == 2` |
| `x_event_wallflower` | WALLFLOWER | bronze | last of ≥3 ranked |
| `x_event_plus_one` | PLUS ONE | bronze | `isFirstEvent` — your first event |

Category `milestone` for the top four, `quirky` for the last three. Glyphs from Material icons via
the catalog's `_g(...)` helper. Banners emit on the same stream as season badges — the moment the
event ends is the moment to celebrate.

## 10. Testing

- `event_achievements_test.dart`: each of the seven badges fires on its condition and not otherwise;
  none fires from `evaluateMilestones` (game-end path).
- `event_service_test.dart`: end awards LIFE OF THE PARTY to the winner; start snapshots + resets; end restores (incl. `?? 1200` for a player
  created mid-event); end computes rows only from event entries; start twice throws; end without
  open throws; end calls `closeDueSeason` (a due boundary closes after end, not before).
- `season_stats_test.dart` additions: event entries excluded in season mode; only matching
  entries included in event mode; date bounds still apply.
- `elo_service_test.dart`: experienced player uses `_kNew` while `EventService.active != null`.
- `stats_recorder_test.dart`: no `RatingSnapshot` appended during an event; `eventId` set on the
  history entry.
- `season_service_test.dart`: `closeDueSeason` returns false while an event is open.
- `game_history` JSON round-trip with and without `eventId`.
- Widget: seasons tab renders an event card above season cards; settings EVENT card toggles
  between start/end states; home header shows the event name.

## 11. Out of scope (parked, not designed)

- Per-event mode restriction or per-event player list.
- Re-opening a closed event; editing a name after the fact.
- Setup-screen banner.
