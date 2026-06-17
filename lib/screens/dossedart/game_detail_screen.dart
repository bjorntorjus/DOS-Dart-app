import 'package:flutter/material.dart';

import '../../models/earned_feat.dart';
import '../../models/game_history.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/achievement_medal.dart';
import '../../widgets/dossedart/arcade_frame.dart';
import '../../widgets/dossedart/dossedart_player_avatar.dart';
import '../../widgets/dossedart/dossedart_top_bar.dart';

/// KAMPDETALJER — drill-down for a single recorded game, reached from the
/// HISTORIKK tab. Shows final standings + ΔELO, earned feats, the play-by-play
/// (progression chart + round log) and a per-player comparison. Games saved
/// before throwHistory existed fall back to an empty state for the play-by-play.
class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.entry});

  final GameHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ranked = [...entry.players]
      ..sort((a, b) => a.placement.compareTo(b.placement));
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: 'KAMPDETALJER',
                onExit: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _Banner(entry: entry, winner: ranked.first),
                    const SizedBox(height: 14),
                    _DetailSection(
                      title: 'SLUTTSTILLING',
                      child: Column(
                        children: [
                          for (final p in ranked) _StandingRow(player: p),
                        ],
                      ),
                    ),
                    if (entry.players.any((p) => (p.earnedFeats ?? []).isNotEmpty))
                      _DetailSection(
                        title: 'PRESTASJONER DENNE KAMPEN',
                        child: _FeatsGrid(players: entry.players),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color placementColor(int placement) => switch (placement) {
      1 => DossedartTokens.yellow,
      2 => DossedartTokens.silver,
      3 => DossedartTokens.bronze,
      _ => DossedartTokens.phosphor,
    };

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

/// A bordered arcade section with a PressStart2P heading — mirrors the stats
/// screen's section card so KAMPDETALJER reads as the same surface.
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(
            color: DossedartTokens.cyan, width: DossedartTokens.borderThin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.cyan,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.entry, required this.winner});
  final GameHistoryEntry entry;
  final GameHistoryPlayer winner;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (entry.durationSeconds != null) formatDuration(entry.durationSeconds!),
      if (entry.rounds != null) 'R${entry.rounds}',
      'WINNER ${winner.name}',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(
            color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.gameConfig ?? entry.gameMode.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: DossedartTokens.yellow,
                        letterSpacing: 1)),
              ),
              Text(
                '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                style: const TextStyle(
                    color: DossedartTokens.phosphor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(parts.join('  ·  '),
              style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

/// 2-column grid of feat chips, one per (player, earnedFeat). A ✦ feat is an
/// in-game moment; a ★ unlock is a newly-earned achievement.
class _FeatsGrid extends StatelessWidget {
  const _FeatsGrid({required this.players});
  final List<GameHistoryPlayer> players;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final p in players)
        for (final f in p.earnedFeats ?? const <EarnedFeat>[])
          _FeatChip(playerName: p.name, feat: f),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _FeatChip extends StatelessWidget {
  const _FeatChip({required this.playerName, required this.feat});
  final String playerName;
  final EarnedFeat feat;

  @override
  Widget build(BuildContext context) {
    final color = AchievementMedal.tierColor(feat.tier);
    final marker = feat.kind == FeatKind.unlock ? '★' : '✦';
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color, width: DossedartTokens.borderThin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(marker, style: TextStyle(color: color, fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(feat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(feat.note ?? playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: DossedartTokens.phosphor, fontSize: 10)),
          if (feat.note != null)
            Text(playerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: DossedartTokens.phosphor, fontSize: 9)),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.player});
  final GameHistoryPlayer player;

  @override
  Widget build(BuildContext context) {
    final color = placementColor(player.placement);
    final darts = player.stats['darts'] ?? player.stats['totalDarts'];
    final delta = player.ratingDelta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${player.placement}',
                style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 12, color: color)),
          ),
          DossedartPlayerAvatar(
            size: 36,
            borderColor: color,
            avatarPath: null,
            borderWidth: DossedartTokens.borderThin,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: player.placement == 1
                            ? DossedartTokens.yellow
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (darts != null)
                  Text('$darts darts',
                      style: const TextStyle(
                          color: DossedartTokens.phosphor, fontSize: 11)),
              ],
            ),
          ),
          if (delta != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${delta >= 0 ? '+' : ''}${delta.round()}',
                    style: TextStyle(
                        color: delta >= 0
                            ? DossedartTokens.green
                            : DossedartTokens.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                if (player.ratingBefore != null && player.ratingAfter != null)
                  Text(
                      '${player.ratingBefore!.round()}→${player.ratingAfter!.round()}',
                      style: const TextStyle(
                          color: DossedartTokens.phosphor, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }
}
