import 'package:flutter/material.dart';

import '../../models/earned_feat.dart';
import '../../models/game_history.dart';
import '../../stats/mode_progression.dart';
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
                    if (entry.throwHistory != null)
                      _DetailSection(
                        title: 'SPILLFORLØP',
                        child: _ProgressSection(entry: entry),
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

const List<Color> _playerPalette = [
  DossedartTokens.cyan,
  DossedartTokens.magenta,
  DossedartTokens.green,
  DossedartTokens.orange,
  DossedartTokens.yellow,
  DossedartTokens.purple,
];

/// Picks the progression strategy for a recorded game. Returns null for modes
/// whose race can't be derived from throws alone (Killer) — those show no chart.
ModeProgression? progressionForEntry(GameHistoryEntry entry) {
  final throws = entry.throwHistory ?? const [];
  switch (entry.gameMode) {
    case 'x01':
      final start = throws.fold<int>(
          0, (m, t) => t.scoreAtStartOfTurn > m ? t.scoreAtStartOfTurn : m);
      return X01Progression(startScore: start > 0 ? start : 501);
    case 'cricket':
    case 'cricket_cutthroat':
      return CricketProgression(
          targets: const {15, 16, 17, 18, 19, 20, 25}, maxValue: 0);
    case 'aroundTheClock':
      return AtcProgression();
    case 'shanghai':
    case 'halveIt':
      return CumulativeScoreProgression(maxValue: 0);
    default:
      return null; // Killer & unknown → round log only
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.entry});
  final GameHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final progression = progressionForEntry(entry);
    if (progression == null) {
      return const Text('Graf utilgjengelig for denne modusen',
          style: TextStyle(color: DossedartTokens.phosphor, fontSize: 12));
    }
    final throws = entry.throwHistory!;
    final series = [
      for (var i = 0; i < entry.players.length; i++)
        progression.seriesFor(throws, playerIndex: i),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _ProgressPainter(progression: progression, series: series),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < entry.players.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 12,
                    height: 3,
                    color: _playerPalette[i % _playerPalette.length]),
                const SizedBox(width: 6),
                Text(entry.players[i].name,
                    style: const TextStyle(
                        color: DossedartTokens.phosphor, fontSize: 11)),
              ]),
          ],
        ),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.progression, required this.series});
  final ModeProgression progression;
  final List<List<num>> series;

  @override
  void paint(Canvas canvas, Size size) {
    final dataMax =
        series.expand((s) => s).fold<num>(0, (m, v) => v > m ? v : m);
    final top = progression.descending
        ? (progression.maxValue > 0 ? progression.maxValue : (dataMax > 0 ? dataMax : 1))
        : (dataMax > 0 ? dataMax : 1);
    final maxLen = series.fold<int>(1, (m, s) => s.length > m ? s.length : m);

    // Gridlines.
    final grid = Paint()
      ..color = DossedartTokens.phosphor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final y = size.height * g / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final dx = maxLen > 1 ? size.width / (maxLen - 1) : size.width;
    for (var p = 0; p < series.length; p++) {
      final s = series[p];
      if (s.isEmpty) continue;
      final color = _playerPalette[p % _playerPalette.length];
      final path = Path();
      for (var i = 0; i < s.length; i++) {
        final x = dx * i;
        final y = size.height - (s[i] / top) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
      // Finish flag for race-to-0 modes when a series reaches 0.
      if (progression.descending && s.last <= 0) {
        final x = dx * (s.length - 1);
        canvas.drawCircle(
            Offset(x, size.height), 4, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.series != series || old.progression != progression;
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
