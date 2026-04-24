import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../services/player_storage.dart';
import 'player_avatar.dart';

/// Shared sheet for managing players mid-game: remove existing, add new.
/// Per-mode rules (e.g., starting score) are handled in the [onAdd] callback.
Future<void> showMidGamePlayerSheet({
  required BuildContext context,
  required List<Player> players,
  required bool Function(int index) isRemoved,
  required bool gameOver,
  required Color Function(int index) colorFor,
  required void Function(SavedPlayer saved) onAdd,
  required void Function(int index) onRemove,
  String? addInfoText,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => _MidGameSheet(
      players: players,
      isRemoved: isRemoved,
      gameOver: gameOver,
      colorFor: colorFor,
      onAdd: onAdd,
      onRemove: onRemove,
      addInfoText: addInfoText,
    ),
  );
}

class _MidGameSheet extends StatefulWidget {
  final List<Player> players;
  final bool Function(int index) isRemoved;
  final bool gameOver;
  final Color Function(int index) colorFor;
  final void Function(SavedPlayer saved) onAdd;
  final void Function(int index) onRemove;
  final String? addInfoText;

  const _MidGameSheet({
    required this.players,
    required this.isRemoved,
    required this.gameOver,
    required this.colorFor,
    required this.onAdd,
    required this.onRemove,
    this.addInfoText,
  });

  @override
  State<_MidGameSheet> createState() => _MidGameSheetState();
}

class _MidGameSheetState extends State<_MidGameSheet> {
  List<SavedPlayer>? _available;

  @override
  void initState() {
    super.initState();
    _loadAvailable();
  }

  Future<void> _loadAvailable() async {
    final saved = await PlayerStorage.loadPlayers();
    final existingIds = widget.players
        .map((p) => p.savedPlayerId)
        .whereType<String>()
        .toSet();
    if (!mounted) return;
    final list = saved.where((sp) => !existingIds.contains(sp.id)).toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _available = list;
    });
  }

  int get _activeCount {
    int n = 0;
    for (int i = 0; i < widget.players.length; i++) {
      if (!widget.isRemoved(i)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Manage players',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.addInfoText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    widget.addInfoText!,
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange[300]),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // Player rows
              for (int i = 0; i < widget.players.length; i++)
                _buildPlayerRow(i),
              const Divider(height: 1),
              // Add section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Add a player',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[300],
                  ),
                ),
              ),
              if (_available == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_available!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No more saved players available.'),
                )
              else
                ..._available!.map((sp) => ListTile(
                      leading: PlayerAvatar(
                        avatarPath: sp.avatarPath,
                        name: sp.name,
                        radius: 18,
                        backgroundColor: Colors.blue,
                      ),
                      title: Text(sp.name),
                      subtitle: Text(
                        'Rating ${sp.rating.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add_circle,
                          color: Colors.green),
                      onTap: widget.gameOver
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onAdd(sp);
                            },
                    )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow(int i) {
    final p = widget.players[i];
    final removed = widget.isRemoved(i);
    final canRemove = !removed && !widget.gameOver && _activeCount > 2;

    return Opacity(
      opacity: removed ? 0.5 : 1.0,
      child: ListTile(
        leading: PlayerAvatar(
          avatarPath: p.avatarPath,
          name: p.name,
          radius: 18,
          backgroundColor: widget.colorFor(i),
        ),
        title: Text(p.name),
        subtitle: removed
            ? const Text('Removed from this game',
                style: TextStyle(fontSize: 12))
            : null,
        trailing: removed
            ? null
            : IconButton(
                icon: Icon(
                  Icons.person_remove,
                  color: canRemove ? Colors.red : Colors.grey,
                ),
                tooltip: canRemove
                    ? 'Remove from game'
                    : 'Need at least 2 active players',
                onPressed: canRemove
                    ? () {
                        Navigator.pop(context);
                        widget.onRemove(i);
                      }
                    : null,
              ),
      ),
    );
  }
}
