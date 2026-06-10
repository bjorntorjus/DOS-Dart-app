import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../models/player.dart';
import '../../../models/saved_player.dart';
import '../../../services/player_storage.dart';
import '../../../theme/dossedart_tokens.dart';
import '../arcade_frame.dart';
import 'dossedart_player_picker.dart';

/// Shared chrome for all DOSSEDART setup screens.
///
/// Owns the player roster, the current selection (in order = play order),
/// the random-order toggle, and all picker-side dialogs (add-player,
/// profile-edit). Mode-specific RULES are passed in via [rulesSection] as a
/// builder that receives the random-order state so each mode can place the
/// RANDOM ORDER toggle wherever fits its layout.
/// The per-mode start logic is delegated to [onStart].
class DossedartSetupScaffold extends StatefulWidget {
  const DossedartSetupScaffold({
    super.key,
    required this.title,
    required this.rulesSection,
    required this.minPlayers,
    required this.summaryBuilder,
    required this.onStart,
  });

  final String title;
  final Widget Function(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) rulesSection;
  final int minPlayers;

  /// Builds the trailing summary string shown under the START button.
  /// Receives the current count of selected players so the caller can
  /// inject mode-config text (e.g. 'CUTTHROAT · RANDOM TARGETS').
  final String Function(int playerCount) summaryBuilder;

  /// Called when the user taps START. The scaffold supplies the ordered
  /// player list (already shuffled if `randomize` is true) and the
  /// randomize flag itself. The list uses `score: 0` as a placeholder —
  /// the mode screen overrides if needed (e.g. X01 handicap) before
  /// navigating to the game screen.
  final void Function(List<Player> players, bool randomize) onStart;

  @override
  State<DossedartSetupScaffold> createState() => _DossedartSetupScaffoldState();
}

class _DossedartSetupScaffoldState extends State<DossedartSetupScaffold> {
  List<SavedPlayer> _savedPlayers = [];
  final List<String> _selectedIds = []; // preserves slot order
  bool _isLoading = true;
  bool _randomOrder = true; // default ON per spec

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final players = await PlayerStorage.loadPlayers();
    players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _savedPlayers = players;
      _isLoading = false;
    });
  }

  void _toggleSelected(SavedPlayer sp) {
    setState(() {
      if (_selectedIds.contains(sp.id)) {
        _selectedIds.remove(sp.id);
      } else {
        _selectedIds.add(sp.id);
      }
    });
  }

  Future<void> _addNewPlayer() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameInputDialog(title: 'NEW FIGHTER'),
    );
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    final saved = await PlayerStorage.addPlayer(trimmed);
    if (!mounted) return;
    setState(() {
      _savedPlayers.add(saved);
      _savedPlayers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedIds.add(saved.id);
    });
  }

  Future<void> _showPlayerProfile(SavedPlayer sp) async {
    await showDialog(
      context: context,
      builder: (_) => _PlayerProfileDialog(
        player: sp,
        savedPlayers: _savedPlayers,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _handleStart() {
    if (_selectedIds.length < widget.minPlayers) return;
    final byId = {for (final p in _savedPlayers) p.id: p};
    final players = _selectedIds
        .map((id) => byId[id]!)
        .map((sp) => Player(
              name: sp.name,
              score: 0,
              savedPlayerId: sp.id,
              avatarPath: sp.avatarPath,
            ))
        .toList();
    if (_randomOrder) players.shuffle(Random());
    widget.onStart(players, _randomOrder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: DossedartTokens.magenta))
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '► RULES',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 11,
                                  color: DossedartTokens.cyan,
                                  letterSpacing: 1.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              widget.rulesSection(
                                _randomOrder,
                                (v) => setState(() => _randomOrder = v),
                              ),
                              const SizedBox(height: 18),
                              _buildCastHeader(),
                              const SizedBox(height: 12),
                              DossedartPlayerPicker(
                                savedPlayers: _savedPlayers,
                                selectedIds: _selectedIds,
                                onToggle: _toggleSelected,
                                onLongPress: _showPlayerProfile,
                                onAdd: _addNewPlayer,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildStartBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: DossedartTokens.magenta, width: 2),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              '◀ HOME',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.cyan,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 13,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const Text(
            '1CR',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 16,
              color: Colors.white54,
              letterSpacing: 2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastHeader() {
    final count = _selectedIds.length;
    final readyLabel = count < widget.minPlayers
        ? '$count READY · MIN ${widget.minPlayers}'
        : '$count READY';
    return Row(
      children: [
        const Expanded(
          child: Text(
            '► PICK YOUR FIGHTERS',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: DossedartTokens.cyan,
              letterSpacing: 1.5,
              height: 1.3,
            ),
          ),
        ),
        Text(
          readyLabel,
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 14,
            color: DossedartTokens.yellow,
            letterSpacing: 2,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStartBar() {
    final canStart = _selectedIds.length >= widget.minPlayers;
    final summary = widget.summaryBuilder(_selectedIds.length);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: DossedartTokens.yellow, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: canStart ? _handleStart : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: canStart
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [DossedartTokens.yellow, Color(0xFFFFA500)],
                      )
                    : null,
                color: canStart ? null : Colors.white12,
                border: Border.all(
                  color: canStart ? Colors.white : Colors.white24,
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '▶ START MATCH ◀',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  color: canStart ? DossedartTokens.bg : Colors.white38,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 15,
              color: Colors.white60,
              letterSpacing: 3,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A name-entry dialog that owns its own [TextEditingController]. Binding the
/// controller to this widget's State means it is disposed only when the dialog
/// route fully unmounts (after its exit transition) — never synchronously while
/// the reverse animation is still rebuilding the field, which crashed with
/// "TextEditingController used after being disposed".
class _NameInputDialog extends StatefulWidget {
  const _NameInputDialog({required this.title});

  final String title;

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Player-profile dialog (avatar + name + stats). Owns its name controller for
/// the same lifecycle reason as [_NameInputDialog]. Persists edits to
/// [savedPlayers] and notifies the parent via [onChanged].
class _PlayerProfileDialog extends StatefulWidget {
  const _PlayerProfileDialog({
    required this.player,
    required this.savedPlayers,
    required this.onChanged,
  });

  final SavedPlayer player;
  final List<SavedPlayer> savedPlayers;
  final VoidCallback onChanged;

  @override
  State<_PlayerProfileDialog> createState() => _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends State<_PlayerProfileDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.player.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _editAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;
    final sp = widget.player;
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/avatars');
    if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
    final ext = p.extension(image.path);
    final dest = '${avatarDir.path}/${sp.id}$ext';
    await File(image.path).copy(dest);
    sp.avatarPath = dest;
    await PlayerStorage.savePlayers(widget.savedPlayers);
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  Future<void> _save() async {
    final sp = widget.player;
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != sp.name) {
      sp.name = newName;
      await PlayerStorage.savePlayers(widget.savedPlayers);
      widget.onChanged();
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.player;
    return AlertDialog(
      title: const Text('Player profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _editAvatar,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: sp.avatarPath != null
                    ? FileImage(File(sp.avatarPath!))
                    : null,
                child: sp.avatarPath == null
                    ? const Icon(Icons.add_a_photo, size: 32)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _stat('Rating', sp.rating.round().toString()),
            _stat('Games played', sp.gamesPlayed.toString()),
            _stat('Win rate', '${(sp.winRate * 100).toStringAsFixed(0)}%'),
            _stat('Avg turn score', sp.averageTurnScore.toStringAsFixed(1)),
            _stat('Best turn', sp.highestTurnScore.toString()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
