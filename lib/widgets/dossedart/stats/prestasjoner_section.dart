import 'package:flutter/material.dart';
import '../../../data/achievement_catalog.dart';
import '../../../models/achievement.dart';
import '../../../models/saved_player.dart';
import '../../../screens/dossedart/achievements_gallery_screen.dart';
import '../../../theme/dossedart_tokens.dart';
import '../achievement_medal.dart';

/// PROFILE-tab achievements section: unlocked count + a row of recent medals +
/// a few "still to unlock" badges + a button into the full gallery.
class PrestasjonerSection extends StatelessWidget {
  const PrestasjonerSection({super.key, required this.player});

  final SavedPlayer player;

  @override
  Widget build(BuildContext context) {
    final all = achievementCatalog;
    final unlocked =
        all.where((a) => player.unlockedAchievementIds.contains(a.id)).toList();
    final locked =
        all.where((a) => !player.unlockedAchievementIds.contains(a.id)).toList();

    // Most-recently unlocked first (by unlock timestamp when present).
    unlocked.sort((a, b) {
      final ta = player.achievementUnlockedAt[a.id];
      final tb = player.achievementUnlockedAt[b.id];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final recent = unlocked.take(5).toList();
    final next = locked.take(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ACHIEVEMENTS',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: DossedartTokens.yellow,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Text(
                '${unlocked.length} / ${all.length}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: DossedartTokens.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isNotEmpty) ...[
            const _Caption('RECENT'),
            const SizedBox(height: 6),
            _MedalRow(items: recent, unlocked: true),
            const SizedBox(height: 12),
          ],
          if (next.isNotEmpty) ...[
            const _Caption('STILL TO UNLOCK'),
            const SizedBox(height: 6),
            _MedalRow(items: next, unlocked: false),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.emoji_events, size: 18),
              label: const Text('VIEW ALL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DossedartTokens.cyan,
                side: const BorderSide(color: DossedartTokens.cyan, width: DossedartTokens.borderThin),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AchievementsGalleryScreen(player: player),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: DossedartTokens.phosphor,
          letterSpacing: 1,
        ),
      );
}

class _MedalRow extends StatelessWidget {
  const _MedalRow({required this.items, required this.unlocked});
  final List<Achievement> items;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _showAchievementInfo(context, a, unlocked),
                child: AchievementMedal(
                    achievement: a, unlocked: unlocked, size: 44),
              ),
            ),
        ],
      ),
    );
  }
}

void _showAchievementInfo(BuildContext context, Achievement a, bool unlocked) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: DossedartTokens.surface,
      shape: Border.all(color: DossedartTokens.cyan, width: 2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: a, unlocked: unlocked, size: 64),
            const SizedBox(height: 12),
            Text(
              a.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 12,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.phosphor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
