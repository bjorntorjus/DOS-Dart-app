import '../models/saved_player.dart';
import '../models/game_history.dart';
import '../services/game_history_service.dart';
import '../services/player_storage.dart';

class StatsRecorder {
  /// Call after EloService.updateRatings to record per-mode stats,
  /// head-to-head results, rating history snapshots, and game history.
  ///
  /// [playerNames] — display names in the same order as [playerIds].
  /// [modeCounters] — optional map of playerId → counter map for
  /// mode-specific detailed stats (e.g. doubles hit, kills, etc.)
  static void recordGame({
    required String gameMode,
    required List<String?> playerIds,
    required List<String> playerNames,
    required List<int> placements,
    required List<SavedPlayer> savedPlayers,
    Map<String, Map<String, int>>? modeCounters,
    Map<String, double>? ratingsBefore,
    Map<String, double>? ratingsAfter,
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

    // Record to game history (fire-and-forget)
    final historyPlayers = List.generate(playerIds.length, (i) {
      final stats = (modeCounters != null && playerIds[i] != null)
          ? (modeCounters[playerIds[i]] ?? <String, int>{})
          : <String, int>{};
      final pid = playerIds[i];
      final rb = pid == null ? null : ratingsBefore?[pid];
      final ra = pid == null ? null : ratingsAfter?[pid];
      return GameHistoryPlayer(
        name: playerNames[i],
        savedPlayerId: pid,
        placement: placements[i],
        stats: Map<String, int>.from(stats),
        ratingBefore: rb,
        ratingAfter: ra,
      );
    });

    final entry = GameHistoryEntry(
      id: '${now.millisecondsSinceEpoch}',
      gameMode: gameMode,
      date: now,
      players: historyPlayers,
    );

    GameHistoryService.record(entry);
  }

  /// Records mid-game join/leave counters for a game whose stats are skipped.
  static Future<void> recordMidGameChanges({
    required Set<String> joinedIds,
    required Set<String> leftIds,
  }) async {
    if (joinedIds.isEmpty && leftIds.isEmpty) return;
    final savedPlayers = await _loadSavedPlayers();
    for (final id in joinedIds) {
      final idx = savedPlayers.indexWhere((sp) => sp.id == id);
      if (idx >= 0) savedPlayers[idx].gamesJoinedMidway++;
    }
    for (final id in leftIds) {
      final idx = savedPlayers.indexWhere((sp) => sp.id == id);
      if (idx >= 0) savedPlayers[idx].gamesLeftMidway++;
    }
    await _saveSavedPlayers(savedPlayers);
  }

  static Future<List<SavedPlayer>> _loadSavedPlayers() =>
      PlayerStorage.loadPlayers();

  static Future<void> _saveSavedPlayers(List<SavedPlayer> players) =>
      PlayerStorage.savePlayers(players);
}
