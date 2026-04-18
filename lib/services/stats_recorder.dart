import '../models/saved_player.dart';

class StatsRecorder {
  /// Call after EloService.updateRatings to record per-mode stats,
  /// head-to-head results, and rating history snapshots.
  ///
  /// [modeCounters] is an optional map of playerId → counter map for
  /// mode-specific detailed stats (e.g. doubles hit, kills, etc.)
  static void recordGame({
    required String gameMode,
    required List<String?> playerIds,
    required List<int> placements,
    required List<SavedPlayer> savedPlayers,
    Map<String, Map<String, int>>? modeCounters,
  }) {
    final now = DateTime.now();

    // Find the best placement (lowest number = winner)
    final bestPlacement = placements.reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];

      // Per-mode stats
      final mode = sp.modeStats.putIfAbsent(gameMode, () => ModeStats());
      mode.played++;
      if (placements[i] == bestPlacement) {
        mode.won++;
      }

      // Merge mode-specific counters
      if (modeCounters != null && modeCounters.containsKey(playerId)) {
        final counters = modeCounters[playerId]!;
        for (final entry in counters.entries) {
          if (entry.key.startsWith('max:')) {
            // Keys prefixed with "max:" use setMax instead of increment
            mode.setMax(entry.key.substring(4), entry.value);
          } else {
            mode.inc(entry.key, entry.value);
          }
        }
      }

      // Head-to-head
      for (int j = 0; j < playerIds.length; j++) {
        if (i == j) continue;
        final opponentId = playerIds[j];
        if (opponentId == null) continue;

        final h2h = sp.headToHead.putIfAbsent(opponentId, () => H2HRecord());
        if (placements[i] < placements[j]) {
          h2h.wins++;
        } else if (placements[i] > placements[j]) {
          h2h.losses++;
        } else {
          h2h.draws++;
        }
      }

      // Rating history snapshot — compute placement among ALL saved players
      final sortedByRating = List<SavedPlayer>.from(savedPlayers)
        ..sort((a, b) => b.rating.compareTo(a.rating));
      final ratingPlacement =
          sortedByRating.indexWhere((s) => s.id == sp.id) + 1;
      sp.ratingHistory.add(RatingSnapshot(
          date: now, rating: sp.rating, placement: ratingPlacement));
    }
  }
}
