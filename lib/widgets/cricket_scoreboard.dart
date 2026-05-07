import 'package:flutter/material.dart';
import 'active_player_highlight.dart';

class CricketScoreboard extends StatelessWidget {
  final List<int> targets; // e.g. [20, 19, 18, 17, 16, 15, 25]
  final List<String> playerNames;
  final List<Map<int, int>> marks; // [playerIndex][target] = mark count (0-3+)
  final List<int> scores;
  final int currentPlayerIndex;
  final Set<int> deadTargets;

  const CricketScoreboard({
    super.key,
    required this.targets,
    required this.playerNames,
    required this.marks,
    required this.scores,
    required this.currentPlayerIndex,
    this.deadTargets = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 36,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 32,
          columns: [
            const DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
            ...List.generate(playerNames.length, (pi) {
              final isCurrent = pi == currentPlayerIndex;
              return DataColumn(
                label: ActivePlayerHighlight(
                  isActive: isCurrent,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  borderRadius: BorderRadius.circular(8),
                  borderWidth: 2,
                  child: Text(
                    playerNames[pi].length > 6
                        ? playerNames[pi].substring(0, 6)
                        : playerNames[pi],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ],
          rows: [
            // Target rows
            ...targets.map((target) {
              final isDead = deadTargets.contains(target);
              return DataRow(cells: [
                DataCell(
                  Opacity(
                    opacity: isDead ? 0.35 : 1.0,
                    child: Text(
                      target == 25 ? 'Bull' : '$target',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: isDead ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                ...List.generate(playerNames.length, (pi) {
                  final m = marks[pi][target] ?? 0;
                  return DataCell(Center(
                    child: Opacity(
                      opacity: isDead ? 0.35 : 1.0,
                      child: _markWidget(m, isDead, Theme.of(context).colorScheme),
                    ),
                  ));
                }),
              ]);
            }),
            // Score row
            DataRow(
              color: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
              cells: [
                const DataCell(Text('Score',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ...List.generate(playerNames.length, (pi) {
                  return DataCell(Center(
                    child: Text(
                      '${scores[pi]}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _markWidget(int count, bool isDead, ColorScheme cs) {
    if (count == 0) return const SizedBox(width: 24);
    final closedColor = isDead ? cs.onSurface.withValues(alpha: 0.4) : Colors.green;
    if (count == 1) {
      return Text('/', style: TextStyle(fontSize: 16, color: cs.onSurface));
    }
    if (count == 2) {
      return Text('X', style: TextStyle(fontSize: 16, color: cs.onSurface));
    }
    // 3+ = closed (circle or lock)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isDead ? Icons.lock_outline : Icons.radio_button_checked,
            size: 16, color: closedColor),
        if (count > 3)
          Text('+${count - 3}',
              style: TextStyle(fontSize: 10, color: closedColor)),
      ],
    );
  }
}
