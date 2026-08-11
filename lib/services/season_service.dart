import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/season.dart';
import '../stats/season_replay.dart';
import '../stats/season_stats.dart';
import 'app_settings.dart';
import 'game_history_service.dart';
import 'player_storage.dart';

/// The day season 1 ends. Everything played up to and including this date is
/// the pre-seasons era; Q3 2026 is season 2.
final DateTime kSeasonOneEnd = DateTime(2026, 6, 30);

/// Storage and lifecycle for quarterly rating seasons.
///
/// See `docs/superpowers/specs/2026-08-11-elo-seasons-design.md`. The two
/// operations that matter are [migrate], which runs once and rebuilds the two
/// seasons already played, and [closeDueSeason], which runs at every app start
/// and does nothing unless a quarter boundary was crossed.
class SeasonService {
  static const _key = 'seasons_v1';

  static Future<List<SeasonRecord>> loadSeasons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SeasonRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A broken archive must not block play. The backup export is the
      // recovery path; returning empty keeps the app usable meanwhile.
      return [];
    }
  }

  static Future<void> _saveSeasons(List<SeasonRecord> seasons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(seasons.map((s) => s.toJson()).toList()));
  }

  static Future<void> _append(SeasonRecord season) async {
    final all = await loadSeasons()
      ..add(season);
    await _saveSeasons(all);
  }

  static Future<bool> needsMigration() async =>
      !(await AppSettings.getSeasonsMigrated());

  /// The open season as it stands right now — computed, never stored, so it
  /// always reflects games played since the last app start.
  static Future<SeasonRecord?> currentSeasonPreview({DateTime? now}) async {
    final start = await AppSettings.getSeasonStart();
    if (start == null) return null;
    final today = now ?? DateTime.now();
    final players = await PlayerStorage.loadPlayers();
    return SeasonRecord(
      number: await AppSettings.getSeasonNumber(),
      start: start,
      end: today,
      rows: seasonStatsFrom(
        history: await GameHistoryService.load(),
        start: start,
        end: today,
        finalRatings: {for (final p in players) p.id: p.rating},
        names: {for (final p in players) p.id: p.name},
      ),
    );
  }

  /// Rebuilds the two seasons already played and opens Q3.
  ///
  /// Order matters and each step earns its place:
  ///  1. refuse without a backup — this is the only operation in the app that
  ///     rewrites every rating, and there is no import to undo it;
  ///  2. archive today's ratings, which are the product of history that may
  ///     predate what game history still holds and cannot be rebuilt after;
  ///  3. season 1 — everything up to 30 June 2026;
  ///  4. season 2 — Q3, left OPEN, so the live rating is each player's
  ///     current-quarter standing.
  ///
  /// Idempotent: the migrated flag is written last, so a run interrupted
  /// after season 1 resumes instead of resetting it again.
  static Future<void> migrate() async {
    if (await AppSettings.getSeasonsMigrated()) return;
    if (await AppSettings.getLastBackupAt() == null) {
      throw StateError('Export a backup before migrating — this rewrites '
          'every rating and cannot be undone.');
    }

    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();
    final names = {for (final p in players) p.id: p.name};

    // 2. All-time row: the ratings as they stand after every game ever
    //    played, preserved because nothing can reconstruct them afterwards.
    final allTimeStart = history.isEmpty
        ? kSeasonOneEnd
        : history.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    await _append(SeasonRecord(
      number: 0,
      start: allTimeStart,
      end: DateTime.now(),
      rows: [
        for (final p in players)
          SeasonPlayerRow(
            playerId: p.id,
            name: p.name,
            rating: p.rating,
            games: p.gamesPlayed,
            wins: p.gamesWon,
            dartsThrown: 0,
            dartsHit: 0,
            gamesWithThrows: 0,
          ),
      ],
    ));

    // 3. Season 1 — from the oldest surviving game to 30 June.
    replayRatings(history: history, players: players, to: kSeasonOneEnd);
    await PlayerStorage.savePlayers(players);
    await _append(SeasonRecord(
      number: 1,
      start: allTimeStart,
      end: kSeasonOneEnd,
      rows: seasonStatsFrom(
        history: history,
        start: allTimeStart,
        end: kSeasonOneEnd,
        finalRatings: {for (final p in players) p.id: p.rating},
        names: names,
      ),
    ));

    // 4. Season 2 — Q3, left open.
    final seasonTwoStart = DateTime(2026, 7, 1);
    replayRatings(history: history, players: players, from: seasonTwoStart);
    await PlayerStorage.savePlayers(players);
    await AppSettings.setSeasonNumber(2);
    await AppSettings.setSeasonStart(seasonTwoStart);

    await AppSettings.setSeasonsMigrated(true);
  }

  /// Closes the open season when the calendar has moved into a new quarter.
  ///
  /// Called at app start, never on a timer: a boundary crossed at 21:00 on a
  /// Friday closes the next time the app launches, so a season can never end
  /// in the middle of a game night.
  ///
  /// [now] exists for tests; production calls this with no argument.
  /// Returns true when a season was actually closed.
  static Future<bool> closeDueSeason({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final start = await AppSettings.getSeasonStart();
    if (start == null) return false;
    if (quarterStart(today) == quarterStart(start)) return false;

    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();
    // The season ends the day before the new quarter began.
    final end = quarterStart(today).subtract(const Duration(days: 1));

    await _append(SeasonRecord(
      number: await AppSettings.getSeasonNumber(),
      start: start,
      end: end,
      rows: seasonStatsFrom(
        history: history,
        start: start,
        end: end,
        finalRatings: {for (final p in players) p.id: p.rating},
        names: {for (final p in players) p.id: p.name},
      ),
    ));

    // Hard reset. Rating ONLY — gamesPlayed, gamesWon, modeStats and
    // unlockedAchievementIds are never touched by a season boundary.
    for (final p in players) {
      p.rating = 1200;
    }
    await PlayerStorage.savePlayers(players);

    await AppSettings.setSeasonNumber(await AppSettings.getSeasonNumber() + 1);
    await AppSettings.setSeasonStart(quarterStart(today));
    return true;
  }
}
