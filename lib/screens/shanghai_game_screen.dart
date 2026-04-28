import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
import '../models/player.dart';
import '../models/shanghai_engine.dart';
import '../services/battery_sampler.dart';
import '../services/elo_service.dart';
import '../services/game_logger.dart';
import '../services/player_storage.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/tts_service.dart';
import '../utils/player_colors.dart' show playerColor;
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
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  void _onHit(HitType type) {
    if (engine.gameOver) return;
    final playerIdx = engine.currentPlayerIndex;
    final dart = engine.dartNumber;
    final target = engine.currentTarget;
    final scoreBefore = engine.totalScores[playerIdx];

    setState(() {
      engine.recordThrow(type);
    });

    final scoreAfter = engine.totalScores[playerIdx];
    final label = _labelForHit(type, target);
    _log.logThrow(
      roundNumber: engine.currentRound,
      playerIndex: playerIdx,
      label: label,
      points: scoreAfter - scoreBefore,
      scoreBefore: scoreBefore,
      scoreAfter: scoreAfter,
      dartNumber: dart,
    );

    SoundService.instance.play(type == HitType.miss ? 'miss/miss' : 'nice/nice');
    if (TtsService.instance.enabled) {
      TtsService.instance.speak(label);
    }

    if (engine.gameOver) {
      _onGameEnd();
    }
  }

  String _labelForHit(HitType type, int target) {
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

    // Capture ratings before update
    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    // Build placements list (1-indexed, lower = better)
    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < ranking.length; rank++) {
      final idx = ranking[rank];
      if (rank > 0 && engine.totalScores[idx] == engine.totalScores[ranking[rank - 1]]) {
        placements[idx] = placements[ranking[rank - 1]]; // tie
      } else {
        placements[idx] = rank + 1;
      }
    }

    // Mode-specific counters
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'max:bestScore': engine.totalScores[pi],
        'totalScore': engine.totalScores[pi],
        'totalGames': 1,
      };
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
    );

    // Capture ratings after update
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

    await PlayerStorage.savePlayers(savedPlayers);
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
    final indices = List<int>.generate(players.length, (i) => i);
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
                backgroundColor: const Color(0xFFE53935)),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = engine.currentPlayerIndex < players.length
        ? players[engine.currentPlayerIndex]
        : players[0];
    return Scaffold(
      appBar: AppBar(
        title: Text('Shanghai — Target: ${engine.currentTarget}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
          tooltip: 'Exit',
        ),
        actions: [
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
          _buildTurnIndicator(p),
          const SizedBox(height: 8),
          _buildHitsDisplay(),
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
          return Column(
            children: [
              PlayerAvatar(
                avatarPath: players[i].avatarPath,
                name: players[i].name,
                radius: 22,
                backgroundColor: isActive
                    ? Theme.of(context).colorScheme.primary
                    : playerColor(i),
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
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTurnIndicator(Player p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '${p.name} — Round ${engine.currentRound + 1} of ${widget.config.targetEnd} — Dart ${engine.dartNumber + 1}/3',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHitsDisplay() {
    final s = engine.currentTurnHits.contains(HitType.single);
    final d = engine.currentTurnHits.contains(HitType.double_);
    final t = engine.currentTurnHits.contains(HitType.triple);
    Color chip(bool hit) =>
        hit ? Theme.of(context).colorScheme.primary : Colors.grey.shade700;
    Widget pill(String label, bool hit) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: chip(hit), borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill('S', s),
        const SizedBox(width: 8),
        pill('D', d),
        const SizedBox(width: 8),
        pill('T', t),
      ],
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
                  child: _bigButton('Single', () => _onHit(HitType.single),
                      const Color(0xFF43A047))),
              const SizedBox(width: 8),
              Expanded(
                  child: _bigButton('Double', () => _onHit(HitType.double_),
                      const Color(0xFF1E88E5))),
              const SizedBox(width: 8),
              Expanded(
                  child: _bigButton('Triple', () => _onHit(HitType.triple),
                      const Color(0xFFE53935))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onHit(HitType.miss),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Miss',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
        child:
            Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
