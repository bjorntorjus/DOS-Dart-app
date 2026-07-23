import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'overview/dossedart_overview_header.dart';

/// Generic mode-data block for the family strip: label + big value + sub-line,
/// left hairline, fixed width so the strip never reflows between states.
class DossedartStripSlot extends StatelessWidget {
  const DossedartStripSlot({
    super.key,
    required this.label,
    required this.value,
    required this.subLine,
    this.valueColor = DossedartTokens.yellow,
    this.subLineColor,
    this.dim = false,
    this.width = 212,
  });

  /// e.g. 'LAST TURN', 'TARGET', 'ROUND 4'.
  final String label;

  /// Big line, VT323 26.
  final String value;

  /// Small line, VT323 14.
  final String subLine;

  final Color valueColor;

  /// Defaults to white-0.5.
  final Color? subLineColor;

  /// 0.34 opacity (rule 2 placeholder state).
  final bool dim;

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: Opacity(
        opacity: dim ? 0.34 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 26,
                    height: 1,
                    letterSpacing: 1.5,
                    color: valueColor,
                    shadows: dim
                        ? null
                        : [
                            Shadow(
                                color: valueColor.withValues(alpha: 0.33),
                                blurRadius: 8)
                          ])),
            const SizedBox(height: 3),
            Text(subLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 14,
                    height: 1,
                    letterSpacing: 1,
                    color: subLineColor ?? Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}

/// Shared active-player hero strip used by the Cricket/ATC/Splitscore/Shanghai
/// cockpits (X01 uses the larger DossedartX01ActiveCard). One source so the
/// chrome cannot drift between modes.
///
/// Fixed 132px zone. Anatomy: [DossedartOverviewHeader] (avatar + name +
/// pips + dart counter) · mode-specific [modeSlot] · score block (label +
/// big accent-colored value).
class DossedartActiveStrip extends StatelessWidget {
  const DossedartActiveStrip({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.dartsInTurn,
    required this.modeSlot,
    required this.scoreLabel,
    required this.scoreValue,
    this.smallScore = false,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;

  /// Darts already thrown this turn (0..3).
  final int dartsInTurn;

  /// Mode-specific data block (last turn, target, round...).
  final Widget modeSlot;

  /// 'POINTS' / 'PROGRESS' / 'TOTAL' / 'TARGET'.
  final String scoreLabel;
  final String scoreValue;

  /// PS-22 instead of PS-30, for long values.
  final bool smallScore;

  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return SizedBox(
      height: 132,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: DossedartTokens.surface,
          border: Border.all(color: c, width: 3),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 14)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DossedartOverviewHeader(
                playerName: playerName,
                avatarPath: avatarPath,
                accent: c,
                dartsThrown: dartsInTurn,
              ),
            ),
            const SizedBox(width: 14),
            modeSlot,
            Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(scoreLabel,
                      style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 7,
                          color: Colors.white.withValues(alpha: 0.45),
                          letterSpacing: 1)),
                  const SizedBox(height: 5),
                  Text(scoreValue,
                      style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: smallScore ? 22 : 30,
                          color: c,
                          shadows: [
                            Shadow(
                                color: c.withValues(alpha: 0.5),
                                blurRadius: 12)
                          ])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
