import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/halve_it_round.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../models/game_result.dart';
import '../widgets/player_avatar.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../models/saved_player.dart';
import 'post_game_screen.dart';
import '../services/battery_sampler.dart';

class HalveItGameScreen extends StatefulWidget {
  final List<Player> players;
  final HalveItConfig config;

  const HalveItGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<HalveItGameScreen> createState() => _HalveItGameScreenState();
}

class _HalveItGameScreenState extends State<HalveItGameScreen> {
  late List<Player> players;
  late List<HalveItRound> rounds;
  late List<int> totalScores;
  late List<List<int?>> roundScores; // [roundIndex][playerIndex], null = not played yet, negative = halved
  int currentRoundIndex = 0;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  int turnPoints = 0; // points accumulated this turn
  bool turnHasHit = false; // whether any dart hit the target this turn
  List<DartThrow> throwHistory = [];
  bool gameOver = false;
  String? lastThrowLabel;

  // Undo data per throw
  final List<_HalveItUndoData> _undoStack = [];
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final ScrollController _scoreboardController = ScrollController();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;
  bool _missSoundPlayed = false;
  int _consecutiveMisses = 0;
  String? _pendingVideoEvent;

  static const double _playerCardHeight = 64.0;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};

  @override
  void initState() {
    super.initState();
    players = widget.players;
    rounds = widget.config.generateRounds();
    totalScores = List.filled(players.length, 40, growable: true);
    roundScores = List.generate(rounds.length,
        (_) => List<int?>.filled(players.length, null, growable: true));
    for (final p in players) {
      p.score = 40;
    }
    _announcer.init();
    _meme.init();
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    _ttsEnabled = TtsService.instance.enabled;
    _log.logGameStart(
      gameMode: 'Splitscore',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 40),
      config: {
        'rounds': rounds.map((r) => r.label).toList(),
        'isRandom': widget.config.isRandom,
      },
    );
    BatterySampler.instance.start('HalveIt');
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    _scoreboardController.dispose();
    super.dispose();
  }

  void _scrollToCurrentPlayer() {
    if (!_scoreboardController.hasClients) return;
    final maxScroll = _scoreboardController.position.maxScrollExtent;
    final targetOffset = (currentPlayerIndex * _playerCardHeight -
            _playerCardHeight)
        .clamp(0.0, maxScroll);
    _scoreboardController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onDartHit(int segment, int multiplier) async {
    if (gameOver) return;

    final round = rounds[currentRoundIndex];
    final points = round.pointsFor(segment, multiplier);
    final hit = round.isHit(segment, multiplier);

    final dartThrow = DartThrow(
      playerIndex: currentPlayerIndex,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: totalScores[currentPlayerIndex],
      turnNumber: dartsInTurn,
      scoreAtStartOfTurn: totalScores[currentPlayerIndex],
    );

    // Save undo data
    final scoreBefore = totalScores[currentPlayerIndex];
    final dartNum = dartsInTurn;
    final roundNum = currentRoundIndex + 1;
    final pIdx = currentPlayerIndex;

    _undoStack.add(_HalveItUndoData(
      roundIndex: currentRoundIndex,
      playerIndex: currentPlayerIndex,
      dartsInTurn: dartsInTurn,
      turnPoints: turnPoints,
      turnHasHit: turnHasHit,
      totalScoreBefore: totalScores[currentPlayerIndex],
      roundScoreBefore: roundScores[currentRoundIndex][currentPlayerIndex],
    ));

    // Pre-roll video dice before setState
    final vc = _meme.frequencyChance;
    final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;

    // Track consecutive misses for pending video event
    if (segment == 0) {
      _consecutiveMisses++;
      if (_consecutiveMisses >= 3) {
        _pendingVideoEvent ??= 'three_misses';
        _consecutiveMisses = 0;
      }
    } else {
      _consecutiveMisses = 0;
    }

    int? turnTotalForVideo;
    bool isTurnEnd = false;

    setState(() {
      throwHistory.add(dartThrow);

      if (hit) {
        turnPoints += points;
        turnHasHit = true;
        lastThrowLabel = '${dartThrow.label} ✓ (+$points)';
        _announcer.announceThrow(dartThrow.spokenLabel);
      } else {
        lastThrowLabel = segment == 0 ? 'Miss' : dartThrow.label;
        if (!(segment == 0 && _missSoundPlayed)) {
          _announcer.announceThrow(segment == 0 ? 'Miss' : dartThrow.spokenLabel);
        }
      }

      _meme.onThrow(dartThrow, remainingScore: totalScores[currentPlayerIndex] + turnPoints);
      dartsInTurn++;
      if (dartsInTurn >= 3) {
        isTurnEnd = true;
        turnTotalForVideo = turnPoints;
        if (turnTotalForVideo! >= 120) {
          _pendingVideoEvent ??= 'high_round';
        }
        if (_pendingVideoEvent != null && videoRoll) {
          _meme.markSoundPlayed();
        }
        _meme.onTurnEnd();
        _finishTurn();
      }
    });

    _log.logThrow(
      roundNumber: roundNum,
      playerIndex: pIdx,
      label: dartThrow.label,
      points: points,
      scoreBefore: scoreBefore,
      scoreAfter: totalScores[pIdx],
      dartNumber: dartNum,
      extra: 'target=${round.label} ${hit ? "HIT" : "MISS"}',
    );

    // Video triggers at turn end only
    if (isTurnEnd && _pendingVideoEvent != null && videoRoll) {
      await VideoService.instance.showRandomFromFolder(context, _pendingVideoEvent!, chance: 1);
      _pendingVideoEvent = null;
      if (!mounted) return;
    }
    _pendingVideoEvent = null;

    if (gameOver) {
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _updateStats().then((_) => _showPostGame());
    }
  }

  void _finishTurn() {
    final pi = currentPlayerIndex;
    final roundNum = currentRoundIndex + 1;
    if (turnHasHit) {
      totalScores[pi] += turnPoints;
      roundScores[currentRoundIndex][pi] = turnPoints;
      _announcer.announceScore('${totalScores[pi]}');
    } else {
      // Halve the score!
      final before = totalScores[pi];
      final halved = totalScores[pi] ~/ 2;
      final lost = totalScores[pi] - halved;
      totalScores[pi] = halved;
      roundScores[currentRoundIndex][pi] = -lost; // negative = halved
      _announcer.announceGameEvent('Halved');
      _log.log('HALVED P$pi(${players[pi].name}) score $before → $halved');
    }
    players[pi].score = totalScores[pi];

    // Next player or next round
    dartsInTurn = 0;
    turnPoints = 0;
    turnHasHit = false;

    // Find next active (non-removed) player in rotation
    int next = currentPlayerIndex + 1;
    while (next < players.length && _removedPlayerIndices.contains(next)) {
      next++;
    }
    if (next >= players.length) {
      // End of round
      if (currentRoundIndex == rounds.length - 1) {
        gameOver = true;
        return;
      }
      currentRoundIndex++;
      // Find first active player in new round
      int first = 0;
      while (first < players.length && _removedPlayerIndices.contains(first)) {
        first++;
      }
      if (first >= players.length) {
        gameOver = true;
        return;
      }
      currentPlayerIndex = first;
    } else {
      currentPlayerIndex = next;
    }
    _log.logAdvance(
      roundNumber: roundNum,
      fromIndex: pi,
      toIndex: currentPlayerIndex,
      toName: players[currentPlayerIndex].name,
      toScore: totalScores[currentPlayerIndex],
      reason: currentPlayerIndex == 0 ? 'new round ${currentRoundIndex + 1}' : null,
    );
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
  }

  void _onMiss() {
    _missSoundPlayed = false;
    if (_memeEnabled) {
      _missSoundPlayed = SoundService.instance.playRandomMaybe([
        'miss',
        if (_offensiveEnabled) 'miss/offensive',
      ], chance: _meme.frequencyChance);
      if (_missSoundPlayed && _meme.frequency < 10) {
        _meme.markSoundPlayed();
      }
    }
    _onDartHit(0, 0);
  }

  String _lastDartsLabel(int playerIndex) {
    final darts =
        throwHistory.where((t) => t.playerIndex == playerIndex).toList();
    if (darts.isEmpty) return '';
    final last3 = darts.length <= 3 ? darts : darts.sublist(darts.length - 3);
    return last3.map((t) => t.shortLabel).join(' \u00b7 ');
  }

  void _undo() {
    if (throwHistory.isEmpty || _undoStack.isEmpty) return;
    final undoneThrow = throwHistory.last;
    final undoData = _undoStack.last;
    _announcer.announceGameEvent('Back');

    setState(() {
      throwHistory.removeLast();
      final data = _undoStack.removeLast();
      currentRoundIndex = data.roundIndex;
      currentPlayerIndex = data.playerIndex;
      dartsInTurn = data.dartsInTurn;
      turnPoints = data.turnPoints;
      turnHasHit = data.turnHasHit;
      totalScores[data.playerIndex] = data.totalScoreBefore;
      roundScores[data.roundIndex][data.playerIndex] = data.roundScoreBefore;
      players[data.playerIndex].score = data.totalScoreBefore;
      gameOver = false;
      lastThrowLabel = null;
    });

    _log.logUndo(
      playerIndex: undoData.playerIndex,
      playerName: players[undoData.playerIndex].name,
      throwLabel: undoneThrow.label,
      scoreRestored: undoData.totalScoreBefore,
      roundNumber: undoData.roundIndex + 1,
    );
  }

  Future<void> _updateStats() async {
    if (_midGamePlayerChanges) {
      await StatsRecorder.recordMidGameChanges(
        joinedIds: _joinedMidGameIds,
        leftIds: _leftMidGameIds,
      );
      return;
    }
    await _updateStatsInternal();
  }

  Future<void> _updateStatsInternal() async {
    final savedPlayers = await PlayerStorage.loadPlayers();

    // Capture ratings before update
    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    // Find winner (highest score)
    int bestScore = -1;
    int winnerIdx = 0;
    for (int i = 0; i < players.length; i++) {
      if (totalScores[i] > bestScore) {
        bestScore = totalScores[i];
        winnerIdx = i;
      }
    }

    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];
      sp.gamesPlayed++;
      if (pi == winnerIdx) sp.gamesWon++;

      // Turn stats: each round is a "turn"
      for (int ri = 0; ri < rounds.length; ri++) {
        final score = roundScores[ri][pi];
        if (score != null) {
          sp.totalTurns++;
          final turnScore = score < 0 ? 0 : score;
          sp.totalTurnScore += turnScore;
          if (turnScore > sp.highestTurnScore) {
            sp.highestTurnScore = turnScore;
          }
        }
      }
    }
    // Rank by total score (higher = better placement)
    final sorted = List.generate(players.length, (i) => i)
      ..sort((a, b) => totalScores[b].compareTo(totalScores[a]));
    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < sorted.length; rank++) {
      if (rank > 0 && totalScores[sorted[rank]] == totalScores[sorted[rank - 1]]) {
        placements[sorted[rank]] = placements[sorted[rank - 1]]; // tie
      } else {
        placements[sorted[rank]] = rank + 1;
      }
    }
    // Compute per-player Halve It stats
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;

      int roundsHit = 0;
      int totalRoundsPlayed = 0;
      int biggestHalving = 0;
      int bestRound = 0;
      int halvings = 0;
      final playerDarts = throwHistory.where((t) => t.playerIndex == pi).toList();
      int totalDarts = playerDarts.length;
      int misses = 0;

      for (int ri = 0; ri < rounds.length; ri++) {
        final score = roundScores[ri][pi];
        if (score == null) continue;
        totalRoundsPlayed++;
        if (score >= 0) {
          roundsHit++;
          if (score > bestRound) bestRound = score;
        } else {
          halvings++;
          // Negative score = halved, abs is the amount lost
          if (score.abs() > biggestHalving) biggestHalving = score.abs();
        }
      }

      for (final t in playerDarts) {
        if (t.segment == 0) misses++;
      }

      modeCounters[playerId] = {
        'max:bestScore': totalScores[pi],
        'totalScore': totalScores[pi],
        'totalGames': 1,
        'roundsHit': roundsHit,
        'totalRounds': totalRoundsPlayed,
        'max:biggestHalving': biggestHalving,
        'totalDarts': totalDarts,
        'misses': misses,
        'bestRound': bestRound,
        'halvings': halvings,
      };
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
    );

    // Capture ratings after update (before recording history)
    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }

    StatsRecorder.recordGame(
      gameMode: 'halveIt',
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

  void _showPostGame() async {
    // Rank players by total score descending
    final indexed = List.generate(players.length, (i) => i);
    indexed.sort((a, b) => totalScores[b].compareTo(totalScores[a]));

    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: indexed,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();

    final results = <PlayerResult>[];
    for (int rank = 0; rank < indexed.length; rank++) {
      final i = indexed[rank];
      // Count halved rounds
      int halvedCount = 0;
      for (int r = 0; r < roundScores.length; r++) {
        if ((roundScores[r][i] ?? 0) < 0) halvedCount++;
      }
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: rank + 1,
        stats: {'score': totalScores[i], 'halved': halvedCount},
        ratingBefore: players[i].savedPlayerId != null ? _ratingsBefore[players[i].savedPlayerId!] : null,
        ratingAfter: players[i].savedPlayerId != null ? _ratingsAfter[players[i].savedPlayerId!] : null,
      ));
    }
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PostGameScreen(
        result: GameResult(gameMode: 'halveIt', results: results),
      )),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo');
      _undo();
    } else {
      _log.logPostGame(action: 'exit');
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = players[currentPlayerIndex];
    final currentRound = rounds[currentRoundIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Splitscore - Round ${currentRoundIndex + 1}/${rounds.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: gameOver ? null : _openPlayerManagement,
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
            icon: Text(_memeEnabled ? '🤡' : '🤐', style: const TextStyle(fontSize: 22)),
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
              icon: Icon(_offensiveEnabled ? Icons.whatshot : Icons.whatshot_outlined),
              onPressed: () {
                setState(() => _offensiveEnabled = !_offensiveEnabled);
                AppSettings.setMemeOffensive(_offensiveEnabled);
                _meme.setOffensive(_offensiveEnabled);
              },
              tooltip: 'Offensive sounds',
            ),
          ],
          if (throwHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo,
              tooltip: 'Undo',
            ),
        ],
      ),
      body: Column(
        children: [
          // Current player + round target info
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentPlayer.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text('Dart ${dartsInTurn + 1} of 3',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                          const SizedBox(width: 8),
                          ...List.generate(3, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(
                                i < dartsInTurn
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                size: 10,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }),
                          if (turnPoints > 0) ...[
                            const SizedBox(width: 12),
                            Text('+$turnPoints',
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 14)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('Target',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                    Text(
                      currentRound.label,
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total: ${totalScores[currentPlayerIndex]}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Round indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: List.generate(rounds.length, (ri) {
                final isCurrent = ri == currentRoundIndex;
                final isDone = ri < currentRoundIndex;
                final isFuture = ri > currentRoundIndex;
                final hideLabel = isFuture && widget.config.isRandom;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isCurrent
                        ? Theme.of(context).colorScheme.tertiary.withAlpha(40)
                        : isDone
                            ? Colors.green.withAlpha(30)
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                    border: isCurrent
                        ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    hideLabel ? '?' : rounds[ri].label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.tertiary
                          : isDone
                              ? Colors.green
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Last throw label
          if (lastThrowLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Last: $lastThrowLabel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: lastThrowLabel!.contains('✓')
                          ? Colors.green
                          : Colors.white,
                    )),
              ),
            ),

          // Target buttons (uses remaining space)
          Expanded(child: _buildTargetButtons(currentRound)),

          // Back + Miss buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (throwHistory.isNotEmpty) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Back', style: TextStyle(fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Player scores (totals only)
          Container(
            constraints: BoxConstraints(
              maxHeight: _playerCardHeight * 3,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow)),
            ),
            child: ListView.builder(
              controller: _scoreboardController,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isCurrent = index == currentPlayerIndex && !gameOver;
                  final lastRoundScore = roundScores[currentRoundIndex][index];
                  final showRoundAnnotation = lastRoundScore != null && index < currentPlayerIndex;
                  final lastDarts = _lastDartsLabel(index);
                  final isRemoved = _removedPlayerIndices.contains(index);

                  return Opacity(
                    opacity: isRemoved ? 0.4 : 1.0,
                    child: Container(
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: isCurrent
                              ? Icon(Icons.arrow_right,
                                  color: Theme.of(context).colorScheme.primary, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        PlayerAvatar(
                          avatarPath: player.avatarPath,
                          name: player.name,
                          radius: 18,
                          backgroundColor: avatarColor(index),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (lastDarts.isNotEmpty)
                                Text(
                                  lastDarts,
                                  style: TextStyle(
                                      fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                                ),
                            ],
                          ),
                        ),
                        if (showRoundAnnotation)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              lastRoundScore < 0
                                  ? '✗ -${lastRoundScore.abs()}'
                                  : '+$lastRoundScore',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: lastRoundScore < 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        Text(
                          '${totalScores[index]}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetButtons(HalveItRound round) {
    if (gameOver) {
      return const Center(child: Text('Game Over', style: TextStyle(fontSize: 24)));
    }

    switch (round.type) {
      case HalveItRoundType.number:
        return _buildNumberButtons(round.targetNumber!);

      case HalveItRoundType.anyDouble:
        final buttons = <Widget>[];
        for (int i = 1; i <= 20; i++) {
          buttons.add(_compactButton(
              'D$i', () => _onDartHit(i, 2), Colors.orange[800]!));
        }
        buttons.add(_compactButton(
            'D-Bull', () => _onDartHit(25, 2), Colors.red[800]!));
        return _compactButtonGrid(buttons, includeMiss: true);

      case HalveItRoundType.anyTriple:
        final buttons = <Widget>[];
        for (int i = 1; i <= 20; i++) {
          buttons.add(_compactButton(
              'T$i', () => _onDartHit(i, 3), Colors.red[800]!));
        }
        return _compactButtonGrid(buttons, includeMiss: true);

      case HalveItRoundType.bull:
        return _buildNumberButtons(null); // null = Bull mode
    }
  }

  /// Big buttons for a specific target number (or Bull if n == null).
  Widget _buildNumberButtons(int? n) {
    final isBull = n == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hit buttons row
          Row(
            children: isBull
                ? [
                    Expanded(child: _scoreButton('S.Bull', '+25', () => _onDartHit(25, 1), Colors.blueGrey[700]!)),
                    const SizedBox(width: 10),
                    Expanded(child: _scoreButton('Bull', '+50', () => _onDartHit(25, 2), Colors.orange[800]!)),
                  ]
                : [
                    Expanded(child: _scoreButton('S$n', '+$n', () => _onDartHit(n, 1), Colors.blueGrey[700]!)),
                    const SizedBox(width: 10),
                    Expanded(child: _scoreButton('D$n', '+${n * 2}', () => _onDartHit(n, 2), Colors.orange[800]!)),
                    const SizedBox(width: 10),
                    Expanded(child: _scoreButton('T$n', '+${n * 3}', () => _onDartHit(n, 3), Colors.red[800]!)),
                  ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 62,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onMiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Miss',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreButton(String label, String points, VoidCallback onTap, Color color) {
    return SizedBox(
      height: 86,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(points, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _compactButton(String label, VoidCallback onTap, Color color) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _compactButtonGrid(List<Widget> buttons, {bool includeMiss = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final tileWidth =
                    (constraints.maxWidth - spacing * 3) / 4; // 4 per row
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  children: buttons
                      .map((b) => SizedBox(width: tileWidth, child: b))
                      .toList(),
                );
              },
            ),
          ),
          if (includeMiss) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onMiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Miss',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
          ],
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
                label: currentFreq == 1
                    ? 'Rare'
                    : currentFreq <= 3
                        ? 'Low'
                        : currentFreq <= 6
                            ? 'Normal'
                            : currentFreq <= 8
                                ? 'Often'
                                : 'Always',
                onChanged: (v) {
                  setDialogState(() => currentFreq = v.round());
                },
              ),
              Text(
                currentFreq == 1
                    ? 'Rare'
                    : currentFreq <= 3
                        ? 'Low'
                        : currentFreq <= 6
                            ? 'Normal'
                            : currentFreq <= 8
                                ? 'Often'
                                : 'Always',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
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

  void _openPlayerManagement() {
    showMidGamePlayerSheet(
      context: context,
      players: players,
      isRemoved: (i) => _removedPlayerIndices.contains(i),
      gameOver: gameOver,
      colorFor: avatarColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !_removedPlayerIndices.contains(i))
        .toList();
    final avgScore = activeIndices.isEmpty
        ? 40
        : (activeIndices.map((i) => totalScores[i]).reduce((a, b) => a + b) /
                activeIndices.length)
            .round();

    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: avgScore,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      totalScores.add(avgScore);
      // Backfill roundScores for rounds already played with null (skipped)
      for (int ri = 0; ri < rounds.length; ri++) {
        roundScores[ri].add(null);
      }
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
              final removed = players[playerIndex];
              setState(() {
                _midGamePlayerChanges = true;
                _removedPlayerIndices.add(playerIndex);
                if (removed.savedPlayerId != null) {
                  _leftMidGameIds.add(removed.savedPlayerId!);
                }
                if (playerIndex == currentPlayerIndex) {
                  dartsInTurn = 0;
                  _advanceToNextActive();
                }
              });
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _advanceToNextActive() {
    final start = currentPlayerIndex;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      if (currentPlayerIndex == start) break;
    } while (_removedPlayerIndices.contains(currentPlayerIndex));
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
}

class _HalveItUndoData {
  final int roundIndex;
  final int playerIndex;
  final int dartsInTurn;
  final int turnPoints;
  final bool turnHasHit;
  final int totalScoreBefore;
  final int? roundScoreBefore;

  _HalveItUndoData({
    required this.roundIndex,
    required this.playerIndex,
    required this.dartsInTurn,
    required this.turnPoints,
    required this.turnHasHit,
    required this.totalScoreBefore,
    required this.roundScoreBefore,
  });
}
