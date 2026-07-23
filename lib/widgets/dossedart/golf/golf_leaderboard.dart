import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../overview/dossedart_standings_rail.dart' show midTruncate;
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
  /// the current playoff participant during sudden death). The active seat
  /// is called out via the row's accent tint + left bar only — v3 dropped
  /// the dedicated "THROWING" status text (KISS pass).
  final bool isActive;

  /// This-hole (or, in a playoff, this-target) stroke count, or null if the
  /// seat hasn't played it yet (shown as `·`). Ignored when [isActive],
  /// since an active seat is still throwing and hasn't recorded this hole.
  final int? holeStroke;
}

/// Full-width standalone leaderboard for the DOSSEDART Golf cockpit — a
/// calm, glow-free readout (only the input console registers score).
/// Rows are sorted by total ascending (current leader first, ties broken by
/// the order [entries] was given in, for deterministic rendering); the
/// leader's rank is yellow, the active row gets an accent left-bar + tint.
///
/// v3 KISS round (2026-07-23): fixed 56px rows, capped at 5 visible with an
/// internal scroll (6th row peeks as the scroll affordance) instead of
/// squeezing to fit every player; the per-row THROWING/TO PLAY status
/// column is gone — the this-hole column is now just the stroke chip or a
/// quiet `·` placeholder.
class GolfLeaderboard extends StatelessWidget {
  const GolfLeaderboard({
    super.key,
    required this.entries,
    required this.holeNumber,
    required this.playoff,
  });

  final List<GolfLeaderboardEntry> entries;

  /// Current hole number (1-based). Kept for API/call-site stability; v3's
  /// this-hole chip no longer labels itself with it (KISS pass).
  final int holeNumber;
  final bool playoff;

  static const double _headerHeight = 34;
  static const double _rowHeight = 56;
  static const int _maxVisibleRows = 5;
  static const double _maxHeight = _headerHeight + _rowHeight * _maxVisibleRows + 2;

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
    final visibleRows =
        ordered.length < _maxVisibleRows ? ordered.length : _maxVisibleRows;
    final scrollable = ordered.length > _maxVisibleRows;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        // Keyed so tests can measure the bordered board itself, excluding
        // the outer margin above (a plain `Container.margin` would still be
        // included in this widget's own render size — margin is the
        // outermost layer `Container.build()` produces).
        key: const Key('golfLeaderboardBoard'),
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        decoration: BoxDecoration(
          // Container auto-insets its child by the border's own thickness
          // (`BoxDecoration.padding` == `border.dimensions`), so a 1px
          // border is exactly the "+2" (top+bottom) slack baked into
          // `_maxHeight` — no separate padding needed.
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: DossedartTokens.borderThin,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LeaderboardHeader(playoff: playoff, playerCount: ordered.length),
            SizedBox(
              height: visibleRows * _rowHeight,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: scrollable
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < ordered.length; i++)
                    _LeaderboardRow(
                      rank: i + 1,
                      isLeader: i == 0,
                      isLast: i == ordered.length - 1,
                      entry: ordered[i],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({required this.playoff, required this.playerCount});

  final bool playoff;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final scrollHint = playerCount > GolfLeaderboard._maxVisibleRows;
    return Container(
      height: GolfLeaderboard._headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          Text(
            playoff ? 'PLAYOFF · TIED LEADERS' : 'LEADERBOARD',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              scrollHint ? '▼ $playerCount PLAYERS · SCROLL' : 'LOWEST WINS',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 16,
                color: scrollHint
                    ? DossedartTokens.yellow
                    : Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
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
    required this.entry,
  });

  final int rank;
  final bool isLeader;
  final bool isLast;
  final GolfLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GolfLeaderboard._rowHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              width: 30,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 15,
                  color: isLeader
                      ? DossedartTokens.yellow
                      : Colors.white.withValues(alpha: 0.4),
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
            const SizedBox(width: 8),
            Container(width: 10, height: 10, color: entry.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                midTruncate(entry.name.toUpperCase(), 16),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: entry.isActive ? entry.accent : Colors.white,
                  letterSpacing: 1,
                  shadows: entry.isActive
                      ? [
                          Shadow(
                            color: entry.accent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Center(child: _thisHoleChip()),
            ),
            SizedBox(
              width: 140,
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
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      vsParLabel(entry.vsPar),
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 15,
                        color: vsParColor(entry.vsPar),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thisHoleChip() {
    final stroke = entry.holeStroke;
    if (stroke == null) {
      return Text(
        '·',
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 17,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      );
    }
    final color = golfTermColor(stroke);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$stroke',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
