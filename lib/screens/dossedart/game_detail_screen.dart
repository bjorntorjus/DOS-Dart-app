import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/dart_throw.dart';
import '../../models/earned_feat.dart';
import '../../models/game_history.dart';
import '../../stats/game_detail_stats.dart';
import '../../stats/mode_progression.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/arcade_frame.dart';
import '../../widgets/dossedart/dossedart_player_avatar.dart';

/// KAMPDETALJER — drill-down for a single recorded game, reached from HISTORIKK.
/// Faithful to the design handoff (game-detail.jsx): banner, standings + ΔELO,
/// leg-progression chart, per-player comparison, earned feats, round-by-round
/// log. Section order tuned per request: chart high, PER SPILLER prominent,
/// RUNDE FOR RUNDE at the bottom. Games without throwHistory show an empty
/// state for the play-by-play. All logic reuses the stats/* derivations.
class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.entry});

  final GameHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ranked = [...entry.players]
      ..sort((a, b) => a.placement.compareTo(b.placement));
    final hasThrows =
        entry.throwHistory != null && entry.throwHistory!.isNotEmpty;
    final hasFeats =
        entry.players.any((p) => (p.earnedFeats ?? const []).isNotEmpty);

    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _Banner(entry: entry, winner: ranked.first),

                    const _SectionLabel('SLUTTSTILLING'),
                    for (final p in ranked) _StandingRow(player: p),

                    // Graph stays near the top — it tells the match's story.
                    const _SectionLabel('SPILLFORLØP',
                        color: DossedartTokens.cyan, right: 'kappløpet'),
                    if (hasThrows)
                      _ProgressSection(entry: entry)
                    else
                      const _Pad(
                        child: Text('Forløp ikke lagret for denne kampen',
                            style: TextStyle(
                                color: DossedartTokens.phosphor,
                                fontFamily: 'VT323',
                                fontSize: 16)),
                      ),

                    // PER SPILLER promoted above the round log (more to chew on).
                    const _SectionLabel('PER SPILLER', right: 'side om side'),
                    _StatGrid(entry: entry),

                    if (hasFeats) ...[
                      const _SectionLabel('PRESTASJONER DENNE KAMPEN',
                          color: DossedartTokens.yellow,
                          right: 'hva hver spiller oppnådde'),
                      _FeatsGrid(players: entry.players),
                    ],

                    if (hasThrows) ...[
                      const _SectionLabel('RUNDE FOR RUNDE',
                          color: DossedartTokens.magenta, right: 'pil for pil'),
                      _RoundLog(entry: entry),
                    ],
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

// ───────────────────────── helpers ─────────────────────────

Color placementColor(int placement) => switch (placement) {
      1 => DossedartTokens.yellow,
      2 => DossedartTokens.silver,
      3 => DossedartTokens.bronze,
      _ => const Color(0x8CD9D2C2), // phosphor @ 55%
    };

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

const _playerPalette = [
  DossedartTokens.cyan,
  DossedartTokens.silver,
  DossedartTokens.green,
  DossedartTokens.orange,
  DossedartTokens.yellow,
  DossedartTokens.magenta,
];

/// Horizontal page padding shared by sections.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border:
            Border(bottom: BorderSide(color: DossedartTokens.magenta, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Text('◀ HISTORIKK',
                style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 18,
                    color: DossedartTokens.cyan,
                    letterSpacing: 2,
                    height: 1)),
          ),
          const Expanded(
            child: Center(
              child: Text('KAMPDETALJER',
                  style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: DossedartTokens.yellow,
                      letterSpacing: 2,
                      height: 1.3)),
            ),
          ),
          // DEL ↗ deferred (no share payload yet) — reserve the space so the
          // title stays centred, matching the artboard's three-slot header.
          const SizedBox(width: 86),
        ],
      ),
    );
  }
}

