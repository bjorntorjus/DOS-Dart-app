import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// DOSSEDART X01 cockpit top bar: ◀ EXIT · title · L n/m · RND r.
class DossedartX01TopBar extends StatelessWidget {
  const DossedartX01TopBar({
    super.key,
    required this.title,
    required this.legIndex,
    required this.legCount,
    required this.roundNumber,
    required this.onExit,
  });

  final String title;
  final int legIndex;
  final int legCount;
  final int roundNumber;
  final VoidCallback onExit;

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
          Text(
            'L $legIndex/$legCount · RND $roundNumber',
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
