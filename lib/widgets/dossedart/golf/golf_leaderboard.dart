import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'golf_common.dart';

/// One player's row data for [GolfLeaderboard]. Built by the screen from
/// the [GolfEngine] each frame — the leaderboard is a live readout, not
/// tied to the hero's frozen 1s hole-result window.
class GolfLeaderboardEntry {
  const GolfLeaderboardEntry({
    required this.name,
    required this.accent,
    required this.total,
    required this.vsPar,
    required this.isActive,
    this.holeStroke,
  });

  final String name;
  final Color accent;
  final int total;
  final int vsPar;

  /// True for the seat currently throwing (`engine.currentPlayerIndex`, or
  /// the current playoff participant during sudden death).
  final bool isActive;

  /// This-hole (or, in a playoff, this-target) stroke count, or null if the
  /// seat hasn't played it yet. Ignored when [isActive].
  final int? holeStroke;
}

/// Full-width standalone leaderboard for the DOSSEDART Golf cockpit v2 — a
/// calm, glow-free readout (only the input console registers score).
/// Rows are sorted by total ascending (current leader first, ties broken by
/// the order [entries] was given in, for deterministic rendering); the
/// leader's rank is yellow, the active row gets an accent left-bar + tint.
///
/// Cockpit v2 layout round (2026-07-20): brings the standalone leaderboard
/// back full-width (QA #3) — replaces the old opponents-strip embedded in
/// `DossedartGolfActiveCard`.
class GolfLeaderboard extends StatelessWidget {
  const GolfLeaderboard({
    super.key,
    required this.entries,
    required this.holeNumber,
    required this.playoff,
  });

  final List<GolfLeaderboardEntry> entries;

  /// Current hole number (1-based) — used to label the this-hole stroke
  /// chip (`H<n>`).
  final int holeNumber;
  final bool playoff;

  List<GolfLeaderboardEntry> get _ordered {
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byTotal = a.$2.total.compareTo(b.$2.total);
        return byTotal != 0 ? byTotal : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  playoff ? 'PLAYOFF · TIED LEADERS' : 'LEADERBOARD',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'LOWEST STROKES WINS',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 13,
                      color: Colors.white38,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < ordered.length; i++)
            _LeaderboardRow(
              rank: i + 1,
              isLeader: i == 0,
              isLast: i == ordered.length - 1,
              holeNumber: holeNumber,
              entry: ordered[i],
            ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.isLeader,
    required this.isLast,
    required this.holeNumber,
    required this.entry,
  });

  final int rank;
  final bool isLeader;
  final bool isLast;
  final int holeNumber;
  final GolfLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isActive ? entry.accent.withValues(alpha: 0.08) : null,
        border: Border(
          left: BorderSide(
            color: entry.isActive ? entry.accent : Colors.transparent,
            width: 4,
          ),
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 13,
                color: isLeader ? DossedartTokens.yellow : Colors.white38,
                shadows: isLeader
                    ? [
                        Shadow(
                          color: DossedartTokens.yellow.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 13,
                color: entry.isActive ? entry.accent : Colors.white,
                letterSpacing: 1,
                shadows: entry.isActive
                    ? [Shadow(color: entry.accent.withValues(alpha: 0.5), blurRadius: 6)]
                    : null,
              ),
            ),
          ),
          SizedBox(
            width: 108,
            child: Align(alignment: Alignment.center, child: _thisHoleStatus()),
          ),
          SizedBox(
            width: 90,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.total}',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    vsParLabel(entry.vsPar),
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: vsParColor(entry.vsPar),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thisHoleStatus() {
    if (entry.isActive) {
      return Text(
        '▶ THROWING',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 9,
          color: entry.accent,
          letterSpacing: 0.5,
        ),
      );
    }
    final stroke = entry.holeStroke;
    if (stroke == null) {
      return const Text(
        '· TO PLAY',
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 14,
          color: Colors.white30,
          letterSpacing: 1,
        ),
      );
    }
    final color = golfTermColor(stroke);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          'H$holeNumber',
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: Colors.white38,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            '$stroke',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
