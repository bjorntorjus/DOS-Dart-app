import 'package:flutter/widgets.dart';
import 'achievement_event.dart';
import 'game_outcome.dart';
import 'saved_player.dart';

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
  const AchievementContext({required this.player, this.outcome});
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
