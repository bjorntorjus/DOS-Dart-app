import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';

/// Which stage of the current hole the [DossedartGolfActiveCard] is
/// showing for the active player.
enum GolfCardPhase {
  /// First dart of the hole not thrown yet.
  teeOff,

  /// At least one miss recorded, hole still open.
  midHole,

  /// Hole just finished at par or better (≤ 3 strokes).
  holeDoneGood,

  /// Hole just finished at bogey or worse (≥ 4 strokes).
  holeDoneBad,
}

/// One opponent's compact tile in the [DossedartGolfActiveCard]'s
/// opponents strip.
class GolfOpponentEntry {
  const GolfOpponentEntry({
    required this.name,
    required this.total,
    required this.vsPar,
    required this.doneThisHole,
    required this.accent,
  });

  final String name;
  final int total;
  final int vsPar;
  final bool doneThisHole;
  final Color accent;
}

/// 'E' for even, otherwise '+n' / '-n'.
String vsParLabel(int vsPar) =>
    vsPar == 0 ? 'E' : (vsPar > 0 ? '+$vsPar' : '$vsPar');

/// Scorecard/term colour for a hole score (also used by Task 5's
/// scorecard sheet).
Color golfTermColor(int strokes) => switch (strokes) {
      1 => DossedartTokens.cyan,
      2 => DossedartTokens.green,
      3 => DossedartTokens.phosphor,
      4 => DossedartTokens.orange,
      _ => DossedartTokens.red,
    };

/// Colour for a vs-par delta: under par reads as an advantage (green),
/// over par as a warning (orange), even as neutral phosphor.
Color _vsParColor(int vsPar) {
  if (vsPar < 0) return DossedartTokens.green;
  if (vsPar > 0) return DossedartTokens.orange;
  return DossedartTokens.phosphor;
}

/// Active player card for the DOSSEDART Golf cockpit.
///
/// Shows the hole context (label + dart pips), the running total with its
/// vs-par delta, a status line describing the current lie/result, the
/// finished-hole term when a hole just ended, and a strip of every
/// opponent's total/vs-par + whether they've already played this hole.
class DossedartGolfActiveCard extends StatelessWidget {
  const DossedartGolfActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.holeLabel,
    required this.dartsThrown,
    required this.total,
    required this.vsPar,
    required this.phase,
    required this.statusLine,
    this.holeStrokes,
    required this.opponents,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;

  /// e.g. 'HOLE 7 · PAR 3' / 'SUDDEN DEATH · 19'.
  final String holeLabel;

  /// 0-3 darts thrown so far this hole.
  final int dartsThrown;

  final int total;
  final int vsPar;
  final GolfCardPhase phase;
  final String statusLine;

  /// 1-6 when [phase] is one of the holeDone* phases.
  final int? holeStrokes;

  final List<GolfOpponentEntry> opponents;

  /// Same downscaling curve as the sibling active cards' `_nameFontSize`.
  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 15;
    if (len <= 10) return 12;
    if (len <= 16) return 10;
    return 9;
  }

  Color get _frameColor => switch (phase) {
        GolfCardPhase.holeDoneGood => DossedartTokens.green,
        GolfCardPhase.holeDoneBad => DossedartTokens.red,
        GolfCardPhase.teeOff || GolfCardPhase.midHole => accentColor,
      };

  @override
  Widget build(BuildContext context) {
    final frame = _frameColor;
    final nameSize = _nameFontSize();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  frame.withValues(alpha: 0.11),
                  frame.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(color: frame, width: 3),
              boxShadow: [
                BoxShadow(color: frame.withValues(alpha: 0.33), blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DossedartPlayerAvatar(
                      avatarPath: avatarPath,
                      size: 40,
                      borderColor: accentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            playerName.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: nameSize,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  holeLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'VT323',
                                    fontSize: 15,
                                    color: Colors.white70,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              for (var i = 0; i < 3; i++) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i < dartsThrown
                                        ? accentColor
                                        : Colors.transparent,
                                    border:
                                        Border.all(color: accentColor, width: 2),
                                  ),
                                ),
                                if (i < 2) const SizedBox(width: 4),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$total',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 30,
                                color: frame,
                                height: 1,
                                letterSpacing: -1,
                                shadows: [
                                  Shadow(
                                    color: frame.withValues(alpha: 0.67),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              vsParLabel(vsPar),
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 13,
                                color: _vsParColor(vsPar),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _buildStatusLine(frame),
                if (opponents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _OpponentsStrip(opponents: opponents),
                ],
              ],
            ),
          ),
          Positioned(
            top: -9,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: frame,
                boxShadow: [
                  BoxShadow(color: frame.withValues(alpha: 0.67), blurRadius: 8),
                ],
              ),
              child: Text(
                '▶ NOW THROWING',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: DossedartTokens.bg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine(Color frame) {
    final strokes = holeStrokes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: frame.withValues(alpha: 0.09),
        border: Border.all(color: frame, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              statusLine,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: frame,
                letterSpacing: 1,
                shadows: [Shadow(color: frame.withValues(alpha: 0.53), blurRadius: 6)],
              ),
            ),
          ),
          if (strokes != null) ...[
            const SizedBox(width: 8),
            Text(
              golfTerm(strokes),
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: golfTermColor(strokes),
                letterSpacing: 1,
                shadows: [
                  Shadow(color: golfTermColor(strokes), blurRadius: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact opponent tiles: name, total + vs-par chip, and a checkmark once
/// the opponent has already played this hole.
class _OpponentsStrip extends StatelessWidget {
  const _OpponentsStrip({required this.opponents});

  final List<GolfOpponentEntry> opponents;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in opponents) ...[
            _OpponentTile(entry: o),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  const _OpponentTile({required this.entry});

  final GolfOpponentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: entry.accent.withValues(alpha: 0.05),
        border: Border.all(color: entry.accent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  entry.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (entry.doneThisHole)
                Text(
                  '✓',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: DossedartTokens.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Wide values (e.g. total 108, vsPar +27) would otherwise overflow
          // the tile's ~62px content budget — FittedBox scales the pair down
          // as a unit rather than ellipsizing a digit out of either number.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.total}',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 13,
                    color: entry.accent,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  vsParLabel(entry.vsPar),
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: _vsParColor(entry.vsPar),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
