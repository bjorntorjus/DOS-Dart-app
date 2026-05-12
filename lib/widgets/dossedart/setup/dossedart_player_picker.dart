import 'package:flutter/material.dart';
import '../../../models/saved_player.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dossedart_picker_tile.dart';

/// 2-column grid of picker tiles plus an ADD PLAYER tile.
///
/// Pure presentation — caller passes the saved players, the current
/// selection (in order), and three callbacks.
class DossedartPlayerPicker extends StatelessWidget {
  const DossedartPlayerPicker({
    super.key,
    required this.savedPlayers,
    required this.selectedIds,
    required this.onToggle,
    required this.onLongPress,
    required this.onAdd,
  });

  final List<SavedPlayer> savedPlayers;
  final List<String> selectedIds;
  final ValueChanged<SavedPlayer> onToggle;
  final ValueChanged<SavedPlayer> onLongPress;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 142,
      ),
      itemCount: savedPlayers.length + 1,
      itemBuilder: (_, i) {
        if (i == savedPlayers.length) return _AddTile(onAdd: onAdd);
        final sp = savedPlayers[i];
        final slotIdx = selectedIds.indexOf(sp.id);
        return DossedartPickerTile(
          player: sp,
          selected: slotIdx >= 0,
          slot: slotIdx >= 0 ? slotIdx + 1 : null,
          onTap: () => onToggle(sp),
          onLongPress: () => onLongPress(sp),
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: DossedartTokens.cyan, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: DossedartTokens.cyan, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                '+',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: DossedartTokens.cyan,
                  letterSpacing: 1,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ADD PLAYER',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: DossedartTokens.cyan,
                letterSpacing: 1.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
