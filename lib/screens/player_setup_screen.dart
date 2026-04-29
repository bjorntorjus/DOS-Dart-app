import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/player.dart';
import '../models/game_mode.dart';
import '../models/game_config.dart';
import '../models/saved_player.dart';
import '../services/player_storage.dart';
import '../services/app_settings.dart';
import '../utils/player_colors.dart';
import '../widgets/player_avatar.dart';
import 'game_screen.dart';
import 'around_the_clock_game_screen.dart';
import 'halve_it_game_screen.dart';
import 'cricket_game_screen.dart';
import 'killer_game_screen.dart';
import 'shanghai_game_screen.dart';

class PlayerSetupScreen extends StatefulWidget {
  final GameMode gameMode;
  final int? startingScore; // only for X01

  const PlayerSetupScreen({
    super.key,
    required this.gameMode,
    this.startingScore,
  });

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  List<SavedPlayer> _savedPlayers = [];
  final List<SavedPlayer> _selectedPlayers = [];
  bool _isLoading = true;

  // X01 options
  String _masterOut = 'none'; // 'none', 'double', 'master'
  bool _handicap = false;
  bool _noBust = false;
  double _handicapScale = AppSettings.defaultHandicapScale;

  // Cricket options
  bool _cricketIsRandom = false;
  bool _cricketIsOpen = false;
  int _cricketTargetCount = 7;
  bool _cricketIncludeBull = true;
  bool _cricketIsCutthroat = false;

  // Around the Clock options
  bool _clockIncludeBull = false;
  bool _clockCountMultiples = true;
  bool _clockReverse = false;

  // Killer options
  bool _killerThrowToPick = true;
  int _killerLives = 3;
  bool _killerMultiplyHits = false;
  bool _killerShields = false;
  bool _killerSuicide = false;

  // Player order
  bool _randomizeOrder = true;

  // Halve It options
  bool _halveItIsRandom = false;
  int _halveItRoundCount = 9;
  bool _halveItIncludeDouble = true;
  bool _halveItIncludeTriple = true;
  bool _halveItIncludeBull = true;

  // Shanghai options
  int _shanghaiTargetEnd = 7;

