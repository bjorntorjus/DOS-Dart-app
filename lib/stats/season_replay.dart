import '../models/game_history.dart';
import '../models/saved_player.dart';
import '../services/elo_service.dart';

/// First day of the calendar quarter [d] falls in.
DateTime quarterStart(DateTime d) =>
    DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1);

/// First day of the quarter after the one [d] falls in.
DateTime nextQuarterStart(DateTime d) {
  final s = quarterStart(d);
  return s.month == 10
      ? DateTime(s.year + 1, 1, 1)
      : DateTime(s.year, s.month + 3, 1);
}

/// Rebuilds ratings from scratch by replaying rated games in date order.
///
/// This is what makes the retroactive seasons possible: game history holds
/// `date`, `gameMode`, and per player `savedPlayerId` + `placement` — exactly
/// the inputs [EloService.updateRatings] takes.
///
/// **Sorting by date is load-bearing.** History is stored newest-first and Elo
/// is order-dependent, so replaying in stored order produces a different, and
/// wrong, answer.
///
/// The K-factor still keys off each player's LIFETIME `gamesPlayed`, which
/// this deliberately does not touch — the spec keeps K unchanged, and a
/// replay is a recount of results, not a rewrite of how much anyone has
/// played.
///
/// [from] and [to] are inclusive whole days when given.
void replayRatings({
  required List<GameHistoryEntry> history,
  required List<SavedPlayer> players,
  DateTime? from,
  DateTime? to,
}) {
  for (final p in players) {
    p.rating = 1200;
  }

  final lower =
      from == null ? null : DateTime(from.year, from.month, from.day);
  final upper = to == null
      ? null
      : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

  final games = history.where((e) {
    if (e.eventId != null) return false; // event games never touch the season
    if (!EloService.isRatedMode(e.gameMode)) return false;
    if (lower != null && e.date.isBefore(lower)) return false;
    if (upper != null && e.date.isAfter(upper)) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final entry in games) {
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
  }
}
