import 'package:flutter/material.dart';
import '../../models/saved_player.dart';
import '../../services/player_storage.dart';
import '../../theme/dossedart_tokens.dart';
import 'dossedart_player_avatar.dart';

/// One standing row in the unified arcade player sheet. Every cockpit maps its
/// live engine state into this shape so the sheet renders identically across modes.
class DossedartStandingRow {
  const DossedartStandingRow({
    required this.playerIndex,
    required this.name,
    required this.avatarPath,
    required this.isActive,
    required this.isRemoved,
    required this.primary,
  });

  final int playerIndex;
  final String name;
  final String? avatarPath;
  final bool isActive;
  final bool isRemoved;
  final String primary;
}

/// Unified DOSSEDART player sheet ("PLAYER OVERVIEW"; SPILLER-OVERSIKT in the
/// design): standings + remove + add-from-saved in one arcade bottom sheet,
/// shared by all 6 cockpits. The async saved-player load lives in the wrapper;
/// the widget itself is pure so it is trivially testable.
Future<void> showDossedartPlayerSheet(
  BuildContext context, {
  required List<DossedartStandingRow> rows,
  required bool gameOver,
  required Set<String> excludeSavedIds,
  required void Function(SavedPlayer saved) onAdd,
  required void Function(int index) onRemove,
  String? addInfoText,
}) async {
  final saved = await PlayerStorage.loadPlayers();
  final available = saved
      .where((sp) => !sp.archived && !excludeSavedIds.contains(sp.id))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  // Archived players count too: a newcomer must not collide with someone who
  // merely is not in this game.
  final takenNames = saved.map((p) => p.name.trim().toLowerCase()).toSet();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: DossedartTokens.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: DossedartPlayerSheet(
        rows: rows,
        gameOver: gameOver,
        available: available,
        takenNames: takenNames,
        addInfoText: addInfoText,
        onAdd: (sp) {
          Navigator.pop(ctx);
          onAdd(sp);
        },
        onCreate: (name) async {
          // A newcomer at the table: persist them and hand them to onAdd
          // exactly like a saved player picked from the list, so the per-mode
          // join rules (starting score, handicap) apply unchanged.
          final sp = await PlayerStorage.addPlayer(name);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          onAdd(sp);
        },
        onRemove: (i) {
          Navigator.pop(ctx);
          onRemove(i);
        },
      ),
    ),
  );
}

class DossedartPlayerSheet extends StatelessWidget {
  const DossedartPlayerSheet({
    super.key,
    required this.rows,
    required this.gameOver,
    required this.available,
    required this.onAdd,
    required this.onRemove,
    this.addInfoText,
    this.takenNames = const {},
    this.onCreate,
  });

  final List<DossedartStandingRow> rows;
  final bool gameOver;
  final List<SavedPlayer> available;
  final void Function(SavedPlayer saved) onAdd;
  final void Function(int index) onRemove;
  final String? addInfoText;

  /// Lower-cased, trimmed names of every saved player — used to refuse a
  /// duplicate before anything is written.
  final Set<String> takenNames;

  /// Called with a validated, trimmed name. Null hides the create row.
  final Future<void> Function(String name)? onCreate;

  int get _activeCount => rows.where((r) => !r.isRemoved).length;

  @override
  Widget build(BuildContext context) {
    final canRemove = !gameOver && _activeCount > 2;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const _SheetTitle('PLAYER OVERVIEW'),
          const SizedBox(height: 4),
          for (final row in rows)
            _StandingTile(row: row, canRemove: canRemove, onRemove: onRemove),
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const _SheetTitle('ADD PLAYER'),
          if (addInfoText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
              child: Text(
                addInfoText!,
                style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 11),
              ),
            ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Text(
                'No more saved players available.',
                style: TextStyle(color: DossedartTokens.phosphor, fontSize: 12),
              ),
            )
          else
            for (final sp in available)
              _AddTile(player: sp, enabled: !gameOver, onTap: () => onAdd(sp)),
          if (onCreate != null)
            _CreateRow(
              enabled: !gameOver,
              takenNames: takenNames,
              onCreate: onCreate!,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: DossedartTokens.yellow,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.row, required this.canRemove, required this.onRemove});
  final DossedartStandingRow row;
  final bool canRemove;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = row.isActive ? DossedartTokens.cyan : DossedartTokens.phosphor;
    return Opacity(
      opacity: row.isRemoved ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            DossedartPlayerAvatar(
              size: 36,
              borderColor: accent,
              avatarPath: row.avatarPath,
              borderWidth: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (row.isRemoved)
                    const Text(
                      'REMOVED',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: DossedartTokens.red,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              row.primary,
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 13, color: accent),
            ),
            if (!row.isRemoved) ...[
              const SizedBox(width: 12),
              _RemoveButton(enabled: canRemove, onTap: () => onRemove(row.playerIndex)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? DossedartTokens.red : DossedartTokens.disabledFg;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1)),
        child: Text(
          'REMOVE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.player, required this.enabled, required this.onTap});
  final SavedPlayer player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            DossedartPlayerAvatar(
              size: 32,
              borderColor: DossedartTokens.green,
              avatarPath: player.avatarPath,
              borderWidth: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Icon(Icons.add_circle,
                color: enabled ? DossedartTokens.green : DossedartTokens.disabledFg, size: 26),
          ],
        ),
      ),
    );
  }
}

/// "New player name" text field + CREATE & ADD, for someone who just walked in.
class _CreateRow extends StatefulWidget {
  const _CreateRow({
    required this.enabled,
    required this.takenNames,
    required this.onCreate,
  });
  final bool enabled;
  final Set<String> takenNames;
  final Future<void> Function(String name) onCreate;

  @override
  State<_CreateRow> createState() => _CreateRowState();
}

class _CreateRowState extends State<_CreateRow> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      widget.enabled && !_busy && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canCreate) return;
    final name = _controller.text.trim();
    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = 'NAME ALREADY EXISTS');
      return;
    }
    setState(() => _busy = true);
    await widget.onCreate(name);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _canCreate ? DossedartTokens.green : DossedartTokens.disabledFg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'New player name',
                    hintStyle: TextStyle(color: DossedartTokens.disabledFg),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                          color: DossedartTokens.phosphor,
                          width: DossedartTokens.borderThin),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                          color: DossedartTokens.cyan,
                          width: DossedartTokens.borderThin),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                          color: DossedartTokens.disabledBorder,
                          width: DossedartTokens.borderThin),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _canCreate ? _submit : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: color, width: DossedartTokens.borderThin)),
                  child: Text(
                    'CREATE & ADD',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: color,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: DossedartTokens.red,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
