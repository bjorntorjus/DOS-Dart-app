import 'dart:async';
import '../models/achievement.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
import '../models/game_outcome.dart';
import '../models/saved_player.dart';
import '../models/season.dart';

class AchievementUnlock {
  final SavedPlayer player;
  final Achievement achievement;
  const AchievementUnlock(this.player, this.achievement);
}

/// Routes the two unlock paths (live in-game events vs game-end milestones),
/// persists unlocks on the SavedPlayer, and emits a stream the banner consumes.
/// Persisting the mutated player is the caller's responsibility (the game
/// screen already saves the player after recording stats).
class AchievementService {
  AchievementService._(this._catalog);
  static final AchievementService instance = AchievementService._(const []);

  /// Test constructor with an explicit catalog.
  factory AchievementService.forTest(List<Achievement> catalog) =>
      AchievementService._(catalog);

  List<Achievement> _catalog;
  void registerCatalog(List<Achievement> catalog) => _catalog = catalog;

  final _unlockController = StreamController<AchievementUnlock>.broadcast();
  Stream<AchievementUnlock> get unlocks => _unlockController.stream;

  bool _unlock(SavedPlayer player, Achievement a, {required bool emit}) {
    if (player.unlockedAchievementIds.contains(a.id)) return false;
    player.unlockedAchievementIds.add(a.id);
    player.achievementUnlockedAt[a.id] = DateTime.now();
    if (emit) _unlockController.add(AchievementUnlock(player, a));
    return true;
  }

  /// A season closed → unlock the season badges this player just earned.
  ///
  /// These are lifetime unlocks like every other; only the trigger is new.
  /// One evaluation path serves both because `ctx.season` is null at game end,
  /// so every season badge tests it first and stays inert there.
  ///
  /// Emits on the banner stream like [checkEvent] — a season ending is
  /// exactly the moment worth celebrating.
  List<Achievement> evaluateSeasonClose(
      SavedPlayer player, SeasonStanding standing) {
    final ctx = AchievementContext(player: player, season: standing);
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (!a.id.startsWith('x_season_')) continue;
      if (!(a.milestoneTest?.call(ctx) ?? false)) continue;
      if (_unlock(player, a, emit: true)) newly.add(a);
    }
    return newly;
  }

  /// Live in-game event → unlock matching event badges, emit banner.
  List<Achievement> checkEvent(AchievementEvent event, SavedPlayer player) {
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (a.event == event && _unlock(player, a, emit: true)) newly.add(a);
    }
    return newly;
  }

  /// Game-end milestone evaluation against the updated player + outcome.
  List<Achievement> evaluateMilestones(SavedPlayer player, GameOutcome outcome) {
    final ctx = AchievementContext(player: player, outcome: outcome);
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (a.milestoneTest != null &&
          a.milestoneTest!(ctx) &&
          _unlock(player, a, emit: true)) {
        newly.add(a);
      }
    }
    return newly;
  }

  /// Game-end convenience used by every cockpit: fire each player's signature
  /// events then evaluate milestones, building the [GameOutcome] from the
  /// per-player data the screen already has. [eventsByIndex] / [countersByIndex]
  /// are keyed by player index. The winner is whoever has the best (lowest)
  /// placement; a shared best placement is a draw (no winner). Caller
  /// persists [savedPlayers] afterwards.
  /// Returns the achievements newly unlocked this game, keyed by player index
  /// (used to surface ★ unlocks on KAMPDETALJER). Empty when nothing unlocked.
  Map<int, List<Achievement>> awardGameEnd({
    required GameMode mode,
    required List<String?> playerIds,
    required List<SavedPlayer> savedPlayers,
    required List<int> placements,
    required Map<String, double> ratingsBefore,
    required Map<String, double> ratingsAfter,
    Map<int, List<AchievementEvent>> eventsByIndex = const {},
    Map<int, Map<String, int>> countersByIndex = const {},
  }) {
    if (placements.isEmpty) return const {};
    final best = placements.reduce((a, b) => a < b ? a : b);
    // A shared best placement is a draw — nobody gets win credit.
    final bestIsShared = placements.where((p) => p == best).length > 1;
    final unlockedByIndex = <int, List<Achievement>>{};
    for (int i = 0; i < playerIds.length; i++) {
      final id = playerIds[i];
      if (id == null) continue;
      final sp = savedPlayers.where((s) => s.id == id).firstOrNull;
      if (sp == null) continue;
      final newly = <Achievement>[];
      for (final e in eventsByIndex[i] ?? const <AchievementEvent>[]) {
        newly.addAll(checkEvent(e, sp));
      }
      final opponents = <double>[];
      for (int j = 0; j < playerIds.length; j++) {
        if (j == i) continue;
        final oid = playerIds[j];
        final r = oid == null ? null : ratingsBefore[oid];
        if (r != null) opponents.add(r);
      }
      newly.addAll(evaluateMilestones(
        sp,
        GameOutcome(
          mode: mode,
          won: placements[i] == best && !bestIsShared,
          placement: placements[i],
          playerCount: playerIds.length,
          ratingBefore: ratingsBefore[id] ?? sp.rating,
          ratingAfter: ratingsAfter[id] ?? sp.rating,
          opponentRatingsBefore: opponents,
          gameCounters: countersByIndex[i] ?? const {},
        ),
      ));
      if (newly.isNotEmpty) unlockedByIndex[i] = newly;
    }
    return unlockedByIndex;
  }

  /// Pre-1.8.4 builds granted these falsely (bust-tainted feats, missing
  /// turnId, tie-as-win). One-time strip; players re-earn them legitimately.
  static const falselyGrantedIds = {
    'cri_the_nine',
    'x01_maximum',
    'x01_bullseye_finish',
    'kil_killing_spree',
    'spl_clutch_save',
    'x_natural_talent',
    'x_giant_slayer',
  };

  /// One-time revocation of the badges 1.8.3 granted via since-fixed bugs.
  /// Returns true when the player record changed (flag flipped).
  bool revokeFalseUnlocks(SavedPlayer player) {
    if (player.falseUnlocksRevoked) return false;
    player.unlockedAchievementIds.removeAll(falselyGrantedIds);
    player.achievementUnlockedAt
        .removeWhere((k, _) => falselyGrantedIds.contains(k));
    player.falseUnlocksRevoked = true;
    return true;
  }

  /// One-time silent retro grant: unlock career-provable milestone badges with
  /// no banner. Per-game predicates see a null outcome and return false.
  void retroGrantSilently(SavedPlayer player) {
    if (player.achievementsRetroGranted) return;
    final ctx = AchievementContext(player: player, outcome: null);
    for (final a in _catalog) {
      if (a.milestoneTest != null && a.milestoneTest!(ctx)) {
        _unlock(player, a, emit: false);
      }
    }
    player.achievementsRetroGranted = true;
  }
}
