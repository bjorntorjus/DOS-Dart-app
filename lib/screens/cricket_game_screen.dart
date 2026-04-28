import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/video_service.dart';
import '../models/game_result.dart';
import '../widgets/player_avatar.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../models/saved_player.dart';
import 'post_game_screen.dart';

class CricketGameScreen extends StatefulWidget {
  final List<Player> players;
  final CricketConfig config;

  const CricketGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<CricketGameScreen> createState() => _CricketGameScreenState();
}

class _CricketGameScreenState extends State<CricketGameScreen> {
  /// Shared height for mark buttons and progress bars — guarantees equal sizing.

  late List<Player> players;
  late List<int> targets;
  late List<Map<int, int>> marks;
  late List<int> scores;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  List<DartThrow> throwHistory = [];
  int? winnerIndex;
  String? lastThrowLabel;
  List<int> finishedPlayers = [];
  bool _gameFullyOver = false;
  bool _statsRecorded = false;

  final List<_CricketUndoData> _undoStack = [];
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _missSoundPlayed = false;
  int _consecutiveMisses = 0;
  int _scoreAtStartOfTurn = 0;
  String? _pendingVideoEvent;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    targets = widget.config.generateTargets();
    marks = List.generate(
        players.length, (_) => {for (final t in targets) t: 0});
    scores = List.filled(players.length, 0, growable: true);
    for (final p in players) {
      p.score = 0;
    }
    _announcer.init();
    _meme.init();
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    _log.logGameStart(
      gameMode: widget.config.isCutthroat ? 'Cricket (Cutthroat)' : 'Cricket',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {
        'targets': targets.map((t) => t == 25 ? 'Bull' : '$t').toList(),
        if (widget.config.isCutthroat) 'cutthroat': true,
      },
    );
  }

  int get _roundNumber {
    if (throwHistory.isEmpty) return 1;
    final turnsForCurrentPlayer =
        throwHistory.where((t) => t.playerIndex == currentPlayerIndex).length;
    return (turnsForCurrentPlayer ~/ 3) + 1;
  }

  bool _isClosed(int target, int playerIndex) =>
      (marks[playerIndex][target] ?? 0) >= 3;

  bool _isClosedByAll(int target) {
    for (int i = 0; i < players.length; i++) {
      if (!_isClosed(target, i)) return false;
    }
    return true;
  }

  bool _allClosedByPlayer(int playerIndex) =>
      targets.every((t) => _isClosed(t, playerIndex));

  void _checkWinner() {
    for (int i = 0; i < players.length; i++) {
      if (finishedPlayers.contains(i)) continue;
      if (_allClosedByPlayer(i)) {
        bool canFinish = true;
        for (int j = 0; j < players.length; j++) {
          if (j == i || finishedPlayers.contains(j)) continue;
          if (widget.config.isCutthroat) {
            // Cutthroat: must have lowest (or tied) score to finish
            if (scores[j] < scores[i]) { canFinish = false; break; }
          } else {
            // Standard: must have highest (or tied) score to finish
            if (scores[j] > scores[i]) { canFinish = false; break; }
          }
        }
        if (canFinish) {
          finishedPlayers.add(i);
          final activePlayers = List.generate(players.length, (idx) => idx)
              .where((idx) => !finishedPlayers.contains(idx))
              .toList();
          if (activePlayers.length <= 1) {
            if (activePlayers.length == 1) finishedPlayers.add(activePlayers.first);
            winnerIndex = finishedPlayers.first;
            _gameFullyOver = true;
          } else {
            winnerIndex = finishedPlayers.first;
          }
          return;
        }
      }
    }
  }

  Future<void> _registerHit(int segment, int multiplier) async {
    if (finishedPlayers.contains(currentPlayerIndex)) return;

    final points = segment * multiplier;
    final roundNum = _roundNumber;
    final scoreBefore = scores[currentPlayerIndex];

    _undoStack.add(_CricketUndoData(
      playerIndex: currentPlayerIndex,
      dartsInTurn: dartsInTurn,
      marksBefore: {
        for (final t in targets) t: marks[currentPlayerIndex][t] ?? 0
      },
      scoresBefore: List.from(scores),
      finishedPlayersBefore: List.from(finishedPlayers),
    ));

    final dartThrow = DartThrow(
      playerIndex: currentPlayerIndex,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: scores[currentPlayerIndex],
      turnNumber: dartsInTurn,
      scoreAtStartOfTurn: scores[currentPlayerIndex],
    );

    // Pre-roll video dice and track per-dart events
    final vc = _meme.frequencyChance;
    final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;

    if (segment == 25 && multiplier == 2) _pendingVideoEvent ??= 'bullseye';
    if (segment == 0) {
      _consecutiveMisses++;
      if (_consecutiveMisses >= 3) {
        _pendingVideoEvent ??= 'three_misses';
        _consecutiveMisses = 0;
      }
    } else {
      _consecutiveMisses = 0;
    }

    bool isTurnEnd = false;

    setState(() {
      throwHistory.add(dartThrow);

      String? extraInfo;

      if (segment > 0 && targets.contains(segment)) {
        final currentMarks = marks[currentPlayerIndex][segment] ?? 0;
        final marksToAdd = multiplier == 0 ? 0 : multiplier;
        final newMarks = currentMarks + marksToAdd;
        final marksForClose = 3 - currentMarks;
        final closingMarks =
            marksToAdd.clamp(0, marksForClose.clamp(0, marksToAdd));
        final overflowMarks = marksToAdd - closingMarks;

        marks[currentPlayerIndex][segment] = newMarks;

        if (overflowMarks > 0) {
          bool allOthersClosed = true;
          for (int j = 0; j < players.length; j++) {
            if (j != currentPlayerIndex && !_isClosed(segment, j)) {
              allOthersClosed = false;
              break;
            }
          }
          if (!allOthersClosed) {
            final pts = segment * overflowMarks;
            if (widget.config.isCutthroat) {
              // Cutthroat: give points to opponents who haven't closed
              for (int j = 0; j < players.length; j++) {
                if (j != currentPlayerIndex && !_isClosed(segment, j) && !finishedPlayers.contains(j)) {
                  scores[j] += pts;
                  players[j].score = scores[j];
                }
              }
              extraInfo = 'cutthroat ${pts}pts to opponents marks=$newMarks';
            } else {
              scores[currentPlayerIndex] += pts;
              players[currentPlayerIndex].score = scores[currentPlayerIndex];
              extraInfo = 'scoring ${pts}pts marks=$newMarks';
            }
          } else {
            extraInfo = newMarks >= 3 ? 'closed ${segment == 25 ? "Bull" : "T$segment"} marks=$newMarks' : 'marks=$newMarks';
          }
        } else {
          extraInfo = newMarks >= 3 ? 'closed ${segment == 25 ? "Bull" : "T$segment"} marks=$newMarks' : 'marks=$newMarks';
        }

        final markStr = newMarks >= 3 ? '(Closed!)' : '($newMarks/3)';
        lastThrowLabel = '${dartThrow.label} $markStr';
        if (currentMarks < 3 && newMarks >= 3) {
          _announcer.announceGameEvent('Closed');
        } else {
          _announcer.announceThrow(dartThrow.spokenLabel);
        }
      } else {
        lastThrowLabel = segment == 0 ? 'Miss' : dartThrow.label;
        extraInfo = segment == 0 ? 'miss' : 'non-target';
        if (!(segment == 0 && _missSoundPlayed)) {
          _announcer.announceThrow(segment == 0 ? 'Miss' : dartThrow.spokenLabel);
        }
      }

      _log.logThrow(
        roundNumber: roundNum,
        playerIndex: currentPlayerIndex,
        label: dartThrow.label,
        points: scores[currentPlayerIndex] - scoreBefore,
        scoreBefore: scoreBefore,
        scoreAfter: scores[currentPlayerIndex],
        dartNumber: dartsInTurn,
        extra: extraInfo,
      );

      _meme.onThrow(dartThrow);
      dartsInTurn++;

      final wasFinished = finishedPlayers.length;
      _checkWinner();
      final playerJustFinished = finishedPlayers.length > wasFinished;

      if (playerJustFinished) {
        isTurnEnd = true;
        final finishedIdx = finishedPlayers.last;
        _log.logFinish(
          roundNumber: roundNum,
          playerIndex: finishedIdx,
          playerName: players[finishedIdx].name,
          details: 'score=${scores[finishedIdx]} placement=#${finishedPlayers.length}',
        );
        if (!_gameFullyOver) {
          // Intermediate finish — announce immediately; no winner video coming
          _announcer.announceWinner(players[finishedIdx].name);
        }
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
      } else if (dartsInTurn >= 3) {
        isTurnEnd = true;
        final turnTotal = scores[currentPlayerIndex] - _scoreAtStartOfTurn;
        if (turnTotal >= 120) _pendingVideoEvent ??= 'high_round';
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
        _advancePlayer();
      }
    });

    // Show video at turn end only
    if (isTurnEnd && _pendingVideoEvent != null && videoRoll) {
      await VideoService.instance.showRandomFromFolder(context, _pendingVideoEvent!, chance: 1);
    }
    if (isTurnEnd) _pendingVideoEvent = null;
    if (!mounted) return;

    if (_gameFullyOver && finishedPlayers.isNotEmpty) {
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(players[winnerIndex!].name);
      _showPostGame();
    } else if (finishedPlayers.contains(currentPlayerIndex) && !_gameFullyOver) {
      if (players.length <= 2) {
        _gameFullyOver = true;
      }
      _showPostGame();
    }
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
    _registerHit(0, 0);
  }

  void _advancePlayer() {
    final fromIndex = currentPlayerIndex;
    dartsInTurn = 0;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    } while (finishedPlayers.contains(currentPlayerIndex));
    _log.logAdvance(
      roundNumber: _roundNumber,
      fromIndex: fromIndex,
      toIndex: currentPlayerIndex,
      toName: players[currentPlayerIndex].name,
      toScore: scores[currentPlayerIndex],
      reason: 'turn complete',
    );
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    _scoreAtStartOfTurn = scores[currentPlayerIndex];
  }

  void _undo() {
    if (throwHistory.isEmpty || _undoStack.isEmpty) return;
    final lastThrow = throwHistory.last;
    _announcer.announceGameEvent('Back');
    setState(() {
      throwHistory.removeLast();
      final data = _undoStack.removeLast();
      finishedPlayers = List.from(data.finishedPlayersBefore);
      _gameFullyOver = false;
      currentPlayerIndex = data.playerIndex;
      dartsInTurn = data.dartsInTurn;
      for (final t in targets) {
        marks[data.playerIndex][t] = data.marksBefore[t] ?? 0;
      }
      for (int i = 0; i < scores.length; i++) {
        scores[i] = data.scoresBefore[i];
        players[i].score = scores[i];
      }
      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
      lastThrowLabel = null;
    });
    _log.logUndo(
      playerIndex: lastThrow.playerIndex,
      playerName: players[lastThrow.playerIndex].name,
      throwLabel: lastThrow.label,
      scoreRestored: scores[lastThrow.playerIndex],
      roundNumber: _roundNumber,
    );
  }

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};

  /// Computes final placements for all players.
  /// Finished players keep their finish order.
  /// Remaining players are ranked by: score (desc/asc for cutthroat),
  /// then closed targets (desc), then total marks (desc). Ties share a rank.
  List<int> _computeExitPlacements() {
    final result = List<int>.filled(players.length, 0);
    for (int i = 0; i < finishedPlayers.length; i++) {
      result[finishedPlayers[i]] = i + 1;
    }
    final remaining = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    if (remaining.isEmpty) return result;

    remaining.sort((a, b) {
      final scoreComp = widget.config.isCutthroat
          ? scores[a].compareTo(scores[b])
          : scores[b].compareTo(scores[a]);
      if (scoreComp != 0) return scoreComp;
      final closedA = targets.where((t) => _isClosed(t, a)).length;
      final closedB = targets.where((t) => _isClosed(t, b)).length;
      if (closedB != closedA) return closedB.compareTo(closedA);
      final marksA = targets.fold(0, (s, t) => s + (marks[a][t] ?? 0));
      final marksB = targets.fold(0, (s, t) => s + (marks[b][t] ?? 0));
      return marksB.compareTo(marksA);
    });

    final base = finishedPlayers.length + 1;
    int place = base;
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0) {
        final prev = remaining[i - 1];
        final curr = remaining[i];
        final sameScore = scores[prev] == scores[curr];
        final prevClosed = targets.where((t) => _isClosed(t, prev)).length;
        final currClosed = targets.where((t) => _isClosed(t, curr)).length;
        final prevMarks = targets.fold(0, (s, t) => s + (marks[prev][t] ?? 0));
        final currMarks = targets.fold(0, (s, t) => s + (marks[curr][t] ?? 0));
        if (!sameScore || prevClosed != currClosed || prevMarks != currMarks) {
          place = base + i;
        }
      }
      result[remaining[i]] = place;
    }
    return result;
  }

  Future<void> _updateStats() async {
    if (_midGamePlayerChanges) {
      await StatsRecorder.recordMidGameChanges(
        joinedIds: _joinedMidGameIds,
        leftIds: _leftMidGameIds,
      );
      return;
    }
    final savedPlayers = await PlayerStorage.loadPlayers();
    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }
    final placements = _computeExitPlacements();
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      savedPlayers[idx].gamesPlayed++;
      if (placements[pi] == 1) {
        savedPlayers[idx].gamesWon++;
      }
    }
    // Compute per-player Cricket stats
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final playerDarts = throwHistory.where((t) => t.playerIndex == pi).toList();
      final closedCount = targets.where((t) => marks[pi][t]! >= 3).length;
      int misses = 0;
      int marksScored = 0;
      final segmentHits = <String, int>{};
      for (final t in playerDarts) {
        // Per-segment hit tracking for heatmap
        final segKey = 'seg_${t.segment}';
        segmentHits[segKey] = (segmentHits[segKey] ?? 0) + 1;
        if (t.segment > 0) {
          final mulSuffix = t.multiplier == 3 ? '_t' : t.multiplier == 2 ? '_d' : '_s';
          final detailKey = 'seg_${t.segment}$mulSuffix';
          segmentHits[detailKey] = (segmentHits[detailKey] ?? 0) + 1;
        }

        if (t.segment == 0) { misses++; }
        else if (targets.contains(t.segment)) {
          marksScored += t.multiplier;
        }
      }

      modeCounters[playerId] = {
        'totalDarts': playerDarts.length,
        'closedTargets': closedCount,
        'totalPoints': scores[pi],
        'marksScored': marksScored,
        'misses': misses,
        'max:bestPoints': scores[pi],
        ...segmentHits,
      };
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
    );
    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }
    StatsRecorder.recordGame(
      gameMode: widget.config.isCutthroat ? 'cricket_cutthroat' : 'cricket',
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

  GameResult _buildGameResult() {
    final placements = _computeExitPlacements();
    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      final closedCount = targets.where((t) => marks[i][t]! >= 3).length;
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: placements[i],
        stats: {'points': scores[i], 'closed': closedCount},
        ratingBefore: players[i].savedPlayerId != null
            ? _ratingsBefore[players[i].savedPlayerId!]
            : null,
        ratingAfter: players[i].savedPlayerId != null
            ? _ratingsAfter[players[i].savedPlayerId!]
            : null,
      ));
    }
    final active = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    return GameResult(
      gameMode: 'cricket',
      results: results,
      canContinue:
          !_gameFullyOver && active.length > 1 && players.length > 2,
    );
  }

  void _showPostGame() async {
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: finishedPlayers,
      gameFullyOver: _gameFullyOver,
    );
    // Compute stats before showing post-game so rating changes are visible (mirrors X01 behaviour)
    if (_gameFullyOver && !_statsRecorded) {
      _statsRecorded = true;
      await _updateStats();
    }
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => PostGameScreen(result: _buildGameResult())),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo');
      _undo();
    } else if (result == 'continue') {
      _log.logPostGame(action: 'continue', details: 'game continues with remaining players');
      setState(() {
        winnerIndex = null;
        _advancePlayer();
      });
    } else {
      _log.logPostGame(action: 'exit', details: 'gameFullyOver=$_gameFullyOver');
      if (!_statsRecorded) {
        // Game not fully over — user exiting early; record stats now
        _statsRecorded = true;
        _gameFullyOver = true;
        await _updateStats();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _lastDartsLabel(int playerIndex) {
    final darts =
        throwHistory.where((t) => t.playerIndex == playerIndex).toList();
    if (darts.isEmpty) return '';
    final last3 = darts.length <= 3 ? darts : darts.sublist(darts.length - 3);
    return last3.map((t) => t.shortLabel).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isGameActive = !finishedPlayers.contains(currentPlayerIndex);
    const targetLabelWidth = 44.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.isCutthroat ? 'Cricket (Cutthroat)' : 'Cricket'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _gameFullyOver ? null : _openPlayerManagement,
            tooltip: 'Manage players',
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
          // Player header with avatars, scores, last darts
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Column(
              children: [
                // Current turn info
                Row(
                  children: [
                    Text(
                      '${players[currentPlayerIndex].name} — Dart ${dartsInTurn + 1}/3',
                      style: TextStyle(
                        fontSize: 16,
                        color: playerColor(currentPlayerIndex),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        i < dartsInTurn ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: playerColor(currentPlayerIndex),
                      ),
                    )),
                    if (lastThrowLabel != null) ...[
                      const Spacer(),
                      Text(
                        lastThrowLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: lastThrowLabel!.contains('Closed')
                              ? Colors.green
                              : Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Player cards
                Row(
                  children: List.generate(players.length, (pi) {
                    final isCurrent = pi == currentPlayerIndex;
                    final lastDarts = _lastDartsLabel(pi);
                    final isRemoved = _removedPlayerIndices.contains(pi);
                    return Expanded(
                      child: Opacity(
                        opacity: isRemoved ? 0.4 : 1.0,
                        child: Container(
                        margin: EdgeInsets.only(
                            right: pi < players.length - 1 ? 6 : 0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? playerColor(pi).withAlpha(40)
                              : Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent
                              ? Border.all(
                                  color: playerColor(pi).withAlpha(100))
                              : null,
                        ),
                        child: Column(
                          children: [
                            PlayerAvatar(
                              avatarPath: players[pi].avatarPath,
                              name: players[pi].name,
                              radius: 18,
                              backgroundColor: playerColor(pi),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              players[pi].name.length > 8
                                  ? players[pi].name.substring(0, 8)
                                  : players[pi].name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: playerColor(pi),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${scores[pi]} pts',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (lastDarts.isNotEmpty)
                              Text(
                                lastDarts,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Column headers for the matrix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                SizedBox(width: targetLabelWidth),
                ...List.generate(players.length, (pi) {
                  final isCurrent = pi == currentPlayerIndex;
                  return Expanded(
                    flex: isCurrent ? 3 : 1,
                    child: Center(
                      child: Text(
                        players[pi].name,
                        style: TextStyle(
                          fontSize: isCurrent ? 12 : 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: playerColor(pi),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Target matrix with progress bars + S/D/T buttons
          // Uses Expanded rows so the matrix fills all available vertical space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: targets.map((target) {
                  final closedByAll = _isClosedByAll(target);
                  final isBull = target == 25;
                  final maxMarks = isBull ? 2 : 3;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: closedByAll
                            ? Colors.grey[900]?.withAlpha(120)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Target label
                          SizedBox(
                            width: targetLabelWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isBull ? 'Bull' : '$target',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: closedByAll ? Colors.grey[600] : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Player columns — active player (flex 3) gets S/D/T buttons,
                          // inactive players (flex 1) get progress bars
                          ...List.generate(players.length, (pi) {
                            final isCurrent = pi == currentPlayerIndex;
                            final m = marks[pi][target] ?? 0;
                            final closed = _isClosed(target, pi);
                            final color = closed ? Colors.green : playerColor(pi);
                            final fillFraction = (m.clamp(0, maxMarks) / maxMarks.toDouble());

                            // Active player: mark buttons
                            if (isCurrent && isGameActive && !closedByAll) {
                              return Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: isBull
                                        ? [
                                            Expanded(child: _markButton(target, 1, m)),
                                            const SizedBox(width: 3),
                                            Expanded(child: _markButton(target, 2, m)),
                                          ]
                                        : [
                                            Expanded(child: _markButton(target, 1, m)),
                                            const SizedBox(width: 3),
                                            Expanded(child: _markButton(target, 2, m)),
                                            const SizedBox(width: 3),
                                            Expanded(child: _markButton(target, 3, m)),
                                          ],
                                  ),
                                ),
                              );
                            }

                            // Inactive player or game not active: progress bar
                            return Expanded(
                              flex: isCurrent ? 3 : 1,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 4,
                                  right: pi < players.length - 1 ? 4 : 0,
                                ),
                                child: _buildProgressBar(
                                  fillFraction: fillFraction,
                                  color: color,
                                  markCount: m,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Fixed bottom bar — always visible
          _buildBottomBar(isGameActive),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isGameActive) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Row(
        children: [
          if (throwHistory.isNotEmpty) ...[
            Expanded(
              child: SizedBox(
                height: 92,
                child: OutlinedButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo, size: 28),
                  label: const Text('BACK',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[300],
                    side: BorderSide(color: Colors.grey[600]!, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 92,
              child: ElevatedButton(
                onPressed: isGameActive ? _onMiss : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
                child: const Text('MISS'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a progress bar showing marks 0–3. Fills its parent's constraints.
  Widget _buildProgressBar({
    required double fillFraction,
    required Color color,
    required int markCount,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[850] ?? Colors.grey[900],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[700]!, width: 0.5),
          ),
        ),
        if (fillFraction > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fillFraction,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withAlpha(markCount >= 3 ? 200 : 140),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        if (markCount > 0)
          Center(
            child: Text(
              markCount >= 3 ? '✓' : '$markCount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: markCount >= 3 ? Colors.white : Colors.white.withAlpha(220),
              ),
            ),
          ),
      ],
    );
  }

  /// Mark button: filled when currentMarks >= multiplier threshold.
  /// Label shows the number (e.g. "20", "D20", "T20", "Bull", "DBull").
  Widget _markButton(int target, int multiplier, int currentMarks) {
    final isBull = target == 25;
    final isFilled = currentMarks >= multiplier;
    final color = playerColor(currentPlayerIndex);
    final label = switch (multiplier) {
      2 => isBull ? 'DBull' : 'D$target',
      3 => 'T$target',
      _ => isBull ? 'Bull' : '$target',
    };
    return SizedBox.expand(
      child: ElevatedButton(
        onPressed: () => _registerHit(target, multiplier),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFilled ? color.withAlpha(170) : const Color(0xFF374151),
          foregroundColor: isFilled ? Colors.white : const Color(0xFFD1D5DB),
          elevation: 0,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(
            color: isFilled ? color.withAlpha(200) : const Color(0xFF4B5563),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
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
                style: TextStyle(color: Colors.grey[400]),
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
      gameOver: _gameFullyOver,
      colorFor: playerColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    int avgPoints = 0;
    final newMarks = {for (final t in targets) t: 0};

    if (activeIndices.isNotEmpty) {
      avgPoints = (activeIndices.map((i) => scores[i]).reduce((a, b) => a + b) /
              activeIndices.length)
          .round();

      // Per-target average marks (rounded), capped at 3 (closed)
      for (final t in targets) {
        final avgMarks = activeIndices
                .map((i) => marks[i][t]!.clamp(0, 3))
                .reduce((a, b) => a + b) /
            activeIndices.length;
        newMarks[t] = avgMarks.round().clamp(0, 3);
      }
    }

    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: avgPoints,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      marks.add(newMarks);
      scores.add(avgPoints);
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
                if (!finishedPlayers.contains(playerIndex)) {
                  finishedPlayers.add(playerIndex);
                }
                if (playerIndex == currentPlayerIndex) {
                  dartsInTurn = 0;
                  _advancePlayer();
                }
              });
            },
            child: const Text('Remove'),
          ),
        ],
      ),
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
}

class _CricketUndoData {
  final int playerIndex;
  final int dartsInTurn;
  final Map<int, int> marksBefore;
  final List<int> scoresBefore;
  final List<int> finishedPlayersBefore;

  _CricketUndoData({
    required this.playerIndex,
    required this.dartsInTurn,
    required this.marksBefore,
    required this.scoresBefore,
    required this.finishedPlayersBefore,
  });
}
