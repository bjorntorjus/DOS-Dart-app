import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../services/player_storage.dart';
import '../utils/player_colors.dart';
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

  /// Every saved player's name (archived too) — a newcomer must not collide
  /// with someone who merely is not in this game.
  Set<String> _takenNames = {};
  final _newName = TextEditingController();
  String? _newNameError;
  bool _creating = false;

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

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
    final list = saved
        .where((sp) => !sp.archived && !existingIds.contains(sp.id))
        .toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _available = list;
      _takenNames = saved.map((p) => p.name.trim().toLowerCase()).toSet();
    });
  }

  /// A newcomer at the table: persist them and hand them to [onAdd] exactly
  /// like a saved player picked from the list, so the per-mode join rules
  /// (starting score, handicap) apply unchanged.
  Future<void> _createAndAdd() async {
    final name = _newName.text.trim();
    if (name.isEmpty || _creating) return;
    if (_takenNames.contains(name.toLowerCase())) {
      setState(() => _newNameError = 'Name already exists');
      return;
    }
    setState(() => _creating = true);
    final saved = await PlayerStorage.addPlayer(name);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onAdd(saved);
  }

  Widget _buildCreateRow() {
    final canCreate =
        !widget.gameOver && !_creating && _newName.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _newName,
              enabled: !widget.gameOver,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'New player name',
                isDense: true,
                errorText: _newNameError,
              ),
              onChanged: (_) => setState(() => _newNameError = null),
              onSubmitted: (_) => _createAndAdd(),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FilledButton.icon(
              onPressed: canCreate ? _createAndAdd : null,
              icon: const Icon(Icons.person_add),
              label: const Text('Create & add'),
            ),
          ),
        ],
      ),
    );
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
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
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
                ..._available!.asMap().entries.map((entry) => ListTile(
                      leading: PlayerAvatar(
                        avatarPath: entry.value.avatarPath,
                        name: entry.value.name,
                        radius: 18,
                        backgroundColor: avatarColor(entry.key),
                      ),
                      title: Text(entry.value.name),
                      subtitle: Text(
                        'Rating ${entry.value.rating.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Icon(Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary),
                      onTap: widget.gameOver
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onAdd(entry.value);
                            },
                    )),
              _buildCreateRow(),
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
                  color: canRemove
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
