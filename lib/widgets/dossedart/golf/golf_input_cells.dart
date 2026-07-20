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
          _CellSpec(
              label: '25',
              multiplier: 1,
              term: golfTerm(3),
              color: golfTermColor(3)),
          _CellSpec(
              label: '50',
              multiplier: 2,
              term: golfTerm(2),
              color: golfTermColor(2)),
        ]
      : [
          _CellSpec(
              label: 'S$targetNumber',
              multiplier: 1,
              term: golfTerm(3),
              color: golfTermColor(3)),
          _CellSpec(
              label: 'D$targetNumber',
              multiplier: 2,
              term: golfTerm(2),
              color: golfTermColor(2)),
          _CellSpec(
              label: 'T$targetNumber',
              multiplier: 3,
              term: golfTerm(1),
              color: golfTermColor(1)),
        ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DossedartTokens.green.withValues(alpha: 0.11),
                  border: Border(
                    bottom: BorderSide(
                        color: DossedartTokens.green.withValues(alpha: 0.4)),
                  ),
                ),
                child: Row(
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
                            color: DossedartTokens.green.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '· THROW AT ${_isBull ? 'BULL' : targetNumber}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 16,
                          color: Colors.white60,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    for (final cell in _cells)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _InputCell(spec: cell, onHit: onHit),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '✗ MISS = +1 STROKE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
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
            BoxShadow(color: spec.color.withValues(alpha: 0.35), blurRadius: 16),
          ],
        ),
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
                  Shadow(color: spec.color.withValues(alpha: 0.7), blurRadius: 10),
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
    );
  }
}
