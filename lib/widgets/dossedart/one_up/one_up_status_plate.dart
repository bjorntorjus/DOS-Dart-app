import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dossedart_one_up_active_card.dart' show OneUpCardMode;

/// The A+ status plate — 1UP's dedicated state channel (fasit 2026-07-22).
/// ALWAYS rendered at the same height (rule 2); the card frame stays player
/// accent, so identity and state never share a channel.
class OneUpStatusPlate extends StatelessWidget {
  const OneUpStatusPlate({
    super.key,
    required this.mode,
    required this.target,
    required this.turnTotal,
    required this.dartsThrown,
    required this.survivor,
    this.hitSuggestion,
  });

  final OneUpCardMode mode;
  final int? target;
  final int turnTotal;
  final int dartsThrown; // 0..3
  final bool survivor;
  final String? hitSuggestion;

  @override
  Widget build(BuildContext context) {
    final left = 3 - dartsThrown;
    Color border = Colors.white.withValues(alpha: 0.14);
    Color bg = Colors.white.withValues(alpha: 0.04);
    List<Widget> inner;

    switch (mode) {
      case OneUpCardMode.free:
        border = DossedartTokens.lime.withValues(alpha: 0.53);
        bg = DossedartTokens.lime.withValues(alpha: 0.05);
        inner = [
          Text(
            survivor
                ? '▸ YOUR 3-DART TOTAL IS THE ROUND TARGET'
                : '▸ YOUR 3-DART TOTAL SETS THE BAR',
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 18,
              color: DossedartTokens.cyan,
              letterSpacing: 1,
            ),
          ),
        ];
      case OneUpCardMode.safe:
        border = DossedartTokens.green;
        bg = DossedartTokens.green.withValues(alpha: 0.11);
        inner = [
          Text(
            'SAFE ✓',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: DossedartTokens.green,
              letterSpacing: 1,
              shadows: [
                Shadow(color: DossedartTokens.green, blurRadius: 10),
              ],
            ),
          ),
          Text(
            survivor ? 'ROUND SURVIVED' : 'NEW TARGET $turnTotal',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ];
      case OneUpCardMode.cantBeat:
        border = DossedartTokens.red;
        bg = DossedartTokens.red.withValues(alpha: 0.10);
        inner = [
          Text(
            "CAN'T BEAT",
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: DossedartTokens.red,
              letterSpacing: 1,
              shadows: [
                Shadow(color: DossedartTokens.red, blurRadius: 8),
              ],
            ),
          ),
          Text(
            '· MAX ${60 * left} LEFT',
            // Fasit used off-token #ff8fa6; round outcome: red at reduced
            // opacity instead.
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 16,
              color: DossedartTokens.red.withValues(alpha: 0.6),
            ),
          ),
        ];
      case OneUpCardMode.normal:
        final need = target != null ? (target! - turnTotal).clamp(0, 999) : 0;
        inner = [
          Text(
            'NEED $need MORE',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: DossedartTokens.yellow,
              letterSpacing: 1,
              shadows: [
                Shadow(
                    color: DossedartTokens.yellow.withValues(alpha: 0.53),
                    blurRadius: 6),
              ],
            ),
          ),
          if (hitSuggestion != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '▶',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: DossedartTokens.green,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  hitSuggestion!,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: DossedartTokens.green,
                    letterSpacing: 1,
                    height: 1,
                    shadows: [
                      Shadow(
                          color:
                              DossedartTokens.green.withValues(alpha: 0.4),
                          blurRadius: 8),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              '· $left DART${left != 1 ? 'S' : ''} LEFT',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
        ];
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 2)),
      child: Row(
        children: [
          for (var i = 0; i < inner.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            inner[i],
          ],
        ],
      ),
    );
  }
}