/// Magenta/cyan/yellow arcade section label + divider line + optional caption.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text,
      {this.color = DossedartTokens.magenta, this.right});
  final String text;
  final Color color;
  final String? right;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 11),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: color,
                  letterSpacing: 2)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
          if (right != null) ...[
            const SizedBox(width: 10),
            Text(right!,
                style: const TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 15,
                    color: Color(0x80FFFFFF),
                    letterSpacing: 1)),
          ],
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
    final stats = <(String, String)>[
      if (entry.durationSeconds != null)
        ('VARIGHET', formatDuration(entry.durationSeconds!)),
      if (entry.rounds != null) ('RUNDER', '${entry.rounds}'),
      ('VINNER', winner.name),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DossedartTokens.yellow.withValues(alpha: 0.04),
          border: Border.all(
              color: DossedartTokens.yellow.withValues(alpha: 0.33),
              width: DossedartTokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.gameConfig ?? entry.gameMode.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 13,
                          color: DossedartTokens.yellow,
                          letterSpacing: 1,
                          height: 1.3)),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                    style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 16,
                        color: Color(0x99FFFFFF),
                        letterSpacing: 1),
                  ),
                ],
              ),
            ),
            for (final (label, value) in stats)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: label == 'VINNER'
                                ? DossedartTokens.cyan
                                : Colors.white)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 12,
                            color: Color(0x73FFFFFF),
                            letterSpacing: 1)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.player});
  final GameHistoryPlayer player;
  @override
  Widget build(BuildContext context) {
    final c = placementColor(player.placement);
    final isTop = player.placement == 1;
    final delta = player.ratingDelta;
    final darts = player.stats['darts'] ?? player.stats['totalDarts'];
    final subtitle =
        isTop ? 'Vant' : (darts != null ? '$darts piler' : 'Fullførte');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isTop
              ? DossedartTokens.yellow.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: c.withValues(alpha: 0.27), width: 2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('${player.placement}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 18,
                      color: c,
                      height: 1)),
            ),
            const SizedBox(width: 8),
            DossedartPlayerAvatar(
                size: 42, borderColor: c, avatarPath: null, borderWidth: 2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 15,
                          color: Color(0x80FFFFFF),
                          letterSpacing: 1)),
                ],
              ),
            ),
            if (delta != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 13,
                          color: delta >= 0
                              ? DossedartTokens.green
                              : DossedartTokens.red)),
                  if (player.ratingBefore != null &&
                      player.ratingAfter != null) ...[
                    const SizedBox(height: 4),
                    Text(
                        '${player.ratingBefore!.round()}→${player.ratingAfter!.round()}',
                        style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 13,
                            color: Color(0x73FFFFFF),
                            letterSpacing: 1)),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── feats ─────────────────────────

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
    return _Pad(
      child: LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final chip in chips) SizedBox(width: w, child: chip)],
        );
      }),
    );
  }
}

class _FeatChip extends StatelessWidget {
  const _FeatChip({required this.playerName, required this.feat});
  final String playerName;
  final EarnedFeat feat;
  @override
  Widget build(BuildContext context) {
    final c = _tierColor(feat.tier);
    final isUnlock = feat.kind == FeatKind.unlock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.055),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CustomPaint(
              painter: _HexPainter(c),
              child: Center(
                child: Text(isUnlock ? '★' : '✦',
                    style: TextStyle(
                        fontFamily: 'PressStart2P', fontSize: 11, color: c)),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xD9FFFFFF))),
                    ),
                    if (isUnlock) ...[
                      const SizedBox(width: 7),
                      Text('NY',
                          style: TextStyle(
                              fontFamily: 'VT323', fontSize: 12, color: c, letterSpacing: 1)),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(feat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'PressStart2P', fontSize: 10, color: Colors.white, height: 1.2)),
                if (feat.note != null) ...[
                  const SizedBox(height: 4),
                  Text(feat.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'VT323', fontSize: 13, color: Color(0x80FFFFFF))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _tierColor(AchievementTier tier) => switch (tier) {
      AchievementTier.gold => DossedartTokens.yellow,
      AchievementTier.silver => DossedartTokens.silver,
      AchievementTier.bronze => DossedartTokens.bronze,
    };

class _HexPainter extends CustomPainter {
  _HexPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Pointy-top hexagon matching the artboard polygon.
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.91, h * 0.28)
      ..lineTo(w * 0.91, h * 0.72)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.09, h * 0.72)
      ..lineTo(w * 0.09, h * 0.28)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.13));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}

