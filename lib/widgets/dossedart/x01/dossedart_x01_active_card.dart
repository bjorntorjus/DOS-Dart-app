import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../overview/dossedart_overview_header.dart';
import '../overview/dossedart_standings_rail.dart';

/// One row of X01 standings data; the card sorts and ranks internally.
class X01Standing {
  const X01Standing({
    required this.name,
    required this.accent,
    required this.remaining,
    this.isActive = false,
  });

  final String name;
  final Color accent;
  final int remaining;
  final bool isActive;
}

/// X01 overview card — rail-B fasit (design_handoff_x01_overview,
/// approved 2026-07-22). Fixed 250px card in a 272px zone (margins 12/10):
/// grammar header + REMAINING 60px · left column LAST / AVG+HIT% / CHECKOUT
/// (always rendered, dim 0.34 when empty) · 300px standings rail with the
/// TO WIN delta. This card is the template the other cockpits restyle onto.
class DossedartX01ActiveCard extends StatelessWidget {
  const DossedartX01ActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.remaining,
    required this.currentDartIndex,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.checkoutTip,
    required this.standings,
    this.avg,
    this.hitPercent,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int remaining;
  final int currentDartIndex; // darts thrown this turn, 0..3
  final String? lastTurnLabel;
  final int? lastTurnSum;
  final String? checkoutTip;
  final double? avg;
  final int? hitPercent; // 0-100; share of this leg's darts on the board
  final List<X01Standing> standings;

  static String _formatAvg(double avg) {
    final s = avg.toStringAsFixed(1);
    return s.length > 4 ? avg.toStringAsFixed(0) : s;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...standings]..sort((a, b) => a.remaining.compareTo(b.remaining));
    final lead = sorted.first.remaining;
    final uniqueLeader =
        sorted.where((s) => s.remaining == lead).length == 1;
    final active = sorted.firstWhere((s) => s.isActive, orElse: () => sorted.first);
    final delta = active.remaining - lead;
    final toWin = delta == 0
        ? (uniqueLeader ? 'YOU LEAD' : 'TIED')
        : '▲ $delta';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      height: 250,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: accentColor, width: 3),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DossedartOverviewHeader(
            playerName: playerName,
            avatarPath: avatarPath,
            accent: accentColor,
            dartsThrown: currentDartIndex,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REMAINING',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$remaining',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 60,
                    color: accentColor,
                    height: 1,
                    letterSpacing: -2,
                    shadows: [
                      Shadow(
                          color: accentColor.withValues(alpha: 0.66),
                          blurRadius: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // flex:37 vs. the rail's flex:25 below reproduces the exact
                // 444/300 tablet split (both sides tuned against the 758px
                // row width — 820px card minus margin/padding/border — at
                // the 820px fasit) — see the rail's comment.
                Expanded(
                  flex: 37,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _helperRow(
                        label: 'LAST',
                        value: lastTurnLabel != null
                            ? '$lastTurnLabel  = ${lastTurnSum ?? 0}'
                            : '— · — · —',
                        color: DossedartTokens.yellow,
                        dim: lastTurnLabel == null,
                      ),
                      _helperRow(
                        label: 'AVG',
                        value: avg != null ? _formatAvg(avg!) : '—',
                        color: Colors.white,
                        dim: avg == null,
                        extraLabel: 'HIT%',
                        extraValue: hitPercent != null ? '$hitPercent%' : '—',
                        extraColor: DossedartTokens.cyan,
                        extraDim: hitPercent == null,
                      ),
                      _helperRow(
                        label: 'CHECKOUT',
                        value: checkoutTip != null ? '▶ $checkoutTip' : '— — —',
                        color: DossedartTokens.green,
                        dim: checkoutTip == null,
                        mono: checkoutTip != null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Below tablet width the rail can no longer claim its full
                // 300px unconditionally: Flexible lets it shrink under
                // squeeze while the ConstrainedBox pins the max so the
                // 820px look is unchanged (same idiom as
                // DossedartActiveStrip's modeSlot, db085a9). flex:25 (vs.
                // the left column's flex:37) is tuned so the allocated
                // share is exactly 300 at the 820px fasit width — no
                // wasted allocation, no gap before the card's right edge.
                Flexible(
                  flex: 25,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: DossedartStandingsRail.width),
                    child: DossedartStandingsRail(
                      entries: [
                        for (final s in sorted)
                          DossedartRailEntry(
                            name: s.name,
                            accent: s.accent,
                            value: '${s.remaining}',
                            isActive: s.isActive,
                            isLeader: uniqueLeader && s.remaining == lead,
                          ),
                      ],
                      bottomLabel: 'TO WIN',
                      bottomValue: toWin,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One oche-legible helper row: label PS-9 + value VT-26 (fasit), dimmed
  /// to 0.34 with a placeholder when empty — always rendered (rule 2).
  Widget _helperRow({
    required String label,
    required String value,
    required Color color,
    required bool dim,
    bool mono = false,
    String? extraLabel,
    String? extraValue,
    Color? extraColor,
    bool extraDim = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
          ),
          Flexible(
            child: Opacity(
              opacity: dim ? 0.34 : 1,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: mono && !dim ? 'PressStart2P' : 'VT323',
                  fontSize: mono && !dim ? 14 : 26,
                  height: 1,
                  letterSpacing: 1,
                  color: dim ? Colors.white : color,
                  shadows: dim
                      ? null
                      : [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
                ),
              ),
            ),
          ),
          if (extraLabel != null) ...[
            const SizedBox(width: 22),
            // The HIT% pair squeezes as a unit at phone width (Flexible +
            // ellipsis on both texts) rather than forcing its fixed
            // natural width, matching the LAST/AVG/CHECKOUT value's own
            // ellipsis handling above.
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      extraLabel,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Opacity(
                      opacity: extraDim ? 0.34 : 1,
                      child: Text(
                        extraValue ?? '—',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 26,
                          height: 1,
                          letterSpacing: 1,
                          color: extraDim ? Colors.white : (extraColor ?? Colors.white),
                          shadows: extraDim || extraColor == null
                              ? null
                              : [Shadow(color: extraColor.withValues(alpha: 0.4), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
