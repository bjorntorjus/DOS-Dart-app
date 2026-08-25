import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../models/saved_player.dart';
import '../stats/season_stats.dart';
import 'achievement_service.dart';
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
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    if (active != null) {
      throw StateError('An event is already open: ${active!.name}');
    }

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
  ///  2. event badges — they read the rows, not live ratings, so awarding
  ///     before the save just keeps it to one PlayerStorage write;
  ///  3. restore season ratings — players created mid-event have no snapshot
  ///     and get 1200, which is their untouched season rating anyway;
  ///  4. persist the closed record, clear [active];
  ///  5. backup AFTER the restore so the file is the post-event truth. A
  ///     failure here is logged, not thrown — the data is already consistent;
  ///  6. a quarter boundary that passed during the event was held back by
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

    final all = await loadEvents();
    final earlier =
        all.where((e) => !e.isOpen && e.id != open.id).toList();
    _awardEvent(closed, earlier, players);

    for (final p in players) {
      p.rating = open.savedRatings[p.id] ?? 1200;
    }
    await PlayerStorage.savePlayers(players);

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
}
