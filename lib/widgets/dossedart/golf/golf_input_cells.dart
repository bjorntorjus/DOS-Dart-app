import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart';
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
/// Console v3 (2026-07-23): the console gains its own `✗` cell — misses are
/// now registered from the SAME surface as hits instead of only via
/// `DossedartActionBar`'s separate miss button (that button stays, this is
/// an approved duplicate entry point). The footer caption explaining the
/// miss cost is gone — the cost is stated on the cell itself now.
class GolfInputCells extends StatelessWidget {
  const GolfInputCells({
    super.key,
    required this.targetNumber,
    required this.onHit,
    required this.onMiss,
    this.playoff = false,
    this.enabled = true,
  });

  /// 1-20, or 25 for Bull.
  final int targetNumber;

  /// Multiplier hit: 1 = single, 2 = double, 3 = triple.
  final void Function(int multiplier) onHit;

  /// Fires when the ✗ cell is tapped — never routes through [onHit].
  final VoidCallback onMiss;

  /// True during a sudden-death playoff hole — changes the ✗ cell's sub
  /// copy from the regulation miss cost to `NO SCORE` (a playoff miss just
  /// stacks toward this turn's eventual stroke count, same as regulation,
  /// but the strokes aren't banked to the main scorecard/total the way a
  /// regulation hole's are, so the artboard's regulation miss-cost copy
  /// doesn't apply here).
  final bool playoff;
  final bool enabled;

  bool get _isBull => targetNumber == 25;

  List<_CellSpec> get _cells => _isBull
      ? [
          _CellSpec(
            label: '25',
            multiplier: 1,
            term: golfTerm(3),
            color: golfTermColor(3),
          ),
          _CellSpec(
            label: '50',
            multiplier: 2,
            term: golfTerm(2),
            color: golfTermColor(2),
          ),
        ]
      : [
          _CellSpec(
            label: 'S$targetNumber',
            multiplier: 1,
            term: golfTerm(3),
            color: golfTermColor(3),
          ),
          _CellSpec(
            label: 'D$targetNumber',
            multiplier: 2,
            term: golfTerm(2),
            color: golfTermColor(2),
          ),
          _CellSpec(
            label: 'T$targetNumber',
            multiplier: 3,
            term: golfTerm(1),
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
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _MissCell(onMiss: onMiss, playoff: playoff),
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
    required this.term,
    required this.color,
  });

  final String label;
  final int multiplier;

  /// Golf term shown as the sub-label (PAR/BIRDIE/ACE), including for the
  /// Bull cells (PAR/BIRDIE).
  final String? term;
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        // Below tablet width the cell's own text stack no longer fits its
        // natural size — FittedBox scales the whole label/term pair down
        // as a unit (same wrap-proof idiom as the console header above)
        // instead of the Text widgets wrapping to a 2nd line and blowing
        // out the console's fixed 220px height.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
              if (spec.term != null) ...[
                const SizedBox(height: 6),
                Text(
                  spec.term!,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The console's `✗` cell — same red chrome shape as the hit cells but its
/// own colour (`DossedartTokens.red`) and its own tap target (`onMiss`,
/// never [_InputCell.onHit]).
///
/// Sub-copy is engine-true, not the artboard's literal `5 STROKES`: a single
/// miss only ever adds ONE stroke to whatever this turn eventually scores
/// (`GolfEngine.applyDart`'s `strokes = (4 - multiplier) + missesThisHole`)
/// — a fixed "5 strokes" cost is only true for a wash (3rd miss), which is a
/// different, worse outcome than tapping ✗ once. During a sudden-death
/// playoff hole the strokes aren't banked to the regulation scorecard/total
/// at all until the hole resolves, so the artboard's `NO SCORE` copy is used
/// instead.
class _MissCell extends StatelessWidget {
  const _MissCell({required this.onMiss, required this.playoff});

  final VoidCallback onMiss;
  final bool playoff;

  @override
  Widget build(BuildContext context) {
    const color = DossedartTokens.red;
    return GestureDetector(
      onTap: onMiss,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16),
          ],
        ),
        // Same wrap-proof FittedBox treatment as _InputCell above — the
        // ✗/MISS/cost stack scales down as a unit under squeeze instead of
        // wrapping and blowing out the console's fixed 220px height.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✗',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 30,
                  color: color,
                  shadows: [Shadow(color: color, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'MISS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                playoff ? 'NO SCORE' : '+1 STROKE',
                style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 17,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
