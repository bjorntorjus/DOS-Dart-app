import 'package:flutter/material.dart';

import '../../../theme/dossedart_tokens.dart';
import 'post_game_type.dart';

/// The 134 px pinned action bar: BACK / PLAY AGAIN / DETAILS on row 1, the
/// primary FINISH GAME full width on row 2 (design fasit 2026-08-10).
///
/// Two rules are load-bearing:
///  - It is a SIBLING of the scroll view, never its last item. The old screen
///    put the chart inside the list and floated the buttons under it, which is
///    how they could be pushed off a short frame.
///  - An unavailable button is rendered and dimmed, never removed, so the
///    primary action never moves between two games (grammar rule 2).
class DossedartPostGameActions extends StatelessWidget {
  const DossedartPostGameActions({
    super.key,
    required this.canUndo,
    required this.canPlayAgain,
    required this.canShowDetails,
    required this.onBack,
    required this.onPlayAgain,
    required this.onDetails,
    required this.onFinish,
  });

  final bool canUndo;
  final bool canPlayAgain;
  final bool canShowDetails;
  final VoidCallback onBack;
  final VoidCallback onPlayAgain;
  final VoidCallback onDetails;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 134,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border:
            Border(top: BorderSide(color: DossedartTokens.yellow, width: 2)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 100,
                  child: _Btn(
                      label: '↶ BACK',
                      color: DossedartTokens.magenta,
                      enabled: canUndo,
                      onTap: onBack),
                ),
                const SizedBox(width: 9),
                Expanded(
                  flex: 125,
                  child: _Btn(
                      label: '↻ PLAY AGAIN',
                      color: DossedartTokens.cyan,
                      enabled: canPlayAgain,
                      onTap: onPlayAgain),
                ),
                const SizedBox(width: 9),
                Expanded(
                  flex: 125,
                  child: _Btn(
                      label: '▶ DETAILS',
                      color: DossedartTokens.purple,
                      enabled: canShowDetails,
                      onTap: onDetails),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: _Btn(
              label: '✓ FINISH GAME',
              color: DossedartTokens.lime,
              enabled: true,
              primary: true,
              onTap: onFinish,
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: primary ? color : Colors.transparent,
        border: Border.all(color: primary ? Colors.white : color, width: 2),
        boxShadow: primary
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 18)]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: PostGameType.psStyle(
            primary ? 12 : 10,
            color: primary ? DossedartTokens.bg : color,
            letterSpacing: primary ? 2 : 1,
          ),
        ),
      ),
    );

    // Dimmed, not removed — and non-interactive while dimmed, so a disabled
    // action cannot be triggered by a stray tap on a visible target.
    if (!enabled) return Opacity(opacity: 0.28, child: body);
    return GestureDetector(onTap: onTap, child: body);
  }
}
