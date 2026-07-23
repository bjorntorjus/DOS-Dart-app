import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Sudden-death tiebreak ladder (19 → 20 → BULL) shown in the same fixed
/// 96px zone the [GolfScorecardStrip] normally occupies — the screen swap
/// between the two during a playoff is Task 5's job, this widget only
/// renders the ladder for a given [stage].
class GolfSuddenDeathChain extends StatelessWidget {
  const GolfSuddenDeathChain({super.key, required this.stage});

  /// 0 = 19 is the live target, 1 = 20, 2 = BULL. Stages before [stage] are
  /// ties already resolved (shown as TIED), the stage itself is the live
  /// target (NOW), later stages haven't been reached yet.
  final int stage;

  static const _labels = ['19', '20', 'BULL'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Margin on the outer Padding, not the sized body — see the matching
      // comment in GolfScorecardStrip for why (Container.margin pollutes a
      // getSize height check against the fixed 96px zone).
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        key: const Key('golfSuddenDeathChainBody'),
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ChainHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++) ...[
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: _StageCell(
                          label: _labels[i],
                          state: _stateFor(i),
                        ),
                      ),
                    ),
                    if (i != _labels.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ChainCellState _stateFor(int i) {
    if (i < stage) return _ChainCellState.done;
    if (i == stage) return _ChainCellState.current;
    return _ChainCellState.future;
  }
}

class _ChainHeader extends StatelessWidget {
  const _ChainHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SUDDEN DEATH',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: DossedartTokens.red,
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: DossedartTokens.red.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'TIE ▸ NEXT',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

enum _ChainCellState { done, current, future }

class _StageCell extends StatelessWidget {
  const _StageCell({required this.label, required this.state});

  final String label;
  final _ChainCellState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _ChainCellState.done:
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '✓ TIED',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      case _ChainCellState.current:
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DossedartTokens.red.withValues(alpha: 0.10),
            border: Border.all(color: DossedartTokens.red, width: 2),
            boxShadow: [
              BoxShadow(
                color: DossedartTokens.red.withValues(alpha: 0.6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 18,
                  color: DossedartTokens.red,
                  shadows: [
                    Shadow(
                      color: DossedartTokens.red.withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '▶ NOW',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      case _ChainCellState.future:
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '·',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        );
    }
  }
}
