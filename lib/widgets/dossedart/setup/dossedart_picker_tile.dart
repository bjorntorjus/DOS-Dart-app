import 'package:flutter/material.dart';
import '../../../models/saved_player.dart';
import '../../../theme/dossedart_tokens.dart';
import '../../player_avatar.dart';

/// One tile in the picker grid.
///
/// Shows avatar (top-left), name (centered), `R nnnn` + 5 W/L pips,
/// and a P-slot badge (yellow, rotated) when selected.
class DossedartPickerTile extends StatelessWidget {
  const DossedartPickerTile({
    super.key,
    required this.player,
    required this.selected,
    this.slot,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedPlayer player;
  final bool selected;
  final int? slot;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent =
        selected ? DossedartTokens.yellow : DossedartTokens.magenta;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: selected ? 1.0 : 0.7,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x10FFD200)
                    : DossedartTokens.surface,
                border: Border.all(color: accent, width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PlayerAvatar(
                      avatarPath: player.avatarPath,
                      name: player.name,
                      radius: 16,
                      backgroundColor: DossedartTokens.bg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    player.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 23,
                      color: Colors.white,
                      letterSpacing: 1,
                      height: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'R ${player.rating.round()}',
                        style: const TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 17,
                          color: Colors.white70,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _formPips(accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (slot != null)
            Positioned(
              top: -8,
              right: -4,
              child: Transform.rotate(
                angle: 0.07,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  color: DossedartTokens.yellow,
                  child: Text(
                    'P$slot',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: DossedartTokens.bg,
                      letterSpacing: 1,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 5 placeholder W/L pips. Recent-results tracking isn't wired up yet
  /// (see project memory) — every pip renders as '?'.
  Widget _formPips(Color accent) {
    final pips = <Widget>[];
    for (var i = 0; i < 5; i++) {
      pips.add(_pip());
      if (i < 4) pips.add(const SizedBox(width: 4));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: pips);
  }

  Widget _pip() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        '?',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Colors.white30,
          height: 1,
        ),
      ),
    );
  }
}
