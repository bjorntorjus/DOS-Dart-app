import 'package:flutter/material.dart';

import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';
import 'post_game_type.dart';

/// The 196 px pinned winner zone: horizontal, not stacked (design fasit
/// 2026-08-10). A spotlight rather than a podium — the user's call: one
/// player is the answer to "who won", and second and third are already
/// legible in the standings right below.
class DossedartWinnerSpotlight extends StatelessWidget {
  const DossedartWinnerSpotlight({
    super.key,
    required this.name,
    required this.headlineLabel,
    required this.headlineValue,
    this.avatarPath,
    this.ratingChange,
    this.showElo = true,
  });

  final String name;
  final String headlineLabel;
  final String headlineValue;
  final String? avatarPath;
  final double? ratingChange;
  final bool showElo;

  @override
  Widget build(BuildContext context) {
    const yellow = DossedartTokens.yellow;
    final elo = showElo ? ratingChange : null;

    return Container(
      height: 196,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.52, -0.2),
          radius: 0.9,
          colors: [yellow.withValues(alpha: 0.12), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.27)),
        ),
      ),
      child: Row(
        children: [
          // The crown overhangs the avatar's top edge, so the stack is
          // allowed to paint outside its box.
          SizedBox(
            width: 104,
            height: 118,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                DossedartPlayerAvatar(
                  size: 104,
                  borderColor: yellow,
                  avatarPath: avatarPath,
                ),
                const Positioned(
                  top: 0,
                  child: Text('👑', style: TextStyle(fontSize: 26)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('★ WINNER ★',
                    style: PostGameType.psStyle(11,
                        color: yellow, letterSpacing: 4, glow: yellow)),
                const SizedBox(height: 12),
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PostGameType.psStyle(
                    PostGameType.spotlightName(name),
                    letterSpacing: 1.5,
                    glow: yellow,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$headlineLabel $headlineValue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PostGameType.vtStyle(19, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Plate(
                  label: headlineLabel, value: headlineValue, color: yellow),
              const SizedBox(height: 9),
              _Plate(
                label: 'ELO',
                value: elo == null
                    ? '—'
                    : '${elo > 0 ? '+' : ''}${elo.toStringAsFixed(1)}',
                color: elo == null
                    ? const Color(0xFF6A5F7A)
                    : elo < 0
                        ? DossedartTokens.red
                        : DossedartTokens.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PostGameType.vtStyle(15,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PostGameType.psStyle(18, color: color, glow: color)),
        ],
      ),
    );
  }
}
