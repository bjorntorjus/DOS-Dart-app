import 'package:flutter/material.dart';

import '../../../screens/post_game/post_game_fields.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';
import 'post_game_type.dart';

/// One standings row: rank plate · avatar · name · headline · Elo, with the
/// mode's remaining stats in a three-column grid below (design fasit
/// 2026-08-10 — this grid IS the wall-of-text fix).
///
/// Every card in a game has the same height: the grid's row count is
/// `ceil(fields / 3)` and a mode's field count does not vary between games,
/// because conditional counters at zero are dimmed in place rather than
/// removed. No expanded "current player" row, no top-three exception.
class DossedartPlacementCard extends StatelessWidget {
  const DossedartPlacementCard({
    super.key,
    required this.placement,
    required this.name,
    required this.accent,
    required this.fields,
    this.avatarPath,
    this.ratingChange,
    this.showElo = true,
    this.showStats = true,
    this.isTied = false,
  });

  final int placement;
  final String name;

  /// The player's colour from the 5-accent cycle, indexed by SEAT — so a
  /// player keeps one colour between this card and the progression chart.
  final Color accent;
  final PostGameFields fields;
  final String? avatarPath;
  final double? ratingChange;

  /// False for modes that never rate (WILDCARD). The column still occupies
  /// its fixed 86 px and renders a dimmed em dash, so standings geometry is
  /// the same in every mode; [showStats] false drops it entirely instead,
  /// since that screen is a different thing rather than the same screen
  /// missing a value.
  final bool showElo;

  /// Always true on the result screen, which is always final; the flag
  /// remains so the card itself can still render a stats-hidden layout.
  final bool showStats;
  final bool isTied;

  @override
  Widget build(BuildContext context) {
    final isFirst = placement == 1;
    final medal = PostGameType.medal(placement);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(
          color: isFirst
              ? DossedartTokens.yellow
              : accent.withValues(alpha: 0.53),
          width: 2,
        ),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: DossedartTokens.yellow.withValues(alpha: 0.27),
                  blurRadius: 14,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 40, child: _header(medal)),
          if (showStats && fields.fields.isNotEmpty)
            _StatGrid(fields: fields.fields),
        ],
      ),
    );
  }

  Widget _header(Color? medal) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medal == null
                ? Colors.transparent
                : medal.withValues(alpha: 0.09),
            border: Border.all(
              color: medal ?? Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Text(
            '$placement',
            style: PostGameType.psStyle(
              14,
              color: medal ?? Colors.white.withValues(alpha: 0.7),
              glow: medal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DossedartPlayerAvatar(
            size: 40, borderColor: accent, avatarPath: avatarPath),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PostGameType.psStyle(
                          PostGameType.standingsName(name),
                          height: 1),
                    ),
                  ),
                  if (isTied) ...[
                    const SizedBox(width: 8),
                    Text('TIED',
                        style: PostGameType.vtStyle(15,
                            color: DossedartTokens.yellow,
                            letterSpacing: 1,
                            height: 1)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fields.headlineLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PostGameType.vtStyle(15,
                    color: Colors.white.withValues(alpha: 0.45), height: 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fields.headlineValue,
          style: PostGameType.psStyle(20,
              color: accent, letterSpacing: -0.5, glow: accent),
        ),
        if (showStats) ...[
          const SizedBox(width: 8),
          SizedBox(width: 86, child: _elo()),
        ],
      ],
    );
  }

  Widget _elo() {
    final d = showElo ? ratingChange : null;
    final none = d == null;
    final up = !none && d > 0.05;
    final down = !none && d < -0.05;
    final color = none
        ? Colors.white
        : up
            ? DossedartTokens.green
            : down
                ? DossedartTokens.red
                : Colors.white.withValues(alpha: 0.5);
    final text = none
        ? '—'
        : '${up ? '▲' : down ? '▼' : '='}'
            '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}';

    return Opacity(
      opacity: none ? 0.3 : 1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('ELO',
              style: PostGameType.vtStyle(14,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 2)),
          const SizedBox(height: 2),
          Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PostGameType.psStyle(11,
                  color: color, glow: none ? null : color)),
        ],
      ),
    );
  }
}

/// Three fixed columns, filled in the mode's declared order. A partial last
/// row is padded with empty dim tracks so every card is a clean rectangle.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.fields});

  final List<StatField> fields;

  @override
  Widget build(BuildContext context) {
    final rows = (fields.length / 3).ceil();
    final slots = <StatField?>[
      ...fields,
      ...List.filled(rows * 3 - fields.length, null),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 6),
                  Expanded(child: _StatCell(field: slots[r * 3 + c])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.field});

  final StatField? field;

  @override
  Widget build(BuildContext context) {
    final f = field;
    if (f == null) {
      return Container(
        key: const Key('statSlotEmpty'),
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.012),
          border: Border.all(
              color: DossedartTokens.magenta.withValues(alpha: 0.09)),
        ),
      );
    }
    return Opacity(
      opacity: f.isZero ? 0.34 : 1,
      child: Container(
        key: const Key('statSlot'),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          border: Border.all(
              color: DossedartTokens.magenta.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(f.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PostGameType.vtStyle(15,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Text(f.value,
                style: PostGameType.psStyle(10, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
