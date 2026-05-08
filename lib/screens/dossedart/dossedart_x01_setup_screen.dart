import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/saved_player.dart';
import '../../services/player_storage.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/arcade_frame.dart';
import '../game_screen.dart';

/// DOSSEDART X01 setup — picks players + rules.
/// Start score is already chosen on the home screen and passed in.
class DossedartX01SetupScreen extends StatefulWidget {
  const DossedartX01SetupScreen({super.key, required this.startingScore});

  final int startingScore;

  @override
  State<DossedartX01SetupScreen> createState() =>
      _DossedartX01SetupScreenState();
}

class _DossedartX01SetupScreenState extends State<DossedartX01SetupScreen> {
  List<SavedPlayer> _savedPlayers = [];
  final List<String> _selectedIds = []; // preserves slot order
  bool _isLoading = true;

  // Rules
  String _outRule = 'none'; // 'none' (free) | 'double' | 'master'
  bool _noBust = false;
  bool _handicap = false;
  bool _randomOrder = false;

  static const _minPlayers = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final players = await PlayerStorage.loadPlayers();
    players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _savedPlayers = players;
      _isLoading = false;
    });
  }

  TextStyle _press(double size, {Color? color, double letterSpacing = 1}) =>
      TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: size,
        color: color ?? Colors.white,
        letterSpacing: letterSpacing,
        height: 1.3,
      );

  TextStyle _vt(double size, {Color? color, double letterSpacing = 1}) =>
      TextStyle(
        fontFamily: 'VT323',
        fontSize: size,
        color: color ?? Colors.white,
        letterSpacing: letterSpacing,
        height: 1,
      );

  String _handleFor(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length >= 3) return cleaned.substring(0, 3);
    return cleaned.padRight(3, 'X');
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
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NEW FIGHTER'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty) return;

    final saved = await PlayerStorage.addPlayer(name);
    setState(() {
      _savedPlayers.add(saved);
      _savedPlayers
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedIds.add(saved.id);
    });
  }

  void _startGame() {
    if (_selectedIds.length < _minPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NEED AT LEAST $_minPlayers PLAYERS')),
      );
      return;
    }
    final byId = {for (final p in _savedPlayers) p.id: p};
    final players = _selectedIds
        .map((id) => byId[id]!)
        .map((sp) => Player(
              name: sp.name,
              score: widget.startingScore,
              savedPlayerId: sp.id,
              avatarPath: sp.avatarPath,
            ))
        .toList();
    if (_randomOrder) players.shuffle(Random());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          players: players,
          masterOut: _outRule,
          startingScore: widget.startingScore,
          handicap: _handicap,
          noBust: _noBust,
        ),
      ),
    );
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
                        child: Column(
                          children: [
                            _buildRules(),
                            _buildCast(),
                            const SizedBox(height: 16),
                          ],
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

  // ─── Top bar ─────────────────────────────────────────────────────────────
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
            child: Text('◀ HOME',
                style: _vt(18, color: DossedartTokens.cyan, letterSpacing: 2)),
          ),
          Expanded(
            child: Center(
              child: Text(
                'NEW MATCH · ${widget.startingScore}',
                style: _press(13,
                    color: DossedartTokens.yellow, letterSpacing: 2),
              ),
            ),
          ),
          Text('1CR',
              style: _vt(16, color: Colors.white54, letterSpacing: 2)),
        ],
      ),
    );
  }

  // ─── Rules ───────────────────────────────────────────────────────────────
  Widget _buildRules() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x66FF00AA), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('► RULES',
              style: _press(11,
                  color: DossedartTokens.cyan, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text('OUT RULE',
              style: _vt(13, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _outChip('FREE OUT', 'none')),
              const SizedBox(width: 4),
              Expanded(child: _outChip('DOUBLE OUT', 'double')),
              const SizedBox(width: 4),
              Expanded(child: _outChip('MASTER OUT', 'master')),
            ],
          ),
          const SizedBox(height: 14),
          Text('OPTIONS',
              style: _vt(13, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _toggle('NO-BUST', _noBust, DossedartTokens.magenta,
                    (v) => setState(() => _noBust = v)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _toggle('HANDICAP', _handicap, DossedartTokens.cyan,
                    (v) => setState(() => _handicap = v)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _toggle('RANDOM', _randomOrder, DossedartTokens.purple,
                    (v) => setState(() => _randomOrder = v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outChip(String label, String value) {
    final on = _outRule == value;
    return GestureDetector(
      onTap: () => setState(() => _outRule = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? DossedartTokens.yellow : DossedartTokens.surface,
          border: Border.all(
            color: on ? DossedartTokens.yellow : DossedartTokens.magenta,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: _press(10,
              color: on ? DossedartTokens.bg : Colors.white,
              letterSpacing: 0.5),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _toggle(
      String label, bool on, Color accent, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.13) : DossedartTokens.surface,
          border: Border.all(
            color: on ? accent : DossedartTokens.magenta,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 14,
              decoration: BoxDecoration(
                color: on ? accent : Colors.white24,
                border: Border.all(color: accent.withValues(alpha: 0.6), width: 1),
              ),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 10,
                height: 10,
                color: on ? DossedartTokens.bg : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: _press(8.5, color: Colors.white, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Cast (player picker) ────────────────────────────────────────────────
  Widget _buildCast() {
    final selectedCount = _selectedIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('► PICK YOUR FIGHTERS',
                    style: _press(11,
                        color: DossedartTokens.cyan, letterSpacing: 1.5)),
              ),
              Text(
                '$selectedCount READY${_randomOrder ? ' · RANDOM' : ''}',
                style: _vt(14,
                    color: DossedartTokens.yellow, letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 130,
            ),
            itemCount: _savedPlayers.length + 1,
            itemBuilder: (_, i) {
              if (i == _savedPlayers.length) return _buildAddTile();
              final sp = _savedPlayers[i];
              return _buildPickerTile(sp);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile(SavedPlayer sp) {
    final selected = _selectedIds.contains(sp.id);
    final slot = selected ? _selectedIds.indexOf(sp.id) + 1 : null;
    final accent =
        selected ? DossedartTokens.yellow : DossedartTokens.magenta;
    return GestureDetector(
      onTap: () => _toggleSelected(sp),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: selected ? 1.0 : 0.7,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x10FFD200)
                    : DossedartTokens.surface,
                border: Border.all(color: accent, width: 3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DossedartTokens.bg,
                      border: Border.all(color: accent, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _handleFor(sp.name),
                      style: _press(11, color: accent, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sp.name.toUpperCase(),
                          style: _vt(18,
                              color: Colors.white, letterSpacing: 1),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R ${sp.rating.round()}',
                          style: _vt(13,
                              color: Colors.white54, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        _buildFormPips(accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (slot != null)
            Positioned(
              top: -8,
              right: -4,
              child: Transform.rotate(
                angle: 0.07,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  color: DossedartTokens.yellow,
                  child: Text(
                    'P$slot',
                    style: _press(10,
                        color: DossedartTokens.bg, letterSpacing: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Last-5 W/L pip row.
  ///
  /// SavedPlayer doesn't yet store per-game results, so every pip is rendered
  /// as a placeholder "?" outline. When recent-results tracking lands
  /// (see project memory), pass the bool list in here:
  /// - true  -> filled accent pip with "W"
  /// - false -> outlined pip with "L"
  /// - null  -> outlined "?" placeholder
  Widget _buildFormPips(Color accent, {List<bool?>? results}) {
    final entries = (results ?? List<bool?>.filled(5, null));
    final pips = <Widget>[];
    for (var i = 0; i < 5; i++) {
      final r = i < entries.length ? entries[i] : null;
      pips.add(_pip(r, accent));
      if (i < 4) pips.add(const SizedBox(width: 3));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: pips);
  }

  Widget _pip(bool? result, Color accent) {
    final isW = result == true;
    final isL = result == false;
    final isPlaceholder = result == null;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isW ? accent : Colors.transparent,
        border: Border.all(
          color: isW
              ? accent
              : isL
                  ? Colors.white24
                  : Colors.white24,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        isW ? 'W' : (isL ? 'L' : '?'),
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 6,
          color: isW
              ? DossedartTokens.bg
              : isPlaceholder
                  ? Colors.white30
                  : Colors.white54,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _addNewPlayer,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: DossedartTokens.cyan,
            width: 3,
            style: BorderStyle.solid, // dashed not supported natively
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: Border.all(
                      color: DossedartTokens.cyan, width: 2)
                  .toBoxDecoration(),
              alignment: Alignment.center,
              child: Text('+',
                  style: _press(20,
                      color: DossedartTokens.cyan, letterSpacing: 1)),
            ),
            const SizedBox(height: 6),
            Text('ADD PLAYER',
                style: _press(10,
                    color: DossedartTokens.cyan, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ─── Start bar ───────────────────────────────────────────────────────────
  Widget _buildStartBar() {
    final canStart = _selectedIds.length >= _minPlayers;
    final outLabel = switch (_outRule) {
      'double' => 'DOUBLE OUT',
      'master' => 'MASTER OUT',
      _ => 'FREE OUT',
    };
    final summary = [
      '${_selectedIds.length} PLAYERS',
      outLabel,
      if (_noBust) 'NO-BUST',
      if (_handicap) 'HANDICAP',
      if (_randomOrder) 'RANDOM ORDER',
    ].join(' · ');

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
            onTap: canStart ? _startGame : null,
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
                style: _press(16,
                    color: canStart ? DossedartTokens.bg : Colors.white38,
                    letterSpacing: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: _vt(15, color: Colors.white60, letterSpacing: 3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

extension _BorderToBoxDecoration on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
