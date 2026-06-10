import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';

/// Shared DOSSEDART cockpit top bar: ◀ EXIT · centered title · trailing.
///
/// Used by every game-mode cockpit so the chrome is identical across modes.
/// The [trailing] string (e.g. "RND 7", or "L 1/3 · RND 7" for a multi-leg
/// match) is composed by the screen — this widget stays mode-agnostic.
class DossedartTopBar extends StatelessWidget {
  const DossedartTopBar({
    super.key,
    required this.title,
    required this.onExit,
    this.trailing,
  });

  final String title;
  final VoidCallback onExit;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: DossedartTokens.magenta, width: 2),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onExit,
            child: const Text(
              '◀ EXIT',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.cyan,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 14,
                color: Colors.white54,
                letterSpacing: 2,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}