// ───────────────────────── leg progression ─────────────────────────

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
      return const _Pad(
        child: Text('Graf utilgjengelig for denne modusen',
            style: TextStyle(
                color: DossedartTokens.phosphor,
                fontFamily: 'VT323',
                fontSize: 16)),
      );
    }
    final throws = entry.throwHistory!;
    final series = [
      for (var i = 0; i < entry.players.length; i++)
        progression.seriesFor(throws, playerIndex: i),
    ];
    return _Pad(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: DossedartTokens.magenta.withValues(alpha: 0.2),
              width: DossedartTokens.borderThin),
        ),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _LegPainter(progression: progression, series: series),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 4,
              children: [
                for (var i = 0; i < entry.players.length; i++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 16,
                        height: 3,
                        color: _playerPalette[i % _playerPalette.length]),
                    const SizedBox(width: 7),
                    Text(entry.players[i].name,
                        style: TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 15,
                            color: _playerPalette[i % _playerPalette.length])),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegPainter extends CustomPainter {
  _LegPainter({required this.progression, required this.series});
  final ModeProgression progression;
  final List<List<num>> series;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0, padR = 16.0, padT = 14.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final dataMax =
        series.expand((s) => s).fold<num>(0, (m, v) => v > m ? v : m);
    final top = progression.descending
        ? (progression.maxValue > 0 ? progression.maxValue : (dataMax > 0 ? dataMax : 1))
        : (dataMax > 0 ? dataMax : 1);
    final maxLen = series.fold<int>(1, (m, s) => s.length > m ? s.length : m);

    double xAt(int i) => padL + (maxLen > 1 ? i * plotW / (maxLen - 1) : 0);
    double yAt(num v) => padT + (1 - v / top) * plotH;

    // Gridlines + y labels (5 steps).
    for (var g = 0; g <= 4; g++) {
      final value = top * (4 - g) / 4;
      final y = padT + plotH * g / 4;
      final atZero = (4 - g) == 0;
      canvas.drawLine(
        Offset(padL, y),
        Offset(size.width - padR, y),
        Paint()
          ..color = atZero
              ? DossedartTokens.green.withValues(alpha: 0.27)
              : DossedartTokens.magenta.withValues(alpha: 0.12)
          ..strokeWidth = atZero ? 1.5 : 1,
      );
      _label(canvas, '${value.round()}', Offset(padL - 6, y),
          align: _Align.right,
          color: atZero ? DossedartTokens.green : const Color(0x66FFFFFF));
    }

    // x labels.
    for (var i = 0; i < maxLen; i++) {
      _label(canvas, i == 0 ? 'START' : 'R$i',
          Offset(xAt(i), size.height - 6),
          align: _Align.center, color: const Color(0x66FFFFFF), size: 11);
    }

    // Lines (paint opponents first so player[0] sits on top).
    for (var p = series.length - 1; p >= 0; p--) {
      final s = series[p];
      if (s.isEmpty) continue;
      final color = _playerPalette[p % _playerPalette.length];
      final path = Path();
      for (var i = 0; i < s.length; i++) {
        final o = Offset(xAt(i), yAt(s[i]));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      // Soft glow underlay.
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color);
      for (var i = 0; i < s.length; i++) {
        final finished = progression.descending && s[i] <= 0;
        canvas.drawCircle(Offset(xAt(i), yAt(s[i])), finished ? 6 : 3.4,
            Paint()..color = color);
      }
    }

    // Finish flag for race-to-0 modes.
    if (progression.descending && series.any((s) => s.isNotEmpty && s.last <= 0)) {
      _label(canvas, progression.finishLabel,
          Offset(xAt(maxLen - 1), yAt(0) - 10),
          align: _Align.right, color: DossedartTokens.yellow, size: 9, ps2p: true);
    }
  }

  void _label(Canvas canvas, String text, Offset at,
      {required _Align align,
      required Color color,
      double size = 13,
      bool ps2p = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: ps2p ? 'PressStart2P' : 'VT323',
              fontSize: size,
              color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _Align.right => at.dx - tp.width,
      _Align.center => at.dx - tp.width / 2,
      _Align.left => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_LegPainter old) =>
      old.series != series || old.progression != progression;
}

