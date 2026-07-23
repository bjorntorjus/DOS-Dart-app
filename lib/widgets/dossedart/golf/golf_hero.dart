import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';
import 'golf_status_plate.dart';

/// Hero target block for the DOSSEDART Golf cockpit — "what do I throw
/// at + what's happening", answerable from the oche in one glance. The
/// hole/target number is the one big glowing element (the aim signal);
/// everything else is a calm readout, except the bottom [GolfStatusPlate]
/// which takes the term colour during the 1s hole-result window.
///
/// Hero v3 layout round (2026-07-22, KISS pass): fixed 244px tall in every
/// state — no more TOTAL block, no more NOW THROWING/HOLE RESULT corner
/// badge. Per-dart zone chips (from `golf_game_screen.dart`'s
/// `holeDartLabels`) replace the old plain dart-count pips, surfaced via
/// the [GolfStatusPlate] at the bottom. Pure display — no rule logic; the
/// screen is responsible for freezing [playerName]/[avatarPath]/
/// [accentColor]/[targetNumber]/[playoff] to the FINISHING player's values
/// during the result window (see golf_game_screen.dart's `_holeTarget`).
class GolfHero extends StatelessWidget {
  const GolfHero({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.targetNumber,
    required this.playoff,
    required this.dartLabels,
    required this.plateMode,
    this.lie,
    this.wash = false,
    this.nextPlayerName,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;

  /// 1-20 in regulation, or the playoff target (19/20/25 — 25 = Bull).
  final int targetNumber;
  final bool playoff;

  /// 0-3 per-dart zone labels for the displayed hole, in throw order
  /// ('S7'/'D7'/'T7'/'25'/'50'/'✗') — frozen to the finished hole's darts
  /// during the result window, live misses-so-far otherwise.
  final List<String> dartLabels;

  final GolfPlateMode plateMode;

  /// Mid-hole: misses so far this hole. Result: the finished hole's
  /// stroke count. Unused in tee-off mode.
  final int? lie;

  /// Result mode only — true when the hole washed (3 misses, max stroke).
  final bool wash;

  /// Who throws next — result mode only.
  final String? nextPlayerName;

  bool get _isBull => playoff && targetNumber == 25;

  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 18;
    if (len <= 10) return 15;
    if (len <= 16) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final nameSize = _nameFontSize();
    return SizedBox(
      height: 244,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: accentColor, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DossedartPlayerAvatar(
                    avatarPath: avatarPath,
                    size: 56,
                    borderColor: accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          playerName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: nameSize,
                            color: Colors.white,
                            letterSpacing: nameSize >= 15 ? 2 : 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: i < dartLabels.length
                                      ? accentColor
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: accentColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                'DART ${min(dartLabels.length + 1, 3)}/3',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'VT323',
                                  fontSize: 13,
                                  color: Colors.white54,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playoff ? 'PLAYOFF' : 'HOLE · PAR 3',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: Colors.white54,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        _isBull ? 'BULL' : '$targetNumber',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          // The hole number is the aim signal and must read
                          // from the throw line — v3 pins it at 120px (BULL
                          // scaled proportionally, matching the prior
                          // 86/130 ratio).
                          fontSize: _isBull ? 58 : 120,
                          color: DossedartTokens.green,
                          height: 0.85,
                          letterSpacing: _isBull ? 0 : -4,
                          shadows: [
                            Shadow(
                              color: DossedartTokens.green.withValues(
                                alpha: 0.75,
                              ),
                              blurRadius: 30,
                            ),
                            const Shadow(
                              color: Color.fromRGBO(0, 0, 0, 0.55),
                              offset: Offset(5, 5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GolfStatusPlate(
              mode: plateMode,
              dartLabels: dartLabels,
              lie: lie,
              wash: wash,
              nextPlayerName: nextPlayerName,
            ),
          ],
        ),
      ),
    );
  }
}
