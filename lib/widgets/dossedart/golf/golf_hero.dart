import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart' show golfTerm;
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';
import 'golf_common.dart';

/// Hero target block for the DOSSEDART Golf cockpit v2 — "what do I throw
/// at + what's happening", answerable from the oche. The hole/target number
/// is the one big glowing element (the aim signal); everything else here is
/// a calm, non-glowing readout — until a hole just finished, when the whole
/// frame takes the term colour + glow for the screen's 1s result window.
///
/// Cockpit v2 layout round (2026-07-20): replaces `DossedartGolfActiveCard`.
/// Pure display — no rule logic. [holeStrokes]/[nextPlayerName] non-null
/// only during the screen's `_lastHole*`-driven 1s result window; the
/// screen is responsible for freezing [playerName]/[avatarPath]/
/// [accentColor]/[targetNumber]/[playoff] to the FINISHING player's values
/// for that same window (see golf_game_screen.dart's `_holeTarget`).
class GolfHero extends StatelessWidget {
  const GolfHero({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.targetNumber,
    required this.playoff,
    required this.dartsThrown,
    required this.total,
    required this.vsPar,
    this.holeStrokes,
    this.nextPlayerName,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;

  /// 1-20 in regulation, or the playoff target (19/20/25 — 25 = Bull).
  final int targetNumber;
  final bool playoff;

  /// 0-3 darts/misses thrown so far this hole.
  final int dartsThrown;

  final int total;
  final int vsPar;

  /// 1-6 during the 1s hole-result window, null otherwise.
  final int? holeStrokes;

  /// Who throws next — set only during the hole-result window.
  final String? nextPlayerName;

  bool get _isResult => holeStrokes != null;
  bool get _isBull => playoff && targetNumber == 25;

  @override
  Widget build(BuildContext context) {
    final term = _isResult ? golfTermColor(holeStrokes!) : null;
    final frameColor = term ?? Colors.white.withValues(alpha: 0.16);
    final badgeColor = term ?? accentColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: term != null
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        term.withValues(alpha: 0.14),
                        term.withValues(alpha: 0.02),
                      ],
                    )
                  : null,
              color: term == null ? Colors.white.withValues(alpha: 0.02) : null,
              border: Border.all(color: frameColor, width: 2),
              boxShadow: term != null
                  ? [BoxShadow(color: term.withValues(alpha: 0.4), blurRadius: 22)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DossedartPlayerAvatar(
                      avatarPath: avatarPath,
                      size: 38,
                      borderColor: accentColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        playerName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 8,
                            color: Colors.white38,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 20,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              vsParLabel(vsPar),
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 12,
                                color: vsParColor(vsPar),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          playoff ? 'PLAYOFF' : 'HOLE',
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
                            fontSize: _isBull ? 56 : 84,
                            color: DossedartTokens.green,
                            height: 0.95,
                            letterSpacing: -2,
                            shadows: [
                              Shadow(
                                color: DossedartTokens.green
                                    .withValues(alpha: 0.75),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PAR 3',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: i < dartsThrown
                                        ? accentColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: i < dartsThrown
                                          ? accentColor
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                if (i < 2) const SizedBox(width: 6),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                '$dartsThrown/3 DARTS',
                                style: const TextStyle(
                                  fontFamily: 'VT323',
                                  fontSize: 15,
                                  color: Colors.white54,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statusBar(),
              ],
            ),
          ),
          Positioned(
            top: -9,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                boxShadow: [
                  BoxShadow(color: badgeColor.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
              child: Text(
                _isResult ? '▣ HOLE RESULT' : '▶ NOW THROWING',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: DossedartTokens.bg,
                ),
              ),
            ),
          ),
          if (_isResult)
            Positioned(
              left: 16,
              right: 16,
              bottom: 4,
              child: Container(
                height: 4,
                color: Colors.white.withValues(alpha: 0.08),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(color: golfTermColor(holeStrokes!)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The "press-your-luck heartbeat": tee-off prompt, mid-hole lying count +
  /// darts-left countdown (yellow), or — during the result window — the
  /// finished hole's term + who throws next.
  Widget _statusBar() {
    if (!_isResult && dartsThrown == 0) {
      return _statusFrame(
        color: Colors.white.withValues(alpha: 0.16),
        child: const Text(
          '▸ TEE OFF · 3 DARTS',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 20,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      );
    }
    if (!_isResult) {
      final left = 3 - dartsThrown;
      return _statusFrame(
        color: Colors.white.withValues(alpha: 0.16),
        child: Row(
          children: [
            Text(
              'LYING $dartsThrown',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 13,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              '$left DART${left == 1 ? '' : 'S'} LEFT',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: DossedartTokens.yellow,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: DossedartTokens.yellow.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final strokes = holeStrokes!;
    final color = golfTermColor(strokes);
    return _statusFrame(
      color: color,
      child: Row(
        children: [
          Text(
            'LYING $strokes',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            golfTerm(strokes),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: color,
              letterSpacing: 1,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
          const Spacer(),
          if (nextPlayerName != null)
            Flexible(
              child: Text(
                'NEXT ▸ ${nextPlayerName!}',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusFrame({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color, width: 2),
      ),
      child: child,
    );
  }
}
