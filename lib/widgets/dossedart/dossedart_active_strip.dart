import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'dossedart_player_avatar.dart';

/// Shared active-player hero strip used by the Cricket/ATC/Splitscore/Shanghai
/// cockpits (X01 uses the larger DossedartX01ActiveCard). One source so the
/// chrome cannot drift between modes.
///
/// Layout: avatar · name + "DART n / 3" · dart dots + "LAST · <label>" ·
/// mode-specific trailing stat (points, target, lives...).
class DossedartActiveStrip extends StatelessWidget {
  const DossedartActiveStrip({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.dartsInTurn,
    this.lastThrowLabel,
    this.trailing,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;

  /// Darts already thrown this turn (0..3).
  final int dartsInTurn;

  /// Label for the most recent throw; shows an em dash when null.
  final String? lastThrowLabel;

  /// Mode-specific stat shown at the right edge (points, target, lives...).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.12), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: c, width: 3)),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.27), blurRadius: 18)],
      ),
      child: Row(
        children: [
          DossedartPlayerAvatar(size: 52, borderColor: c, avatarPath: avatarPath),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '▶ ${playerName.toUpperCase()}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 13,
                          color: c,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      'DART ${dartsInTurn + 1} / 3',
                      style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _DartDots(filled: dartsInTurn, color: c),
                    const SizedBox(width: 10),
                    Text(
                      'LAST · ',
                      style: TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 2,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        lastThrowLabel ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: DossedartTokens.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Three turn-progress dots; filled dots are solid, no glow (the glow Cricket
/// once carried was copy-paste drift, not canon).
class _DartDots extends StatelessWidget {
  const _DartDots({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}
