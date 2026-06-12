import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';

/// Active player card shown in the DOSSEDART X01 cockpit.
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
    this.avg,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int remaining;
  final int currentDartIndex; // 0..3
  final String? lastTurnLabel; // e.g., 'T20 · S20 · S20' (null = no previous turn)
  final int? lastTurnSum;
  final String? checkoutTip;
  final double? avg;

  /// Formats the turn average for the narrow AVG column: at most 4 chars.
  /// If the 1-decimal form is longer ('180.0', or '100.0' from 99.95
  /// rounding up), drop the decimal so the PressStart2P text stays within
  /// the column instead of painting over the adjacent LAST label.
  static String _formatAvg(double avg) {
    final s = avg.toStringAsFixed(1);
    return s.length > 4 ? avg.toStringAsFixed(0) : s; // 99.95 -> '100'
  }

  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 18;
    if (len <= 10) return 15;
    if (len <= 16) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final nameSize = _nameFontSize();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: avatar + name + dart-dots
          Row(
            children: [
              DossedartPlayerAvatar(
                avatarPath: avatarPath,
                size: 56,
                borderColor: accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playerName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: nameSize,
                        color: Colors.white,
                        letterSpacing: nameSize >= 15 ? 2 : 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: i < currentDartIndex
                                  ? accentColor
                                  : Colors.transparent,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          'DART $currentDartIndex/3',
                          style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 13,
                            color: Colors.white54,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Row 2: REMAINING label + big number
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'REMAINING',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$remaining',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 60,
                  color: accentColor,
                  letterSpacing: 2,
                  height: 1,
                  shadows: [
                    Shadow(
                        color: accentColor.withValues(alpha: 0.7),
                        blurRadius: 16),
                  ],
                ),
              ),
            ],
          ),
          // Row 3: AVG + LAST — always rendered so the card height is constant
          // from the very first dart (placeholders before any data exists).
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: accentColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AVG',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          color: Colors.white60,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avg != null ? _formatAvg(avg!) : '–',
                        // Never wrap: a wrapped AVG value grows the card and
                        // shifts the board below. _formatAvg keeps values to
                        // at most 4 chars; those may still paint a few px
                        // past the 52px column instead.
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: avg != null
                              ? DossedartTokens.cyan
                              : Colors.white.withValues(alpha: 0.3),
                          letterSpacing: 1,
                          shadows: avg != null
                              ? [
                                  Shadow(
                                    color: DossedartTokens.cyan
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'LAST',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    lastTurnLabel ?? '— · — · —',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 20,
                      color: lastTurnLabel != null
                          ? DossedartTokens.yellow
                          : Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (lastTurnSum != null)
                  Text(
                    '= $lastTurnSum',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 13,
                      color: DossedartTokens.yellow,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
          // Row 4: checkout tip
          if (checkoutTip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: DossedartTokens.green.withValues(alpha: 0.06),
                // Spec calls for a dashed border; Flutter has no native dashed support, rendered solid.
                border: Border.all(color: DossedartTokens.green, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: DossedartTokens.green.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                '▶ $checkoutTip',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.green,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
