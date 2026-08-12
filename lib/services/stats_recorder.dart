import '../models/saved_player.dart';
import '../models/game_history.dart';
import '../models/dart_throw.dart';
import '../models/earned_feat.dart';
import '../services/game_history_service.dart';
import '../services/player_storage.dart';
import '../services/shot_clock.dart';

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
    String? gameConfig,
    int? durationSeconds,
    List<DartThrow>? throwHistory,
    Map<int, List<EarnedFeat>>? earnedFeatsByIndex,
  }) {
    final now = DateTime.now();

    // Find the best placement (lowest number = winner).
    // A shared best placement is a draw — nobody gets win credit.
    final bestPlacement = placements.reduce((a, b) => a < b ? a : b);
    final bestIsShared =
        placements.where((p) => p == bestPlacement).length > 1;

    for (int i = 0; i < playerIds.length; i++) {
      final playerId = playerIds[i];
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];

      // Per-mode stats
      final mode = sp.modeStats.putIfAbsent(gameMode, () => ModeStats());
      mode.played++;
      if (placements[i] == bestPlacement && !bestIsShared) {
        mode.won++;
      }

      // Win/loss streaks (cross-mode). Sole best = win; shared best = draw
      // (breaks both streaks); everything else = loss.
      if (placements[i] == bestPlacement && !bestIsShared) {
        sp.currentWinStreak++;
        if (sp.currentWinStreak > sp.bestWinStreak) {
          sp.bestWinStreak = sp.currentWinStreak;
        }
        sp.currentLossStreak = 0;
      } else if (placements[i] == bestPlacement) {
        sp.currentWinStreak = 0;
        sp.currentLossStreak = 0;
      } else {
        sp.currentLossStreak++;
        sp.currentWinStreak = 0;
      }

      // Slow turns are collected by ShotClock during the game rather than
      // passed in by each screen — one merge point instead of ten cockpits
      // each remembering to forward the same counter.
      final slow = ShotClock.instance.slowTurnsFor(playerNames[i]);
      if (slow > 0) mode.inc('slowTurns', slow);

      // Merge mode-specific counters
      if (modeCounters != null && modeCounters.containsKey(playerId)) {
        final counters = modeCounters[playerId]!;
        for (final entry in counters.entries) {
          if (entry.key.startsWith('max:')) {
            mode.setMax(entry.key.substring(4), entry.value);
          } else if (entry.key.startsWith('min:')) {
            mode.setMin(entry.key.substring(4), entry.value);
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

    // The shot-clock tally is per game. Clearing it here also restores the
    // first-turn grace for the next game, so this is the only reset the
    // feature needs anywhere.
    ShotClock.instance.resetGame();

    // Record to game history (fire-and-forget)
    final entry = buildEntry(
      gameMode: gameMode,
      playerIds: playerIds,
      playerNames: playerNames,
      placements: placements,
      modeCounters: modeCounters,
      ratingsBefore: ratingsBefore,
      ratingsAfter: ratingsAfter,
      gameConfig: gameConfig,
      durationSeconds: durationSeconds,
      throwHistory: throwHistory,
      earnedFeatsByIndex: earnedFeatsByIndex,
    );

    GameHistoryService.record(entry);
  }

  /// Assembles a [GameHistoryEntry] from the same inputs [recordGame] uses to
  /// persist one — extracted so callers can build an EPHEMERAL entry (never
  /// passed to [GameHistoryService.record]) for immediate display, e.g. the
  /// post-game "DETAILS" drill-down. Stats recording is deferred until Finish
  /// (post-game Undo safety), so no persisted entry exists yet while the
  /// post-game screen is showing — screens call this directly with
  /// pre-Finish values (typically null/empty ratings, since Elo computes at
  /// Finish) to get a stand-in entry for [GameDetailScreen].
  ///
  /// Note: [GameHistoryEntry.id] and `date` are derived from `DateTime.now()`
  /// at call time. An ephemeral entry built here and the "real" entry
  /// [recordGame] persists later will therefore get different ids/dates —
  /// this is fine and expected, not a bug: the ephemeral copy is discarded
  /// once the post-game screen closes.
  static GameHistoryEntry buildEntry({
    required String gameMode,
    required List<String?> playerIds,
    required List<String> playerNames,
    required List<int> placements,
    Map<String, Map<String, int>>? modeCounters,
    Map<String, double>? ratingsBefore,
    Map<String, double>? ratingsAfter,
    String? gameConfig,
    int? durationSeconds,
    List<DartThrow>? throwHistory,
    Map<int, List<EarnedFeat>>? earnedFeatsByIndex,
  }) {
    final now = DateTime.now();

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
        earnedFeats: earnedFeatsByIndex?[i],
      );
    });

    return GameHistoryEntry(
      id: '${now.millisecondsSinceEpoch}',
      gameMode: gameMode,
      date: now,
      players: historyPlayers,
      gameConfig: gameConfig,
      durationSeconds: durationSeconds,
      throwHistory: throwHistory,
    );
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
