import 'package:flutter/widgets.dart';
import 'achievement_event.dart';
import 'event.dart';
import 'game_outcome.dart';
import 'saved_player.dart';
import 'season.dart';

enum AchievementTier { bronze, silver, gold }

enum AchievementCategory { scoring, milestone, streak, social, quirky }

/// A medal glyph: a Material icon today, swappable to a custom asset later
/// without touching the medal widget or call sites (spec decision #7).
class AchievementGlyph {
  final IconData? icon;
  final String? assetPath;
  const AchievementGlyph.icon(this.icon) : assetPath = null;
  const AchievementGlyph.asset(this.assetPath) : icon = null;
  bool get isAsset => assetPath != null;
}

/// Context for a milestone predicate. [outcome] is null during silent retro —
/// per-game predicates MUST null-check it and return false, so retro only ever
/// grants career-provable badges.
class AchievementContext {
  final SavedPlayer player;
  final GameOutcome? outcome;

  /// Set only when a season closes. Null at game end, which is how the season
  /// badges stay inert on the normal path — they all test `ctx.season` first,
  /// so one evaluation path serves both without a parallel system.
  final SeasonStanding? season;

  /// Set only when an event closes — same trick as [season]: the event badges
  /// all test `ctx.event` first and stay inert at game end.
  final EventStanding? event;

  const AchievementContext({
    required this.player,
    this.outcome,
    this.season,
    this.event,
  });
}

typedef MilestoneTest = bool Function(AchievementContext ctx);

class Achievement {
  final String id;
  final String name; // globally unique (spec decision #1)
  final String description;
  final AchievementTier tier;
  final AchievementCategory category;
  final AchievementGlyph glyph;
  final String? mode; // GameMode.name, or null for cross-cutting
  final MilestoneTest? milestoneTest; // threshold/career/per-game; null for pure events
  final AchievementEvent? event; // in-game event; null for milestones

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.category,
    required this.glyph,
    this.mode,
    this.milestoneTest,
    this.event,
  });
}
