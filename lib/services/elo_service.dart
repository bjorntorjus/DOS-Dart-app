import 'dart:math';
import '../models/saved_player.dart';
import 'app_settings.dart';

class EloService {
  static double _kNew = AppSettings.defaultEloKNew;
  static double _kExp = AppSettings.defaultEloKExp;
  static int _threshold = AppSettings.defaultEloThreshold;

  /// Load ELO settings from storage. Call once at app start or before rating updates.
  static Future<void> loadSettings() async {
    _kNew = await AppSettings.getEloKNew();
    _kExp = await AppSettings.getEloKExp();
    _threshold = await AppSettings.getEloThreshold();
  }

  /// Calculate K-factor based on games played.
  /// New players have higher K (rating changes faster).
  /// Experienced players have lower K (rating is more stable).
  static double kFactor(int gamesPlayed) {
    if (gamesPlayed < _threshold) {
      return _kNew;
    }
    return _kExp;
  }

  /// Expected score of player A against player B.
  /// Returns a value between 0 and 1.
  static double _expectedScore(double ratingA, double ratingB) {
    return 1.0 / (1.0 + pow(10, (ratingB - ratingA) / 400));
  }

  /// Update ratings for all players based on final placements.
  ///
  /// [playerIds] - list of saved player IDs in the game (order matches players list)
  /// [placements] - placement for each player (1 = 1st place, 2 = 2nd, etc.)
  ///                Players with the same placement are considered tied.
  /// [savedPlayers] - all saved players (will be modified in place)
  ///
  /// Each pair of players is treated as a head-to-head match:
  /// - Higher placement = win (score 1.0)
  /// - Same placement = draw (score 0.5)
  /// - Lower placement = loss (score 0.0)
  ///
  /// Rating changes are scaled by 1/(N-1) where N is the number of players,
  /// so that a game with many players doesn't cause disproportionate swings.
  static void updateRatings({
    required List<String?> playerIds,
    required List<int> placements,
    required List<SavedPlayer> savedPlayers,
  }) {
    final n = playerIds.length;
    if (n < 2) return;

    // Build a map of playerIndex -> SavedPlayer for players that have IDs
    final indexToSaved = <int, SavedPlayer>{};
    for (int i = 0; i < n; i++) {
      final pid = playerIds[i];
      if (pid == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == pid);
      if (idx >= 0) {
        indexToSaved[i] = savedPlayers[idx];
      }
    }

    if (indexToSaved.length < 2) return;

    // Calculate rating deltas using pairwise comparisons
    final deltas = <int, double>{};
    for (final i in indexToSaved.keys) {
      deltas[i] = 0.0;
    }

    final scale = 1.0 / (n - 1);

    for (final i in indexToSaved.keys) {
      for (final j in indexToSaved.keys) {
        if (i >= j) continue; // each pair once

        final ratingI = indexToSaved[i]!.rating;
        final ratingJ = indexToSaved[j]!.rating;

        final expectedI = _expectedScore(ratingI, ratingJ);
        final expectedJ = 1.0 - expectedI;

        double actualI;
        if (placements[i] < placements[j]) {
          actualI = 1.0; // i won
        } else if (placements[i] == placements[j]) {
          actualI = 0.5; // draw
        } else {
          actualI = 0.0; // i lost
        }
        final actualJ = 1.0 - actualI;

        final kI = kFactor(indexToSaved[i]!.gamesPlayed);
        final kJ = kFactor(indexToSaved[j]!.gamesPlayed);

        deltas[i] = deltas[i]! + kI * (actualI - expectedI) * scale;
        deltas[j] = deltas[j]! + kJ * (actualJ - expectedJ) * scale;
      }
    }

    // Apply deltas
    for (final i in indexToSaved.keys) {
      indexToSaved[i]!.rating += deltas[i]!;
      // Floor at 100 to prevent negative/very low ratings
      if (indexToSaved[i]!.rating < 100) {
        indexToSaved[i]!.rating = 100;
      }
    }
  }
}
