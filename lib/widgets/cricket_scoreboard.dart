import 'package:flutter/material.dart';
class CricketScoreboard extends StatelessWidget {
  final List<int> targets; // e.g. [20, 19, 18, 17, 16, 15, 25]
  final List<String> playerNames;
  final List<Map<int, int>> marks; // [playerIndex][target] = mark count (0-3+)
  final List<int> scores;
  final int currentPlayerIndex;

  const CricketScoreboard({
    super.key,
    required this.targets,
    required this.playerNames,
    required this.marks,
    required this.scores,
    required this.currentPlayerIndex,
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
              return DataColumn(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playerNames[pi].length > 6
                          ? playerNames[pi].substring(0, 6)
                          : playerNames[pi],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          rows: [
            // Target rows
            ...targets.map((target) {
              return DataRow(cells: [
                DataCell(Text(
                  target == 25 ? 'Bull' : '$target',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                )),
                ...List.generate(playerNames.length, (pi) {
                  final m = marks[pi][target] ?? 0;
                  return DataCell(Center(child: _markWidget(m)));
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

  Widget _markWidget(int count) {
    if (count == 0) return const SizedBox(width: 24);
    if (count == 1) {
      return const Text('/', style: TextStyle(fontSize: 16, color: Colors.white));
    }
    if (count == 2) {
      return const Text('X', style: TextStyle(fontSize: 16, color: Colors.white));
    }
    // 3+ = closed (circle)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.radio_button_checked,
            size: 16, color: Colors.green),
        if (count > 3)
          Text('+${count - 3}',
              style: const TextStyle(fontSize: 10, color: Colors.green)),
      ],
    );
  }
}