  int get _minPlayers {
    switch (widget.gameMode) {
      case GameMode.killer:
        return 3;
      case GameMode.aroundTheClock:
      case GameMode.halveIt:
      case GameMode.shanghai:
        return 1;
      default:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPlayers();
  }

  Future<void> _loadSavedPlayers() async {
    final players = await PlayerStorage.loadPlayers();
    players.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final scale = await AppSettings.getHandicapScale();
    setState(() {
      _savedPlayers = players;
      _handicapScale = scale;
      _isLoading = false;
    });
    // Auto-open player selection on first entry
    if (mounted && _selectedPlayers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPlayers.isEmpty) _addPlayer();
      });
    }
  }

  void _addPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final available = _savedPlayers
              .where((sp) => !_selectedPlayers.any((sel) => sel.id == sp.id))
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Add players (${_selectedPlayers.length} selected)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreatePlayerDialog();
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (available.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'All players have been added.\nCreate a new player if needed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final sp = available[i];
                        return ListTile(
                          leading: PlayerAvatar(
                            avatarPath: sp.avatarPath,
                            name: sp.name,
                            radius: 20,
                          ),
                          title: Text(sp.name),
                          subtitle: Text(
                            'Rating: ${sp.rating.round()} | '
                            'Games: ${sp.gamesPlayed} | '
                            'Avg: ${sp.averageTurnScore.toStringAsFixed(1)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green, size: 28),
                            onPressed: () {
                              setState(() => _selectedPlayers.add(sp));
                              setSheetState(() {}); // refresh sheet to remove added player
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreatePlayerDialog() async {
    final nameController = TextEditingController();
    String? avatarPath;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final path = await _pickImage();
                  if (path != null) {
                    setDialogState(() => avatarPath = path);
                  }
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      avatarPath != null ? FileImage(File(avatarPath!)) : null,
                  child: avatarPath == null
                      ? const Icon(Icons.add_a_photo, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim();
    nameController.dispose();
    if (name.isEmpty) return;

    final saved = await PlayerStorage.addPlayer(name);

    // If an image was picked, save it as the avatar
    if (avatarPath != null) {
      final dir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${dir.path}/avatars');
      if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);

      final ext = p.extension(avatarPath!);
      final dest = '${avatarDir.path}/${saved.id}$ext';
      await File(avatarPath!).copy(dest);

      saved.avatarPath = dest;
      await PlayerStorage.savePlayers([..._savedPlayers, saved]);
    }

    setState(() {
      _savedPlayers.add(saved);
      _selectedPlayers.add(saved);
    });
  }

  Future<String?> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    return image?.path;
  }

  void _showPlayerProfile(SavedPlayer sp) {
    final nameController = TextEditingController(text: sp.name);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Player profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final imagePath = await _pickImage();
                    if (imagePath == null) return;

                    final dir = await getApplicationDocumentsDirectory();
                    final avatarDir = Directory('${dir.path}/avatars');
                    if (!avatarDir.existsSync()) {
                      avatarDir.createSync(recursive: true);
                    }

                    final ext = p.extension(imagePath);
                    final dest = '${avatarDir.path}/${sp.id}$ext';
                    await File(imagePath).copy(dest);

                    sp.avatarPath = dest;
                    await PlayerStorage.savePlayers(_savedPlayers);
                    setDialogState(() {});
                    setState(() {});
                  },
                  child: Stack(
                    children: [
                      PlayerAvatar(
                        avatarPath: sp.avatarPath,
                        name: sp.name,
                        radius: 40,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                // Stats
                _profileStat('Rating', sp.rating.round().toString()),
                _profileStat('Games played', sp.gamesPlayed.toString()),
                _profileStat(
                  'Win rate',
                  '${(sp.winRate * 100).toStringAsFixed(0)}%',
                ),
                _profileStat(
                  'Avg turn score',
                  sp.averageTurnScore.toStringAsFixed(1),
                ),
                _profileStat(
                  'Best turn',
                  sp.highestTurnScore.toString(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != sp.name) {
                  sp.name = newName;
                  await PlayerStorage.savePlayers(_savedPlayers);
                  setState(() {});
                }
                nameController.dispose();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(String label, String value) {
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

  void _removePlayer(int index) {
    setState(() => _selectedPlayers.removeAt(index));
  }

  int _handicappedScore(String playerId) {
    final baseScore = widget.startingScore ?? 0;
    if (!_handicap) return baseScore;
    final sp = _savedPlayers.where((p) => p.id == playerId).firstOrNull;
    if (sp == null) return baseScore;
    final adjustment = ((sp.rating - 1200) * _handicapScale).round();
    final score = baseScore + adjustment;
    final minScore = _masterOut == 'double'
        ? 101
        : _masterOut == 'master'
            ? 61
            : 2;
    return score.clamp(minScore, 9999);
  }

  List<Player> _buildPlayers() {
    return _selectedPlayers
        .map((sp) => Player(
              name: sp.name,
              score: _handicappedScore(sp.id),
              savedPlayerId: sp.id,
              avatarPath: sp.avatarPath,
            ))
        .toList();
  }

  void _startGame() {
    if (_selectedPlayers.length < _minPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need at least $_minPlayers players'),
        ),
      );
      return;
    }

    final players = _buildPlayers();
    if (_randomizeOrder) players.shuffle(Random());

    Widget screen;
    switch (widget.gameMode) {
      case GameMode.x01:
        screen = GameScreen(
          players: players,
          masterOut: _masterOut,
          startingScore: widget.startingScore!,
          handicap: _handicap,
          noBust: _noBust,
        );
      case GameMode.cricket:
        screen = CricketGameScreen(
          players: players,
          config: CricketConfig(
            isRandom: _cricketIsRandom,
            isOpen: _cricketIsOpen,
            targetCount: _cricketTargetCount,
            includeBull: _cricketIncludeBull,
            isCutthroat: _cricketIsCutthroat,
          ),
        );
      case GameMode.aroundTheClock:
        screen = AroundTheClockGameScreen(
          players: players,
          config: AroundTheClockConfig(
            includeBull: _clockIncludeBull,
            countMultiples: _clockCountMultiples,
            reverse: _clockReverse,
          ),
        );
      case GameMode.killer:
        screen = KillerGameScreen(
          players: players,
          config: KillerConfig(
            throwToPick: _killerThrowToPick,
            lives: _killerLives,
            multiplyHits: _killerMultiplyHits,
            shields: _killerShields,
            suicide: _killerSuicide,
          ),
        );
      case GameMode.halveIt:
        screen = HalveItGameScreen(
          players: players,
          config: HalveItConfig(
            isRandom: _halveItIsRandom,
            roundCount: _halveItRoundCount,
            includeDouble: _halveItIncludeDouble,
            includeTriple: _halveItIncludeTriple,
            includeBull: _halveItIncludeBull,
          ),
        );
      case GameMode.shanghai:
        screen = ShanghaiGameScreen(
          players: players,
          config: ShanghaiConfig(targetEnd: _shanghaiTargetEnd),
        );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  String get _title {
    if (widget.gameMode == GameMode.x01) {
      return '${widget.startingScore} - Setup';
    }
    return '${widget.gameMode.label} - Setup';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mode-specific options
                _buildModeOptions(),

                // Randomize player order toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.shuffle, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Randomize player order',
                            style: TextStyle(fontSize: 14)),
                      ),
                      Switch(
                        value: _randomizeOrder,
                        onChanged: (v) =>
                            setState(() => _randomizeOrder = v),
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                // Selected player list
                Expanded(
                  child: _selectedPlayers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Tap "Add player" to select players',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedPlayers.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final player =
                                  _selectedPlayers.removeAt(oldIndex);
                              _selectedPlayers.insert(newIndex, player);
                            });
                          },
                          itemBuilder: (context, index) {
                            final sp = _selectedPlayers[index];
                            return Card(
                              key: ValueKey(sp.id),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () => _showPlayerProfile(sp),
                                  child: PlayerAvatar(
                                    avatarPath: sp.avatarPath,
                                    name: sp.name,
                                    radius: 20,
                                    backgroundColor: avatarColor(index),
                                  ),
                                ),
                                title: GestureDetector(
                                  onTap: () => _showPlayerProfile(sp),
                                  child: Text(
                                    sp.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  'Rating: ${sp.rating.round()} | '
                                  'Games: ${sp.gamesPlayed}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _removePlayer(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Add player (secondary, outlined)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addPlayer,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: Text(
                          'Select players (${_selectedPlayers.length})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[300],
                        side: BorderSide(color: Colors.grey[600]!, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),

                // Start button (primary, prominent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedPlayers.length >= _minPlayers
                          ? _startGame
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('START GAME'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeOptions() {
    switch (widget.gameMode) {
      case GameMode.x01:
        return _optionsCard([
          ListTile(
            title: const Text('Out rule'),
            subtitle: Text(_masterOut == 'none'
                ? 'Straight out (no requirement)'
                : _masterOut == 'double'
                    ? 'Must finish on a double'
                    : 'Must finish on a double or triple'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'none', label: Text('Any')),
                ButtonSegment(value: 'double', label: Text('D')),
                ButtonSegment(value: 'master', label: Text('D/T')),
              ],
              selected: {_masterOut},
              onSelectionChanged: (v) =>
                  setState(() => _masterOut = v.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Handicap'),
            subtitle: const Text('Starting scores adjusted by rating'),
            value: _handicap,
            onChanged: (v) => setState(() => _handicap = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('No-bust mode'),
            subtitle: const Text('Going over score = finish; biggest overshoot wins ties'),
            value: _noBust,
            onChanged: (v) => setState(() => _noBust = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ]);

      case GameMode.cricket:
        return _optionsCard([
          SwitchListTile(
            title: const Text('Cutthroat'),
            subtitle: const Text(
              'Reverse scoring: hitting open numbers gives points to '
              'opponents who haven\'t closed them. Lowest score wins!'),
            value: _cricketIsCutthroat,
            onChanged: (v) => setState(() => _cricketIsCutthroat = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Open mode'),
            subtitle: const Text('All numbers 1-20 are valid targets'),
            value: _cricketIsOpen,
            onChanged: (v) => setState(() {
              _cricketIsOpen = v;
              if (v) _cricketIsRandom = false;
            }),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          if (!_cricketIsOpen) ...[
            SwitchListTile(
              title: const Text('Random numbers'),
              subtitle: const Text('Choose random targets instead of 15-20'),
              value: _cricketIsRandom,
              onChanged: (v) => setState(() => _cricketIsRandom = v),
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
            if (_cricketIsRandom)
              ListTile(
                title: Text('Number of targets: $_cricketTargetCount'),
                subtitle: Slider(
                  value: _cricketTargetCount.toDouble(),
                  min: 3,
                  max: 15,
                  divisions: 12,
                  label: '$_cricketTargetCount',
                  onChanged: (v) =>
                      setState(() => _cricketTargetCount = v.round()),
                ),
              ),
          ],
          SwitchListTile(
            title: const Text('Include Bull'),
            value: _cricketIncludeBull,
            onChanged: (v) => setState(() => _cricketIncludeBull = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ]);

      case GameMode.aroundTheClock:
        return _optionsCard([
          SwitchListTile(
            title: const Text('Include Bull'),
            subtitle: const Text('Bull as final target after 20'),
            value: _clockIncludeBull,
            onChanged: (v) => setState(() => _clockIncludeBull = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Count double/triple'),
            subtitle: const Text('Double = 2 hits, Triple = 3 hits'),
            value: _clockCountMultiples,
            onChanged: (v) => setState(() => _clockCountMultiples = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Reverse (20→1)'),
            subtitle: const Text('Start from 20, count down to 1'),
            value: _clockReverse,
            onChanged: (v) => setState(() => _clockReverse = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ]);

      case GameMode.killer:
        return _optionsCard([
          SwitchListTile(
            title: const Text('Throw to pick number'),
            subtitle: Text(_killerThrowToPick
                ? 'Players throw a dart to pick'
                : 'Random numbers assigned'),
            value: _killerThrowToPick,
            onChanged: (v) => setState(() => _killerThrowToPick = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            title: Text('Number of lives: $_killerLives'),
            subtitle: Slider(
              value: _killerLives.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_killerLives',
              onChanged: (v) => setState(() => _killerLives = v.round()),
            ),
          ),
          SwitchListTile(
            title: const Text('Multiply hits'),
            subtitle: const Text('Double = 2× damage, Triple = 3×'),
            value: _killerMultiplyHits,
            onChanged: (v) => setState(() => _killerMultiplyHits = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Bull shields'),
            subtitle: const Text('Bull = 1 shield, Double bull = 3 shields'),
            value: _killerShields,
            onChanged: (v) => setState(() => _killerShields = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Suicide mode'),
            subtitle: const Text('Hitting your own number costs lives'),
            value: _killerSuicide,
            onChanged: (v) => setState(() => _killerSuicide = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ]);

      case GameMode.halveIt:
        return _optionsCard([
          SwitchListTile(
            title: const Text('Random rounds'),
            subtitle: const Text('Random order and targets'),
            value: _halveItIsRandom,
            onChanged: (v) => setState(() => _halveItIsRandom = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          if (_halveItIsRandom) ...[
            ListTile(
              title: Text('Number of rounds: $_halveItRoundCount'),
              subtitle: Slider(
                value: _halveItRoundCount.toDouble(),
                min: 5,
                max: 20,
                divisions: 15,
                label: '$_halveItRoundCount',
                onChanged: (v) =>
                    setState(() => _halveItRoundCount = v.round()),
              ),
            ),
            SwitchListTile(
              title: const Text('Include Double round'),
              value: _halveItIncludeDouble,
              onChanged: (v) =>
                  setState(() => _halveItIncludeDouble = v),
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
            SwitchListTile(
              title: const Text('Include Triple round'),
              value: _halveItIncludeTriple,
              onChanged: (v) =>
                  setState(() => _halveItIncludeTriple = v),
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
          ],
          SwitchListTile(
            title: const Text('Include Bull round'),
            value: _halveItIncludeBull,
            onChanged: (v) => setState(() => _halveItIncludeBull = v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ]);

      case GameMode.shanghai:
        return _optionsCard([
          ListTile(
            title: const Text('Target sequence'),
            subtitle: Text(_shanghaiTargetEnd == 7
                ? '1 to 7 (short)'
                : _shanghaiTargetEnd == 9
                    ? '1 to 9 (medium)'
                    : '1 to 20 (long)'),
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('1-7')),
                ButtonSegment(value: 9, label: Text('1-9')),
                ButtonSegment(value: 20, label: Text('1-20')),
              ],
              selected: {_shanghaiTargetEnd},
              onSelectionChanged: (v) =>
                  setState(() => _shanghaiTargetEnd = v.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ]);
    }
  }

  Widget _optionsCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