enum _Align { left, center, right }

// ───────────────────────── per-player grid ─────────────────────────

class _GridRowData {
  _GridRowData(this.label, this.values, this.display, this.higherIsBetter);
  final String label;
  final List<num?> values;
  final List<String> display;
  final bool higherIsBetter;
}

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
        _GridRowData('3-PILERS SNITT', [for (final x in s) x.avg3],
            [for (final x in s) x.avg3.toStringAsFixed(1)], true),
        _GridRowData('BESTE RUNDE', [for (final x in s) x.bestTurn],
            [for (final x in s) '${x.bestTurn}'], true),
        _GridRowData('180 / 140+', [for (final _ in s) null],
            [for (final x in s) '${x.n180} / ${x.n140}'], false),
        _GridRowData('DOBLER', [for (final x in s) x.doublesHit],
            [for (final x in s) '${x.doublesHit}'], true),
        _GridRowData('PILER KASTET', [for (final x in s) x.darts],
            [for (final x in s) '${x.darts}'], false),
      ];
    }
    final keys = <String>{for (final p in players) ...p.stats.keys}.toList();
    return [
      for (final k in keys)
        _GridRowData(
          k.toUpperCase(),
          [for (final p in players) p.stats[k]],
          [
            for (final p in players) p.stats.containsKey(k) ? '${p.stats[k]}' : '—'
          ],
          true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final players = entry.players;
    final rows = _rows();
    return _Pad(
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(
                color: DossedartTokens.magenta.withValues(alpha: 0.2),
                width: DossedartTokens.borderThin)),
        child: Column(
          children: [
            // Header.
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  const Expanded(
                    flex: 14,
                    child: Text('STATISTIKK',
                        style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Color(0x80FFFFFF),
                            letterSpacing: 0.5)),
                  ),
                  for (var i = 0; i < players.length; i++)
                    Expanded(
                      flex: 10,
                      child: Text(players[i].name.toUpperCase(),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                              color: placementColor(players[i].placement),
                              letterSpacing: 0.5)),
                    ),
                ],
              ),
            ),
            for (var r = 0; r < rows.length; r++)
              _StatGridRow(row: rows[r], odd: r.isOdd, players: players.length),
          ],
        ),
      ),
    );
  }
}

class _StatGridRow extends StatelessWidget {
  const _StatGridRow(
      {required this.row, required this.odd, required this.players});
  final _GridRowData row;
  final bool odd;
  final int players;

