import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'golf_common.dart' show golfTermColor;

/// THE score-registering console for the DOSSEDART Golf cockpit v2 — the
/// ONE loud, glowing, obviously-tappable surface in the cockpit (hero,
/// leaderboard and scorecard strip are calm, glow-free readouts; only these
/// cells register a stroke). A labelled header names the console
/// explicitly and states the current target; three term-coloured cells
/// (two in a Bull sudden-death playoff) show the term + stroke count each
/// would score.
///
/// Cockpit v2 layout round (2026-07-20): same constructor contract as v1
/// (`targetNumber`/`onHit`/`enabled`) — only the surrounding chrome and the
/// Bull cell labels changed (`25`/`50`, matching the dartboard segment
/// values, instead of `BULL`/`D-BULL` — copy delta, term math unchanged).
///
/// Console v4 (2026-08-07 QA): back to hits only. The console's own `✗`
/// cell (v3) is gone — `DossedartActionBar`'s miss button is the single
/// miss entry point again, matching every sibling cockpit. The PAR/BIRDIE/
/// ACE sub-labels are gone too: the cells read as plain `S7`/`D7`/`T7`
/// (`25`/`50` on Bull), same grammar as the other modes' score input. Cell
/// colours still carry the term.
class GolfInputCells extends StatelessWidget {
  const GolfInputCells({
    super.key,
    required this.targetNumber,
    required this.onHit,
    this.enabled = true,
  });

  /// 1-20, or 25 for Bull.
  final int targetNumber;

  /// Multiplier hit: 1 = single, 2 = double, 3 = triple.
  final void Function(int multiplier) onHit;

  final bool enabled;

  bool get _isBull => targetNumber == 25;

  List<_CellSpec> get _cells => _isBull
      ? [
          _CellSpec(label: '25', multiplier: 1, color: golfTermColor(3)),
          _CellSpec(label: '50', multiplier: 2, color: golfTermColor(2)),
        ]
      : [
          _CellSpec(
            label: 'S$targetNumber',
            multiplier: 1,
            color: golfTermColor(3),
          ),
          _CellSpec(
            label: 'D$targetNumber',
            multiplier: 2,
            color: golfTermColor(2),
          ),
          _CellSpec(
            label: 'T$targetNumber',
            multiplier: 3,
            color: golfTermColor(1),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SizedBox(
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              color: DossedartTokens.green.withValues(alpha: 0.03),
              border: Border.all(color: DossedartTokens.green, width: 3),
              boxShadow: [
                BoxShadow(
                  color: DossedartTokens.green.withValues(alpha: 0.28),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: DossedartTokens.green.withValues(alpha: 0.11),
                    border: Border(
                      bottom: BorderSide(
                        color: DossedartTokens.green.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  // Wrap-proof (fix 2, cockpit v2 layout round): the pair must
                  // never break to two lines at narrow widths — scale the row
                  // down as a unit rather than letting it wrap.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '▼ TAP TO SCORE',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: DossedartTokens.green,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: DossedartTokens.green.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· THROW AT ${_isBull ? 'BULL' : targetNumber}',
                          style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 16,
                            color: Colors.white60,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        for (final cell in _cells)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _InputCell(spec: cell, onHit: onHit),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CellSpec {
  const _CellSpec({
    required this.label,
    required this.multiplier,
    required this.color,
  });

  final String label;
  final int multiplier;

  /// Term colour for the cell chrome — the term NAME is no longer written
  /// out (console v4), only carried by this colour.
  final Color color;
}

class _InputCell extends StatelessWidget {
  const _InputCell({required this.spec, required this.onHit});

  final _CellSpec spec;
  final void Function(int multiplier) onHit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onHit(spec.multiplier),
      child: Container(
        // 24, not the v3 16: with the term sub-label gone the padding is
        // what keeps the cell (and so the tap target) the same height it
        // had when the label/term pair set it.
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: spec.color.withValues(alpha: 0.09),
          border: Border.all(color: spec.color, width: 3),
          boxShadow: [
            BoxShadow(
              color: spec.color.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
          ],
        ),
        // Below tablet width the cell's own label no longer fits its natural
        // size — FittedBox scales it down (same wrap-proof idiom as the
        // console header above) instead of the Text wrapping to a 2nd line
        // and blowing out the console's fixed 220px height.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            spec.label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 20,
              color: spec.color,
              shadows: [
                Shadow(
                  color: spec.color.withValues(alpha: 0.7),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
