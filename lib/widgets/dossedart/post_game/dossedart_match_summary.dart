import 'package:flutter/material.dart';

import '../../../screens/post_game/match_summary.dart';
import '../../../theme/dossedart_tokens.dart';
import 'post_game_type.dart';

/// The game-level zone at the bottom of the scroll: 3 × 2 label/value cells
/// (design fasit 2026-08-10).
///
/// Values are LIME, which is reserved here and for the primary action, so a
/// number about the MATCH reads as a different class than the per-player
/// accents above it.
///
/// The zone never shrinks. An unavailable cell is dimmed with an em dash in
/// place, so the screen has the same shape whether or not the throw history
/// survived — see [MatchSummary] for why nulls are normal.
class DossedartMatchSummary extends StatelessWidget {
  const DossedartMatchSummary({super.key, required this.summary});

  final MatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final cells = <_Cell>[
      _Cell('DURATION', s.duration),
      _Cell('ROUNDS', s.rounds),
      _Cell('DARTS THROWN', s.darts),
      _Cell(s.bestTurnLabel, s.bestTurn,
          sub: s.degraded ? 'NOT RECORDED' : s.bestTurnBy),
      _Cell('HIT DISTRIBUTION', s.hitDistribution),
      _Cell('BIGGEST LEAD', s.biggestLead),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostGameSectionLabel('MATCH SUMMARY',
            note: s.degraded ? '· partly unavailable' : null),
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 6),
                  Expanded(child: cells[r * 3 + c]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.label, this.value, {this.sub});

  final String label;

  /// Null means "not available" — dimmed, em dash, same footprint.
  final String? value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final dim = value == null;
    return Opacity(
      opacity: dim ? 0.32 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          border:
              Border.all(color: DossedartTokens.magenta.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PostGameType.vtStyle(14,
                    color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value ?? '—',
                style: PostGameType.psStyle(13,
                    color: dim ? Colors.white : DossedartTokens.lime,
                    glow: dim ? null : DossedartTokens.lime),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PostGameType.vtStyle(14,
                      color: Colors.white.withValues(alpha: 0.42),
                      letterSpacing: 1)),
            ],
          ],
        ),
      ),
    );
  }
}
