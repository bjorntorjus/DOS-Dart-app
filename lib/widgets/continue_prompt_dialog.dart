import 'package:flutter/material.dart';

import '../theme/dossedart_tokens.dart';

/// Modal "keep playing or end?" prompt, shown on the GAME screen when a player
/// finishes while others can still play for the places (X01, Cricket, ATC).
/// The result screen never carries this choice — it is always final.
///
/// Returns true = keep playing (also on barrier dismiss, the safe default),
/// false = end the game now.
Future<bool> showContinuePrompt(
  BuildContext context, {
  required String finisherName,
  required int remainingCount,
  required bool dossedart,
  String finishVerb = 'FINISHED',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => dossedart
        ? _DossedartContinuePrompt(
            finisherName: finisherName,
            remainingCount: remainingCount,
            finishVerb: finishVerb,
          )
        : AlertDialog(
            title: Text('$finisherName ${finishVerb.toLowerCase()}!'),
            content: Text(remainingCount == 1
                ? '1 player can still play for the places.'
                : '$remainingCount players can still play for the places.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('End game'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Keep playing'),
              ),
            ],
          ),
  );
  return result ?? true;
}

class _DossedartContinuePrompt extends StatelessWidget {
  const _DossedartContinuePrompt({
    required this.finisherName,
    required this.remainingCount,
    required this.finishVerb,
  });

  final String finisherName;
  final int remainingCount;
  final String finishVerb;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        decoration: BoxDecoration(
          color: DossedartTokens.bg,
          border: Border.all(color: DossedartTokens.lime, width: 3),
          boxShadow: [
            BoxShadow(
              color: DossedartTokens.lime.withValues(alpha: 0.4),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★ ${finisherName.toUpperCase()} $finishVerb ★',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: DossedartTokens.lime,
                letterSpacing: 2,
                height: 1.4,
                shadows: [Shadow(color: DossedartTokens.lime, blurRadius: 12)],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              remainingCount == 1
                  ? '1 PLAYER CAN STILL PLAY FOR THE PLACES'
                  : '$remainingCount PLAYERS CAN STILL PLAY FOR THE PLACES',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PromptButton(
                    label: 'KEEP PLAYING',
                    color: DossedartTokens.lime,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PromptButton(
                    label: 'END GAME',
                    color: DossedartTokens.magenta,
                    primary: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Same visual grammar as the post-game action bar's buttons: primary is
/// filled with a glow, secondary is a 2px outline.
class _PromptButton extends StatelessWidget {
  const _PromptButton({
    required this.label,
    required this.color,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
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
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: primary ? DossedartTokens.bg : color,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
