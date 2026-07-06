import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_history.dart';
import '../models/saved_player.dart';
import '../stats/game_detail_stats.dart';
import 'game_history_service.dart';
import 'player_storage.dart';

/// One-time cleanup for the turn-aggregation bug: X01 turn stats used to be
/// grouped by `scoreAtStartOfTurn`, which merged a busted turn into the next
/// turn at the same score and could push "highest turn" past the 180 max
/// (e.g. the bogus 190 record). The live code now groups by `turnId` (see
/// [x01TurnTotals]); this migration repairs already-persisted stats.
class StatsMigration {
  /// SharedPreferences flag marking the turn-fix migration as done.
  static const flagKey = 'stats_turn_fix_v1_done';

  /// Hard ceiling for any 3-dart turn. Three triple-20s = 180.
  static const _maxTurn = 180;

  static const _modes = ['x01'];

  /// Runs the migration once. Safe to call on every startup — it no-ops after
  /// the first successful run.
  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flagKey) ?? false) return;

    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();
    if (fixPlayers(players, history)) {
      await PlayerStorage.savePlayers(players);
    }
    await prefs.setBool(flagKey, true);
  }

  /// Repairs [players] in-place against [history]. Returns true if anything
  /// changed. Pure (no I/O) so it can be unit-tested directly.
  ///
  /// For each affected mode: if game history fully covers the player's games,
  /// the turn counters are recomputed exactly (from stored throws where
  /// available, else from each game's stored snapshot clamped to 180). If
  /// coverage is incomplete (e.g. a heavy player whose oldest games have
  /// scrolled out of history), only the impossible "highest turn" value is
  /// clamped to 180 — rebuilding sums from a truncated history would
  /// under-count and is worse than the bug's small skew.
  static bool fixPlayers(
      List<SavedPlayer> players, List<GameHistoryEntry> history) {
    var changed = false;
    for (final player in players) {
      for (final mode in _modes) {
        final ms = player.modeStats[mode];
        if (ms == null) continue;
        if (_fixMode(player, mode, ms, history)) changed = true;
      }
      if (_fixBestTurn(player, history)) changed = true;
    }
    return changed;
  }

  /// Repairs the cross-mode [SavedPlayer.highestTurnScore] ("best turn"), which
  /// X01 and Splitscore both write. Only X01 carried the merge bug, but the
  /// field is a single max so the contributions can't be separated: recompute
  /// the true best 3-dart turn across all the player's games when history fully
  /// covers them, otherwise just clamp the impossible value to 180.
  static bool _fixBestTurn(SavedPlayer player, List<GameHistoryEntry> history) {
    final games = history
        .where((e) => e.players.any((gp) => gp.savedPlayerId == player.id))
        .toList();
    final fullyCovered =
        player.gamesPlayed > 0 && games.length >= player.gamesPlayed;

    int best;
    if (fullyCovered) {
      best = 0;
      for (final game in games) {
        final idx =
            game.players.indexWhere((gp) => gp.savedPlayerId == player.id);
        if (idx < 0) continue;
        final throws = game.throwHistory;
        if (throws != null) {
          for (final t in x01TurnTotals(throws, playerIndex: idx)) {
            if (t > best) best = t;
          }
        } else {
          // No raw throws — fall back to the game's stored best turn (clamped).
          final s = game.players[idx].stats;
          final h = s['max:highestTurn'] ?? s['highestTurn'] ?? 0;
          final clamped = h > _maxTurn ? _maxTurn : h;
          if (clamped > best) best = clamped;
        }
      }
    } else {
      if (player.highestTurnScore <= _maxTurn) return false;
      best = _maxTurn;
    }

    if (player.highestTurnScore != best) {
      player.highestTurnScore = best;
      return true;
    }
    return false;
  }

  static bool _fixMode(SavedPlayer player, String mode, ModeStats ms,
      List<GameHistoryEntry> history) {
    final games = history
        .where((e) =>
            e.gameMode == mode &&
            e.players.any((gp) => gp.savedPlayerId == player.id))
        .toList();

    final fullyCovered = ms.played > 0 && games.length >= ms.played;
    if (!fullyCovered) {
      // Can't trust a rebuild — just remove the impossible value.
      if (ms.get('highestTurn') > _maxTurn) {
        ms.counters['highestTurn'] = _maxTurn;
        return true;
      }
      return false;
    }

    var highest = 0, turns = 0, score = 0, over100 = 0;
    for (final game in games) {
      final idx = game.players.indexWhere((gp) => gp.savedPlayerId == player.id);
      final throws = game.throwHistory;
      if (throws != null && idx >= 0) {
        final totals = x01TurnTotals(throws, playerIndex: idx);
        for (final t in totals) {
          if (t > highest) highest = t;
          turns++;
          score += t;
          if (t >= 100) over100++;
        }
      } else if (idx >= 0) {
        // No raw throws kept for this game — fall back to its stored snapshot,
        // clamping the (possibly merged) highest turn to the 180 ceiling.
        final s = game.players[idx].stats;
        final h = (s['max:highestTurn'] ?? s['highestTurn'] ?? 0);
        if (h > highest) highest = h > _maxTurn ? _maxTurn : h;
        turns += s['totalTurns'] ?? 0;
        score += s['totalTurnScore'] ?? 0;
        over100 += s['turnsOver100'] ?? 0;
      }
    }

    var changed = false;
    void set(String key, int value) {
      if (ms.get(key) != value) {
        ms.counters[key] = value;
        changed = true;
      }
    }

    set('highestTurn', highest);
    set('totalTurns', turns);
    set('totalTurnScore', score);
    set('turnsOver100', over100);
    return changed;
  }
}