  @override
  Widget build(BuildContext context) {
    final present = row.values.whereType<num>().toList();
    num? best;
    if (present.length > 1) {
      best = row.higherIsBetter
          ? present.reduce((a, b) => a > b ? a : b)
          : present.reduce((a, b) => a < b ? a : b);
      if (present.every((v) => v == best)) best = null;
    }
    return Container(
      decoration: BoxDecoration(
        color: odd ? Colors.white.withValues(alpha: 0.015) : null,
        border: Border(
            top: BorderSide(
                color: DossedartTokens.magenta.withValues(alpha: 0.12))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Text(row.label,
                style: const TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 16,
                    color: Color(0x99FFFFFF),
                    letterSpacing: 1)),
          ),
          for (var i = 0; i < row.display.length; i++)
            Expanded(
              flex: 10,
              child: Text(row.display[i],
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 11,
                      color: (best != null && row.values[i] == best)
                          ? DossedartTokens.green
                          : Colors.white)),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── round log ─────────────────────────

class _RoundLog extends StatefulWidget {
  const _RoundLog({required this.entry});
  final GameHistoryEntry entry;
  @override
  State<_RoundLog> createState() => _RoundLogState();
}

class _RoundLogState extends State<_RoundLog> {
  static const _collapsed = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final players = widget.entry.players;
    final throws = widget.entry.throwHistory!;
    final descending = progressionForEntry(widget.entry)?.descending ?? false;
    final byRound = <int, List<DartThrow>>{};
    for (final t in throws) {
      (byRound[t.roundNumber] ??= []).add(t);
    }
    final rounds = byRound.keys.toList()..sort();
    final shown = _expanded ? rounds : rounds.take(_collapsed).toList();

    return _Pad(
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(
                color: DossedartTokens.magenta.withValues(alpha: 0.2),
                width: DossedartTokens.borderThin)),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Column(
          children: [
            // Column header: blank + player names.
            Container(
              padding: const EdgeInsets.only(top: 9, bottom: 6),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: DossedartTokens.magenta.withValues(alpha: 0.27),
                          width: 2))),
              child: Row(
                children: [
                  const SizedBox(width: 34),
                  for (var i = 0; i < players.length; i++)
                    Expanded(
                      child: Text(players[i].name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                              color: _playerPalette[i % _playerPalette.length],
                              letterSpacing: 0.5)),
                    ),
                ],
              ),
            ),
            for (final r in shown)
              _RoundRow(
                round: r,
                darts: byRound[r]!,
                playerCount: players.length,
                descending: descending,
              ),
            if (!_expanded && rounds.length > _collapsed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('VIS ALLE ${rounds.length} RUNDER ›',
                        style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 15,
                            color: DossedartTokens.cyan,
                            letterSpacing: 1)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow(
      {required this.round,
      required this.darts,
      required this.playerCount,
      required this.descending});
  final int round;
  final List<DartThrow> darts;
  final int playerCount;
  final bool descending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: DossedartTokens.magenta.withValues(alpha: 0.12)))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text('R$round',
                style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: Color(0x73FFFFFF),
                    height: 1.4)),
          ),
          for (var i = 0; i < playerCount; i++)
            Expanded(child: _PlayerTurn(
              darts: darts.where((d) => d.playerIndex == i).toList(),
              descending: descending,
            )),
        ],
      ),
    );
  }
}

class _PlayerTurn extends StatelessWidget {
  const _PlayerTurn({required this.darts, required this.descending});
  final List<DartThrow> darts;
  final bool descending;

  @override
  Widget build(BuildContext context) {
    if (darts.isEmpty) {
      return const Opacity(
        opacity: 0.25,
        child: Text('—',
            style: TextStyle(
                fontFamily: 'VT323', fontSize: 15, color: Color(0x66FFFFFF))),
      );
    }
    final total = darts.fold<int>(0, (s, d) => s + d.points);
    final is180 = total == 180;
    final remaining = descending ? darts.first.scoreAtStartOfTurn - total : null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [for (final d in darts) _ThrowChip(dart: d)],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text('$total',
                  style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 11,
                      color: is180 ? DossedartTokens.yellow : Colors.white)),
              if (remaining != null && remaining >= 0) ...[
                const SizedBox(width: 6),
                Text('$remaining igjen',
                    style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 13,
                        color: Color(0x99FFFFFF),
                        letterSpacing: 1)),
              ],
            ],
          ),
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
    final Color color;
    if (dart.isBust) {
      color = DossedartTokens.red;
    } else if (dart.segment == 0) {
      color = const Color(0x80FFFFFF);
    } else if (dart.multiplier == 3) {
      color = DossedartTokens.cyan;
    } else if (dart.multiplier == 2) {
      color = DossedartTokens.magenta;
    } else {
      color = const Color(0x80FFFFFF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration:
          BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.33))),
      child: Text(dart.shortLabel,
          style: TextStyle(
              fontFamily: 'VT323', fontSize: 16, color: color, letterSpacing: 0.5)),
    );
  }
}
