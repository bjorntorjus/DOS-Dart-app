import 'package:flutter/material.dart';
import '../../data/achievement_catalog.dart';
import '../../models/achievement.dart';
import '../../models/saved_player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/achievement_medal.dart';

/// Arcade gallery of all achievements for one player: unlocked badges in full
/// color, locked ones dimmed with their description. Filterable by tier.
class AchievementsGalleryScreen extends StatefulWidget {
  const AchievementsGalleryScreen({super.key, required this.player});

  final SavedPlayer player;

  @override
  State<AchievementsGalleryScreen> createState() =>
      _AchievementsGalleryScreenState();
}

class _AchievementsGalleryScreenState extends State<AchievementsGalleryScreen> {
  AchievementTier? _tierFilter; // null = all

  bool _isUnlocked(Achievement a) =>
      widget.player.unlockedAchievementIds.contains(a.id);

  @override
  Widget build(BuildContext context) {
    final all = achievementCatalog;
    final shown = _tierFilter == null
        ? all
        : all.where((a) => a.tier == _tierFilter).toList();
    final unlockedCount = all.where(_isUnlocked).length;

    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'ACHIEVEMENTS',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: DossedartTokens.yellow,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '$unlockedCount / ${all.length}',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: DossedartTokens.cyan,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: all.isEmpty ? 0 : unlockedCount / all.length,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(DossedartTokens.green),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _FilterBar(
            selected: _tierFilter,
            onChanged: (t) => setState(() => _tierFilter = t),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: shown.length,
              itemBuilder: (ctx, i) =>
                  _GalleryTile(achievement: shown[i], unlocked: _isUnlocked(shown[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final AchievementTier? selected;
  final ValueChanged<AchievementTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, AchievementTier? value) {
      final on = selected == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          onSelected: (_) => onChanged(value),
          showCheckmark: false,
          backgroundColor: DossedartTokens.surface,
          selectedColor: DossedartTokens.cyan.withValues(alpha: 0.25),
          labelStyle: TextStyle(
            color: on ? DossedartTokens.cyan : DossedartTokens.phosphor,
            fontSize: 11,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          chip('ALL', null),
          chip('BRONZE', AchievementTier.bronze),
          chip('SILVER', AchievementTier.silver),
          chip('GOLD', AchievementTier.gold),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: achievement.description,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AchievementMedal(achievement: achievement, unlocked: unlocked, size: 64),
          const SizedBox(height: 6),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'PressStart2P',
              height: 1.3,
              color: unlocked ? Colors.white : DossedartTokens.disabledFg,
            ),
          ),
        ],
      ),
    );
  }
}
