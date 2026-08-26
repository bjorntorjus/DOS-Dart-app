import '../models/game_history.dart';
import '../models/season.dart';
import '../services/elo_service.dart';

/// Per-player figures for one season, derived from game history in a date
/// range rather than from cumulative counters.
///
/// That is not a stylistic choice. The retroactive seasons have no snapshot
/// taken at their boundaries — nobody stood at midnight on 30 June writing
/// down everyone's totals — so a cumulative-diff scheme could not build them
/// at all. Reading the range straight from history works for a season that
/// already happened and one that just closed, with no separate code path.
///
/// [start] and [end] are inclusive whole days.
///
/// [eventId] selects the table being built. Null is season mode: entries that
/// carry ANY eventId are skipped, because event games are not season games.
/// A value is event mode: only entries with exactly that id count. Date bounds
/// apply either way — one function, no fork.
List<SeasonPlayerRow> seasonStatsFrom({
  required List<GameHistoryEntry> history,
  required DateTime start,
  required DateTime end,
  required Map<String, double> finalRatings,
  required Map<String, String> names,
  String? eventId,
}) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

  final games = <String, int>{};
  final wins = <String, int>{};
  final thrown = <String, int>{};
  final hit = <String, int>{};
  final withThrows = <String, int>{};

  for (final entry in history) {
    if (entry.date.isBefore(from) || entry.date.isAfter(to)) continue;
    if (eventId == null ? entry.eventId != null : entry.eventId != eventId) {
      continue;
    }
    if (!EloService.isRatedMode(entry.gameMode)) continue;

    final placements = entry.activePlayers.map((p) => p.placement).toList();
    if (placements.isEmpty) continue;
    final best = placements.reduce((a, b) => a < b ? a : b);
    // A shared best placement is a draw — nobody gets win credit. Same rule
    // StatsRecorder applies live.
    final bestIsShared = placements.where((p) => p == best).length > 1;

    final throws = entry.throwHistory;
    final hasThrows = throws != null && throws.isNotEmpty;

    for (var seat = 0; seat < entry.players.length; seat++) {
      if (entry.players[seat].removed) continue;
      final id = entry.players[seat].savedPlayerId;
      if (id == null) continue; // guests contribute nothing, as they do live

      games[id] = (games[id] ?? 0) + 1;
      if (entry.players[seat].placement == best && !bestIsShared) {
        wins[id] = (wins[id] ?? 0) + 1;
      }

      if (!hasThrows) continue;
      withThrows[id] = (withThrows[id] ?? 0) + 1;
      for (final t in throws.where((t) => t.playerIndex == seat)) {
        thrown[id] = (thrown[id] ?? 0) + 1;
        if (t.multiplier > 0) hit[id] = (hit[id] ?? 0) + 1;
      }
    }
  }

  return [
    for (final id in games.keys)
      SeasonPlayerRow(
        playerId: id,
        name: names[id] ?? id,
        rating: finalRatings[id] ?? 1200,
        games: games[id] ?? 0,
        wins: wins[id] ?? 0,
        dartsThrown: thrown[id] ?? 0,
        dartsHit: hit[id] ?? 0,
        gamesWithThrows: withThrows[id] ?? 0,
      ),
  ];
}
