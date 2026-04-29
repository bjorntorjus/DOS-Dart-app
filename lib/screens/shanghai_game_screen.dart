import 'package:flutter/material.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../models/shanghai_engine.dart';
import '../services/app_settings.dart';
import '../services/battery_sampler.dart';
import '../services/elo_service.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/player_storage.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/tts_service.dart';
import '../utils/player_colors.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/player_avatar.dart';
import 'post_game_screen.dart';

class ShanghaiGameScreen extends StatefulWidget {
  final List<Player> players;
  final ShanghaiConfig config;

  const ShanghaiGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<ShanghaiGameScreen> createState() => _ShanghaiGameScreenState();
}

class _ShanghaiGameScreenState extends State<ShanghaiGameScreen> {
  late List<Player> players;
  late ShanghaiGameEngine engine;
  final GameLogger _log = GameLogger.instance;

  // Per-turn hit history for the dart-slot display.
  // Reset whenever a new turn starts. Length matches engine.dartNumber.
  final List<HitType> _turnHits = [];

  final MemeService _meme = MemeService();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;

  bool _midGamePlayerChanges = false;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  @override
  void initState() {
    super.initState();
    players = List<Player>.from(widget.players);
    engine = ShanghaiGameEngine(
      playerCount: players.length,
      targetEnd: widget.config.targetEnd,
    );
    _log.logGameStart(
      gameMode: 'Shanghai',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {'targetEnd': widget.config.targetEnd},
    );
    BatterySampler.instance.start('Shanghai');
    _meme.init();
    AppSettings.getMemeEnabled().then((v) {
      if (mounted) setState(() => _memeEnabled = v);
    });
    AppSettings.getMemeOffensive().then((v) {
      if (mounted) setState(() => _offensiveEnabled = v);
    });
    TtsService.instance.init().then((_) {
      if (mounted) setState(() => _ttsEnabled = TtsService.instance.enabled);
    });
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  int _multiplierFor(HitType type) => switch (type) {
        HitType.single => 1,
        HitType.double_ => 2,
        HitType.triple => 3,
        HitType.miss => 0,
      };

  String _logLabelForHit(HitType type, int target) {
    switch (type) {
      case HitType.single:
        return 'S$target';
      case HitType.double_:
        return 'D$target';
      case HitType.triple:
        return 'T$target';
      case HitType.miss:
        return 'miss';
    }
  }

  String _spokenForHit(HitType type, int target) {
    switch (type) {
      case HitType.single:
        return '$target';
      case HitType.double_:
        return 'double $target';
      case HitType.triple:
        return 'triple $target';
      case HitType.miss:
        return 'miss';
    }
  }

  void _onHit(HitType type) {
    if (engine.gameOver) return;
    final playerIdx = engine.currentPlayerIndex;
    final dart = engine.dartNumber;
    final target = engine.currentTarget;
    final scoreBefore = engine.totalScores[playerIdx];
    final wasTurnStart = dart == 0;

    setState(() {
      engine.recordThrow(type);
      _turnHits.add(type);
    });

    final scoreAfter = engine.totalScores[playerIdx];
    final pointsDelta = scoreAfter - scoreBefore;
    final logLabel = _logLabelForHit(type, target);

    _log.logThrow(
      roundNumber: engine.currentRound,
      playerIndex: playerIdx,
      label: logLabel,
      points: pointsDelta,
      scoreBefore: scoreBefore,
      scoreAfter: scoreAfter,
      dartNumber: dart,
    );

    final dartThrow = DartThrow(
      playerIndex: playerIdx,
      segment: type == HitType.miss ? 0 : target,
      multiplier: _multiplierFor(type),
      points: pointsDelta,
      scoreBefore: scoreBefore,
      turnNumber: dart,
      scoreAtStartOfTurn: wasTurnStart ? scoreBefore : (scoreBefore - 0),
      roundNumber: engine.currentRound,
    );

    // Play core sound (miss/nice) before meme so meme can mark and skip TTS.
    if (type == HitType.miss) {
      SoundService.instance.play('miss/miss');
    } else {
      SoundService.instance.play('nice/nice');
    }

    final memeTriggered = _meme.onThrow(dartThrow);
    if (!memeTriggered && _ttsEnabled) {
      TtsService.instance.speak(_spokenForHit(type, target));
    }

    // Did the engine just advance to the next turn?
    final turnEnded = engine.dartNumber == 0;
    if (turnEnded) {
      _meme.onTurnEnd();
      _turnHits.clear();
    }

    if (engine.gameOver) {
      _onGameEnd();
    }
  }

  Future<void> _onGameEnd() async {
    final ranking = _rankPlayers();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();

    await _updateStats(ranking);
    if (!mounted) return;
    _showPostGame(ranking);
  }

  Future<void> _updateStats(List<int> ranking) async {
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < ranking.length; rank++) {
      final idx = ranking[rank];
      if (rank > 0 &&
          engine.totalScores[idx] == engine.totalScores[ranking[rank - 1]]) {
        placements[idx] = placements[ranking[rank - 1]];
      } else {
        placements[idx] = rank + 1;
      }
    }

    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      if (engine.isSkipped(pi)) continue;
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'max:bestScore': engine.totalScores[pi],
        'totalScore': engine.totalScores[pi],
        'totalGames': 1,
      };
    }

    if (!_midGamePlayerChanges) {
      EloService.updateRatings(
        playerIds: players.map((p) => p.savedPlayerId).toList(),
        placements: placements,
        savedPlayers: savedPlayers,
      );
    }

    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }

    StatsRecorder.recordGame(
      gameMode: 'shanghai',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
    );

    if (!_midGamePlayerChanges) {
      await PlayerStorage.savePlayers(savedPlayers);
    }
  }

  void _showPostGame(List<int> ranking) {
    final results = <PlayerResult>[];
    for (int rank = 0; rank < ranking.length; rank++) {
      final i = ranking[rank];
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: rank + 1,
        stats: {'score': engine.totalScores[i]},
        ratingBefore: players[i].savedPlayerId != null
            ? _ratingsBefore[players[i].savedPlayerId!]
            : null,
        ratingAfter: players[i].savedPlayerId != null
            ? _ratingsAfter[players[i].savedPlayerId!]
            : null,
      ));
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PostGameScreen(
          result: GameResult(gameMode: 'shanghai', results: results),
        ),
      ),
    );
  }

  List<int> _rankPlayers() {
    final indices = List<int>.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    indices.sort((a, b) => engine.totalScores[b].compareTo(engine.totalScores[a]));
    if (engine.isInstantShanghai && engine.winnerIndex != null) {
      indices.remove(engine.winnerIndex!);
      indices.insert(0, engine.winnerIndex!);
    }
    return indices;
  }

  void _onUndo() {
    if (engine.gameOver) return;
    setState(() {
      engine.undo();
      if (_turnHits.isNotEmpty) {
        _turnHits.removeLast();
      }
    });
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.totalScores[engine.currentPlayerIndex],
      roundNumber: engine.currentRound,
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('All progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  void _openPlayerManagement() {
    showMidGamePlayerSheet(
      context: context,
      players: players,
      isRemoved: (i) => engine.isSkipped(i),
      gameOver: engine.gameOver,
      colorFor: avatarColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    int avgScore = 0;
    if (activeIndices.isNotEmpty) {
      avgScore = (activeIndices
                  .map((i) => engine.totalScores[i])
                  .reduce((a, b) => a + b) /
              activeIndices.length)
          .round();
    }
    setState(() {
      _midGamePlayerChanges = true;
      players.add(Player(
        name: sp.name,
        score: avgScore,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer(initialScore: avgScore);
    });
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content: const Text('Rating will not be updated for this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _midGamePlayerChanges = true;
                final wasCurrent = engine.currentPlayerIndex == playerIndex;
                engine.removePlayer(playerIndex);
                if (wasCurrent) _turnHits.clear();
                if (engine.gameOver) {
                  _onGameEnd();
                }
              });
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showMemeFrequencyDialog() {
    int currentFreq = _meme.frequency;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Meme frequency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: currentFreq.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _freqLabel(currentFreq),
                onChanged: (v) {
                  setDialogState(() => currentFreq = v.round());
                },
              ),
              Text(_freqLabel(currentFreq),
                  style: TextStyle(color: Colors.grey[400])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _meme.setFrequency(currentFreq);
                AppSettings.setMemeFrequency(currentFreq);
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  String _freqLabel(int freq) {
    if (freq == 1) return 'Rare';
    if (freq <= 3) return 'Low';
    if (freq <= 6) return 'Normal';
    if (freq <= 8) return 'Often';
    return 'Always';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shanghai'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
          tooltip: 'Exit',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: engine.gameOver ? null : _openPlayerManagement,
            tooltip: 'Manage players',
          ),
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              await TtsService.instance.setEnabled(!_ttsEnabled);
              setState(() => _ttsEnabled = TtsService.instance.enabled);
            },
            tooltip: 'Speech',
          ),
          IconButton(
            icon: Text(_memeEnabled ? '🤡' : '🤐',
                style: const TextStyle(fontSize: 22)),
            onPressed: () {
              setState(() => _memeEnabled = !_memeEnabled);
              AppSettings.setMemeEnabled(_memeEnabled);
              _meme.setEnabled(_memeEnabled);
            },
            tooltip: 'Meme sounds',
          ),
          if (_memeEnabled) ...[
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showMemeFrequencyDialog,
              tooltip: 'Meme frequency',
            ),
            IconButton(
              icon: Icon(_offensiveEnabled
                  ? Icons.whatshot
                  : Icons.whatshot_outlined),
              onPressed: () {
                setState(() => _offensiveEnabled = !_offensiveEnabled);
                AppSettings.setMemeOffensive(_offensiveEnabled);
                _meme.setOffensive(_offensiveEnabled);
              },
              tooltip: 'Offensive sounds',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: engine.gameOver ? null : _onUndo,
            tooltip: 'Undo',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScoreboard(),
          const SizedBox(height: 8),
          _buildTurnIndicator(),
          const SizedBox(height: 8),
          _buildDartSlots(),
          const Spacer(),
          _buildActionButtons(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(players.length, (i) {
          final isActive = i == engine.currentPlayerIndex && !engine.gameOver;
          final isRemoved = engine.isSkipped(i);
          final col = Column(
            children: [
              PlayerAvatar(
                avatarPath: players[i].avatarPath,
                name: players[i].name,
                radius: 22,
                backgroundColor: avatarColor(i),
              ),
              const SizedBox(height: 4),
              Text(
                players[i].name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal),
              ),
              Text(
                '${engine.totalScores[i]}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ],
          );
          return Opacity(
            opacity: isRemoved ? 0.4 : 1.0,
            child: ActivePlayerHighlight(
              isActive: isActive,
              child: col,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTurnIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Round ${engine.currentRound + 1} of ${widget.config.targetEnd} — Target: ${engine.currentTarget}',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDartSlots() {
    final target = engine.currentTarget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (i) {
          final hit = i < _turnHits.length ? _turnHits[i] : null;
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == 2 ? 0 : 4),
              child: _dartSlot(i + 1, hit, target),
            ),
          );
        }),
      ),
    );
  }

  Widget _dartSlot(int dartNum, HitType? hit, int target) {
    final filled = hit != null;
    final label = hit == null
        ? '–'
        : hit == HitType.miss
            ? 'Miss'
            : _logLabelForHit(hit, target);
    final color = filled
        ? (hit == HitType.miss
            ? Theme.of(context).colorScheme.surfaceContainer
            : Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.surfaceContainer;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 1.0 : 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Text('Dart $dartNum',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _bigButton('${engine.currentTarget}',
                      () => _onHit(HitType.single),
                      Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 8),
              Expanded(
                  child: _bigButton('D${engine.currentTarget}',
                      () => _onHit(HitType.double_),
                      Theme.of(context).colorScheme.secondary)),
              const SizedBox(width: 8),
              Expanded(
                  child: _bigButton('T${engine.currentTarget}',
                      () => _onHit(HitType.triple),
                      Theme.of(context).colorScheme.tertiary)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onHit(HitType.miss),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Miss',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap, Color color) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
