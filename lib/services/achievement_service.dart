import 'dart:async';
import '../models/achievement.dart';
import '../models/achievement_event.dart';
import '../models/game_outcome.dart';
import '../models/saved_player.dart';

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
