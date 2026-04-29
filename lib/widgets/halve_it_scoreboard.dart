import 'package:flutter/material.dart';
import '../models/halve_it_round.dart';
import 'active_player_highlight.dart';

class HalveItScoreboard extends StatelessWidget {
  final List<HalveItRound> rounds;
  final List<String> playerNames;
  final List<List<int?>> roundScores; // [roundIndex][playerIndex]
  final List<int> totalScores;
  final int currentRoundIndex;
  final int currentPlayerIndex;

  const HalveItScoreboard({
    super.key,
    required this.rounds,
    required this.playerNames,
    required this.roundScores,
    required this.totalScores,
    required this.currentRoundIndex,
    required this.currentPlayerIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 36,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 34,
          columns: [
            const DataColumn(label: Text('Round', style: TextStyle(fontSize: 12))),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ],
          rows: [
            ...List.generate(rounds.length, (ri) {
              final round = rounds[ri];
              final isCurrent = ri == currentRoundIndex;
              return DataRow(
                color: isCurrent
                    ? WidgetStatePropertyAll(Colors.amber.withAlpha(20))
                    : null,
                cells: [
                  DataCell(Text(
                    round.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.amber : null,
                    ),
                  )),
                  ...List.generate(playerNames.length, (pi) {
                    final score = roundScores[ri][pi];
                    if (score == null) {
                      return const DataCell(Text('-',
                          style: TextStyle(fontSize: 12, color: Colors.grey)));
                    }
                    final isHalved = score < 0;
                    return DataCell(Text(
                      isHalved ? '${score.abs()} ✗' : '$score',
                      style: TextStyle(
                        fontSize: 12,
                        color: isHalved ? Colors.red : Colors.white,
                      ),
                    ));
                  }),
                ],
              );
            }),
            // Total row
            DataRow(
              color: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
              cells: [
                const DataCell(Text('Total',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                ...List.generate(playerNames.length, (pi) {
                  return DataCell(Text(
                    '${totalScores[pi]}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
