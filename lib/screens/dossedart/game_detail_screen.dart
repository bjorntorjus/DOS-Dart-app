import 'package:flutter/material.dart';

import '../../models/dart_throw.dart';
import '../../models/earned_feat.dart';
import '../../models/game_history.dart';
import '../../stats/game_detail_stats.dart';
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
                    if (entry.throwHistory != null &&
                        entry.throwHistory!.isNotEmpty) ...[
                      _DetailSection(
                        title: 'SPILLFORLØP',
                        child: _ProgressSection(entry: entry),
                      ),
                      _DetailSection(
                        title: 'RUNDE FOR RUNDE',
                        child: _RoundLog(entry: entry),
                      ),
                    ] else
                      const _DetailSection(
                        title: 'SPILLFORLØP',
                        child: Text('Forløp ikke lagret for denne kampen',
                            style: TextStyle(
                                color: DossedartTokens.phosphor, fontSize: 12)),
                      ),
                    _DetailSection(
                      title: 'PER SPILLER',
                      child: _StatGrid(entry: entry),
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

/// Round-by-round throw log. Collapsed to the first [_collapsedRounds] rounds
/// with a "VIS ALLE N RUNDER ›" expander.
class _RoundLog extends StatefulWidget {
  const _RoundLog({required this.entry});
  final GameHistoryEntry entry;
  @override
  State<_RoundLog> createState() => _RoundLogState();
}

class _RoundLogState extends State<_RoundLog> {
  static const _collapsedRounds = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final throws = widget.entry.throwHistory!;
    final byRound = <int, List<DartThrow>>{};
    for (final t in throws) {
      (byRound[t.roundNumber] ??= []).add(t);
    }
    final rounds = byRound.keys.toList()..sort();
    final shown = _expanded ? rounds : rounds.take(_collapsedRounds).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in shown) _RoundBlock(round: r, darts: byRound[r]!, players: widget.entry.players),
        if (!_expanded && rounds.length > _collapsedRounds)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('VIS ALLE ${rounds.length} RUNDER ›',
                  style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: DossedartTokens.cyan)),
            ),
          ),
      ],
    );
  }
}

class _RoundBlock extends StatelessWidget {
  const _RoundBlock(
      {required this.round, required this.darts, required this.players});
  final int round;
  final List<DartThrow> darts;
  final List<GameHistoryPlayer> players;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('R$round',
              style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: DossedartTokens.phosphor)),
          const SizedBox(height: 4),
          for (var i = 0; i < players.length; i++)
            if (darts.any((d) => d.playerIndex == i))
              _RoundPlayerLine(
                name: players[i].name,
                darts: darts.where((d) => d.playerIndex == i).toList(),
              ),
        ],
      ),
    );
  }
}

class _RoundPlayerLine extends StatelessWidget {
  const _RoundPlayerLine({required this.name, required this.darts});
  final String name;
  final List<DartThrow> darts;

  @override
  Widget build(BuildContext context) {
    final total = darts.fold<int>(0, (s, d) => s + d.points);
    final is180 = total == 180;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [for (final d in darts) _ThrowChip(dart: d)],
            ),
          ),
          const SizedBox(width: 8),
          Text('$total',
              style: TextStyle(
                  color: is180 ? DossedartTokens.yellow : DossedartTokens.phosphor,
                  fontSize: 13,
                  fontWeight: is180 ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _ThrowChip extends StatelessWidget {
  const _ThrowChip({required this.dart});
  final DartThrow dart;

  @override
  Widget build(BuildContext context) {
    // Triple = cyan, double = magenta, single = dim, miss/bust = dim red.
    final Color color;
    if (dart.isBust) {
      color = DossedartTokens.red;
    } else if (dart.segment == 0) {
      color = DossedartTokens.phosphor;
    } else if (dart.multiplier == 3) {
      color = DossedartTokens.cyan;
    } else if (dart.multiplier == 2) {
      color = DossedartTokens.magenta;
    } else {
      color = DossedartTokens.phosphor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color, width: DossedartTokens.borderThin),
      ),
      child: Text(dart.shortLabel,
          style: TextStyle(color: color, fontSize: 11, fontFamily: 'VT323')),
    );
  }
}

class _GridRowData {
  _GridRowData(this.label, this.values, this.display, this.higherIsBetter);
  final String label;
  final List<num?> values; // null = missing
  final List<String> display;
  final bool higherIsBetter;
}

/// Side-by-side per-player comparison. X01 derives rich rows from throwHistory;
/// other modes (or pre-throwHistory games) fall back to the stored counters.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.entry});
  final GameHistoryEntry entry;

  List<_GridRowData> _rows() {
    final players = entry.players;
    if (entry.gameMode == 'x01' && entry.throwHistory != null) {
      final s = [
        for (var i = 0; i < players.length; i++)
          x01GridStats(entry.throwHistory!, playerIndex: i),
      ];
      return [
        _GridRowData('3-DART AVG', [for (final x in s) x.avg3],
            [for (final x in s) x.avg3.toStringAsFixed(1)], true),
        _GridRowData('BEST TURN', [for (final x in s) x.bestTurn],
            [for (final x in s) '${x.bestTurn}'], true),
        _GridRowData('180s', [for (final x in s) x.n180],
            [for (final x in s) '${x.n180}'], true),
        _GridRowData('140+', [for (final x in s) x.n140],
            [for (final x in s) '${x.n140}'], true),
        _GridRowData('DOUBLES', [for (final x in s) x.doublesHit],
            [for (final x in s) '${x.doublesHit}'], true),
        _GridRowData('DARTS', [for (final x in s) x.darts],
            [for (final x in s) '${x.darts}'], false),
      ];
    }
    // Fallback: union of stored counter keys, higher assumed better, — if absent.
    final keys = <String>{for (final p in players) ...p.stats.keys}.toList();
    return [
      for (final k in keys)
        _GridRowData(
          k.toUpperCase(),
          [for (final p in players) p.stats[k]],
          [for (final p in players) p.stats.containsKey(k) ? '${p.stats[k]}' : '—'],
          true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final players = entry.players;
    final rows = _rows();
    return Column(
      children: [
        // Header: player names.
        Row(
          children: [
            const SizedBox(width: 96),
            for (final p in players)
              Expanded(
                child: Text(p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: DossedartTokens.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rows) _StatGridRow(row: row),
      ],
    );
  }
}

class _StatGridRow extends StatelessWidget {
  const _StatGridRow({required this.row});
  final _GridRowData row;

  @override
  Widget build(BuildContext context) {
    // Best value among present cells (max or min by higherIsBetter).
    final present = row.values.whereType<num>().toList();
    num? best;
    if (present.length > 1) {
      best = row.higherIsBetter
          ? present.reduce((a, b) => a > b ? a : b)
          : present.reduce((a, b) => a < b ? a : b);
      // Don't highlight when everyone ties.
      if (present.every((v) => v == best)) best = null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(row.label,
                style: const TextStyle(
                    color: DossedartTokens.phosphor, fontSize: 11)),
          ),
          for (var i = 0; i < row.display.length; i++)
            Expanded(
              child: Text(row.display[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: (best != null && row.values[i] == best)
                          ? DossedartTokens.green
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: (best != null && row.values[i] == best)
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ),
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
