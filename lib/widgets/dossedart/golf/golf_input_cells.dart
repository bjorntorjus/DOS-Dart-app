import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart';
import 'dossedart_golf_active_card.dart' show golfTermColor;

/// S/D/T target-zone input for the DOSSEDART Golf cockpit — ATC's target
/// cells (`_atcInputCells`), extracted as a real widget and coloured per
/// stroke term instead of ATC's uniform cyan.
///
/// Normal target: single (`S<n>`, PAR), double (`D<n>`, BIRDIE), triple
/// (`T<n>`, ACE). Bull (`targetNumber == 25`, sudden death only) drops the
/// triple cell — `BULL` (PAR) / `D-BULL` (BIRDIE) only, using the same
/// term vocabulary as the normal cells.
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
              label: 'BULL',
              multiplier: 1,
              term: golfTerm(3),
              color: golfTermColor(3)),
          _CellSpec(
              label: 'D-BULL',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            const SizedBox(height: 8),
            const Text(
              'MISS = +1 STROKE',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 14,
                color: Colors.white54,
                letterSpacing: 1,
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: spec.color.withValues(alpha: 0.07),
          border: Border.all(color: spec.color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              spec.label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 16,
                color: spec.color,
              ),
            ),
            if (spec.term != null) ...[
              const SizedBox(height: 4),
              Text(
                spec.term!,
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 13,
                  color: spec.color,
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
