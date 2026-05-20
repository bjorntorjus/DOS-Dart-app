import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// DOSSEDART X01 cockpit action bar: ↶ UNDO · ✗ MISS · ⋯ MENU.
///
/// UNDO — magenta border, flex 1.
/// MISS — filled orange (primary), flex 2.
/// MENU — cyan border, flex 1.
class DossedartX01ActionBar extends StatelessWidget {
  const DossedartX01ActionBar({
    super.key,
    required this.onUndo,
    required this.onMiss,
    required this.onMenu,
  });

  final VoidCallback onUndo;
  final VoidCallback onMiss;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: DossedartTokens.yellow, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _Btn(
              label: '↶ UNDO',
              borderColor: DossedartTokens.magenta,
              fg: Colors.white,
              onTap: onUndo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _Btn(
              label: '✗ MISS',
              borderColor: Colors.white,
              bg: DossedartTokens.orange,
              fg: Colors.black,
              onTap: onMiss,
              glow: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _Btn(
              label: '⋯ MENU',
              borderColor: DossedartTokens.cyan,
              fg: DossedartTokens.cyan,
              onTap: onMenu,
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
    required this.borderColor,
    required this.fg,
    required this.onTap,
    this.bg,
    this.glow = false,
  });

  final String label;
  final Color borderColor;
  final Color fg;
  final VoidCallback onTap;
  final Color? bg;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: DossedartTokens.orange.withValues(alpha: 0.55),
                    blurRadius: 16,
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: fg,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
