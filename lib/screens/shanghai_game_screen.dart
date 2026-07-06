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
import '../services/video_service.dart';
import '../utils/player_colors.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
import '../models/earned_feat.dart';
import '../utils/earned_feats_builder.dart';
import '../services/achievement_service.dart';
import '../widgets/player_avatar.dart';
import 'post_game_screen.dart';
import '../theme/dossedart_tokens.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_active_strip.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';

class ShanghaiGameScreen extends StatefulWidget {
  final List<Player> players;
  final ShanghaiConfig config;
  final bool useDossedartDesign;

  const ShanghaiGameScreen({
    super.key,
    required this.players,
    required this.config,
    this.useDossedartDesign = false,
  });

  @override
  State<ShanghaiGameScreen> createState() => _ShanghaiGameScreenState();
}

class _ShanghaiGameScreenState extends State<ShanghaiGameScreen> {
  late List<Player> players;
  late ShanghaiGameEngine engine;

  @visibleForTesting
  ShanghaiGameEngine get engineForTest => engine;

  @visibleForTesting
  Future<void> onGameEndForTest() => _onGameEnd();

  @visibleForTesting
  void onHitForTest(HitType type) => _onHit(type);

  @visibleForTesting
  void onUndoForTest() => _onUndo();

  final GameLogger _log = GameLogger.instance;

  // Per-turn hit history for the dart-slot display.
  // Reset whenever a new turn starts. Length matches engine.dartNumber.
  final List<HitType> _turnHits = [];

  // Per-dart history feeding the active strip's live turn label (same
  // turnId-grouped pattern as the other DOSSEDART cockpits).
  List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;

  final MemeService _meme = MemeService();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;

  bool _midGamePlayerChanges = false;
  final DateTime _gameStart = DateTime.now();

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

  /// In-progress turn's darts joined live (e.g. "S5 · S6 · MISS"); falls back
  /// to the active player's previous turn between turns.
  String? get _stripTurnLabel =>
      throwHistory.recentTurnLabel(engine.currentPlayerIndex);

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
      turnId: _turnIdCounter,
      roundNumber: engine.currentRound,
    );
    throwHistory.add(dartThrow);

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
      _turnIdCounter++;
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
    await _fireWinnerCelebration();
    if (!mounted) return;
    // Preview rating deltas so they're visible on the result screen even
    // though recording is deferred until the user leaves (audit F17).
    await _prepareRatingPreview(ranking);
    if (!mounted) return;
    _showPostGame(ranking);
  }

  /// Computes the rating deltas this finish WILL produce so the result screen
  /// can show them, without persisting anything. Actual recording stays
  /// deferred until the user leaves the result screen.
  Future<void> _prepareRatingPreview(List<int> ranking) async {
    if (_midGamePlayerChanges) return; // no rating changes to preview
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _buildPlacements(ranking),
      savedPlayers: savedPlayers,
    );

    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }
    // savedPlayers are discarded unpersisted — this was display-only.
  }

  /// Placements from [ranking]; equal totals share a placement.
  List<int> _buildPlacements(List<int> ranking) {
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
    return placements;
  }

  Future<void> _fireWinnerCelebration() async {
    if (engine.isInstantShanghai && _ttsEnabled) {
      // High-priority announcement — stop any queued TTS so this lands first.
      TtsService.instance.stop();
      TtsService.instance.speak('INSTANT SHANGHAI!');
    }
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
  }

  Future<void> _updateStats(List<int> ranking) async {
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    final placements = _buildPlacements(ranking);

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

    var earnedFeats = <int, List<EarnedFeat>>{};
    if (!_midGamePlayerChanges) {
      final events = <int, List<AchievementEvent>>{};
      if (engine.isInstantShanghai && engine.winnerIndex != null) {
        events[engine.winnerIndex!] = [AchievementEvent.instantShanghai];
      }
      final unlocks = AchievementService.instance.awardGameEnd(
        mode: GameMode.shanghai,
        playerIds: players.map((p) => p.savedPlayerId).toList(),
        savedPlayers: savedPlayers,
        placements: placements,
        ratingsBefore: _ratingsBefore,
        ratingsAfter: _ratingsAfter,
        eventsByIndex: events,
      );
      earnedFeats =
          buildEarnedFeats(eventsByIndex: events, unlocksByIndex: unlocks);
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
      gameConfig: 'Shanghai',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
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

    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PostGameScreen(
          result: GameResult(gameMode: 'shanghai', results: results),
        ),
      ),
    ).then((action) async {
      if (!mounted) return;
      if (action == 'undo') {
        // User wants to keep playing — undo the game-end and return to game.
        // Same guard as _onUndo: a stack emptied by add/remove player must
        // not rewind the screen-side history the engine cannot match.
        if (!engine.canUndo) return;
        setState(() {
          engine.undo();
          if (throwHistory.isNotEmpty) {
            final lastThrow = throwHistory.removeLast();
            _turnIdCounter = lastThrow.turnId;
          }
        });
        return;
      }
      // 'home' or back-button: persist stats now (deferred from _onGameEnd
      // so Undo doesn't strand the user with stats they didn't confirm),
      // then leave the game-screen entirely.
      await _updateStats(ranking);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
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
    // Add/remove player clears the engine's undo stack and engine.undo()
    // silently no-ops when empty — rewinding the screen-side history then
    // would desync the strip's turn grouping.
    if (!engine.canUndo) return;
    setState(() {
      engine.undo();
      if (_turnHits.isNotEmpty) {
        _turnHits.removeLast();
      }
      if (throwHistory.isNotEmpty) {
        final lastThrow = throwHistory.removeLast();
        _turnIdCounter = lastThrow.turnId;
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

  void _openDossedartPlayerSheet() {
    final rows = <DossedartStandingRow>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      rows.add(DossedartStandingRow(
        playerIndex: i,
        name: p.name,
        avatarPath: p.avatarPath,
        isActive: i == engine.currentPlayerIndex,
        isRemoved: engine.isSkipped(i),
        primary: '${engine.totalScores[i]}',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: engine.gameOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
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
    if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
    return _buildClassicScaffold(context);
  }

  // ---------------------------------------------------------------------------
  // DOSSEDART arcade cockpit — three chase cells (S/D/T of the round number)
  // are both the input and the Shanghai tracker; a gold banner counts the n/3
  // chase. Every tap feeds the same engine.recordThrow via _onHit.
  // ---------------------------------------------------------------------------

  Widget _buildDossedartCockpit(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: 'SHANGHAI · 1→${engine.targetEnd}',
                onExit: _confirmExit,
                trailing: 'RND ${engine.currentRound + 1}/${engine.targetEnd}',
              ),
              DossedartActiveStrip(
                playerName: players[engine.currentPlayerIndex].name,
                avatarPath: players[engine.currentPlayerIndex].avatarPath,
                accentColor: DossedartTokens.cyan,
                dartsInTurn: engine.dartNumber,
                lastThrowLabel: _stripTurnLabel,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 12,
                            color: Colors.white54,
                            letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(
                      '${engine.totalScores[engine.currentPlayerIndex]}',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 36,
                        color: DossedartTokens.cyan,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _shanghaiStandings(),
              _shanghaiBanner(),
              Expanded(child: Center(child: _shanghaiChaseCells())),
              _shanghaiRoundLadder(),
              DossedartActionBar(
                onUndo: _onUndo,
                onMiss: () => _onHit(HitType.miss),
                onMenu: () => showDossedartCockpitMenu(
                  context,
                  meme: _meme,
                  onTtsChanged: (v) => setState(() => _ttsEnabled = v),
                  onPlayerOverview: _openDossedartPlayerSheet,
                  onExit: _confirmExit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shanghaiStandings() {
    final order = [
      for (int i = 0; i < players.length; i++)
        if (!engine.isSkipped(i)) i
    ]..sort((a, b) => engine.totalScores[b].compareTo(engine.totalScores[a]));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int rank = 0; rank < order.length; rank++)
            Expanded(child: _shanghaiStandChip(order[rank], rank == 0)),
        ],
      ),
    );
  }

  Widget _shanghaiStandChip(int i, bool leader) {
    final active = i == engine.currentPlayerIndex;
    final c = leader
        ? DossedartTokens.yellow
        : active
            ? DossedartTokens.cyan
            : DossedartTokens.phosphor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            players[i].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: c),
          ),
          const SizedBox(height: 2),
          Text(
            '${engine.totalScores[i]}',
            style: TextStyle(
                fontFamily: 'PressStart2P', fontSize: 13, color: c),
          ),
        ],
      ),
    );
  }

  Widget _shanghaiBanner() {
    final got = engine.currentTurnHits.length;
    final oneAway = got == 2;
    final target = engine.currentTarget;
    const c = DossedartTokens.yellow;
    final msg = oneAway
        ? 'TREFF T$target FOR DIREKTE SEIER!'
        : 'S + D + T I ÉN TUR = DIREKTE SEIER';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withValues(alpha: oneAway ? 0.16 : 0.06),
        border: Border.all(color: c.withValues(alpha: oneAway ? 1 : 0.33), width: 2),
        boxShadow: oneAway
            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 14)]
            : null,
      ),
      child: Row(
        children: [
          const Text('⚡ SHANGHAI',
              style: TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 9, color: c)),
          Expanded(
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'VT323', fontSize: 15, color: c, letterSpacing: 1),
            ),
          ),
          Text('$got/3',
              style: const TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: c)),
        ],
      ),
    );
  }

  Widget _shanghaiChaseCells() {
    final target = engine.currentTarget;
    final hits = engine.currentTurnHits;
    final oneAway = hits.length == 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _shanghaiChaseCell('SINGLE', '$target', HitType.single,
              hits.contains(HitType.single), oneAway),
          _shanghaiChaseCell('DOUBLE', 'D$target', HitType.double_,
              hits.contains(HitType.double_), oneAway),
          _shanghaiChaseCell('TRIPLE', 'T$target', HitType.triple,
              hits.contains(HitType.triple), oneAway),
        ],
      ),
    );
  }

  Widget _shanghaiChaseCell(
      String cap, String label, HitType type, bool hit, bool oneAway) {
    final c = hit
        ? DossedartTokens.green
        : oneAway
            ? DossedartTokens.yellow
            : DossedartTokens.cyan;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: () => _onHit(type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: c.withValues(alpha: hit ? 0.18 : 0.07),
              border: Border.all(color: c, width: hit ? 3 : 2),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: hit ? 0.45 : 0.2), blurRadius: hit ? 16 : 10),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cap,
                    style: TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 14,
                        color: c,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'PressStart2P', fontSize: 26, color: c)),
                const SizedBox(height: 8),
                Text(hit ? '✓ TRUFFET' : '—',
                    style: TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 14,
                        color: hit ? c : Colors.white38,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shanghaiRoundLadder() {
    final cur = engine.currentTarget;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int r = 1; r <= engine.targetEnd; r++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r == cur
                      ? DossedartTokens.cyan.withValues(alpha: 0.16)
                      : null,
                  border: Border.all(
                    color: r == cur
                        ? DossedartTokens.cyan
                        : r < cur
                            ? DossedartTokens.green.withValues(alpha: 0.6)
                            : DossedartTokens.phosphor.withValues(alpha: 0.3),
                    width: r == cur ? 2 : 1,
                  ),
                ),
                child: Text(
                  r < cur ? '✓' : '$r',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: r == cur
                        ? DossedartTokens.cyan
                        : r < cur
                            ? DossedartTokens.green
                            : DossedartTokens.phosphor.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassicScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shanghai'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
          tooltip: 'Exit',
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'players':
                  if (!engine.gameOver) _openPlayerManagement();
                  break;
                case 'tts':
                  await TtsService.instance.setEnabled(!_ttsEnabled);
                  setState(() => _ttsEnabled = TtsService.instance.enabled);
                  break;
                case 'meme':
                  setState(() => _memeEnabled = !_memeEnabled);
                  AppSettings.setMemeEnabled(_memeEnabled);
                  _meme.setEnabled(_memeEnabled);
                  break;
                case 'meme_freq':
                  _showMemeFrequencyDialog();
                  break;
                case 'offensive':
                  setState(() => _offensiveEnabled = !_offensiveEnabled);
                  AppSettings.setMemeOffensive(_offensiveEnabled);
                  _meme.setOffensive(_offensiveEnabled);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'players',
                enabled: !engine.gameOver,
                child: const Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 12),
                    Text('Manage players'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'tts',
                child: Row(
                  children: [
                    Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
                    const SizedBox(width: 12),
                    Text(_ttsEnabled ? 'TTS on' : 'TTS off'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'meme',
                child: Row(
                  children: [
                    Text(_memeEnabled ? '🤡' : '🤐',
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(_memeEnabled ? 'Memes on' : 'Memes off'),
                  ],
                ),
              ),
              if (_memeEnabled) ...[
                const PopupMenuItem(
                  value: 'meme_freq',
                  child: Row(
                    children: [
                      Icon(Icons.tune),
                      SizedBox(width: 12),
                      Text('Meme frequency'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'offensive',
                  child: Row(
                    children: [
                      Icon(_offensiveEnabled
                          ? Icons.whatshot
                          : Icons.whatshot_outlined),
                      const SizedBox(width: 12),
                      Text(_offensiveEnabled
                          ? 'Offensive on'
                          : 'Offensive off'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPlayerInfoBar(),
          _buildRoundIndicators(),
          const SizedBox(height: 4),
          _buildDartSlots(),
          const SizedBox(height: 8),
          Expanded(child: _buildHitButtons()),
          _buildBackMissRow(),
          _buildScoreboard(),
        ],
      ),
    );
  }

  Widget _buildPlayerInfoBar() {
    final pi = engine.currentPlayerIndex;
    if (pi >= players.length) return const SizedBox();
    final player = players[pi];
    final dartsInTurn = _turnHits.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('Dart ${dartsInTurn + 1} of 3',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    ...List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          i < dartsInTurn ? Icons.circle : Icons.circle_outlined,
                          size: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Target',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11)),
              Text(
                '${engine.currentTarget}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: ${engine.totalScores[pi]}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundIndicators() {
    final total = widget.config.targetEnd;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: List.generate(total, (ri) {
          final isCurrent = ri == engine.currentRound;
          final isDone = ri < engine.currentRound;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isCurrent
                  ? Theme.of(context).colorScheme.tertiary.withAlpha(40)
                  : isDone
                      ? Theme.of(context).colorScheme.primary.withAlpha(30)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
              border: isCurrent
                  ? Border.all(
                      color: Theme.of(context).colorScheme.tertiary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${ri + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent
                    ? Theme.of(context).colorScheme.tertiary
                    : isDone
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScoreboard() {
    final cardHeight = 56.0;
    return Container(
      constraints: BoxConstraints(maxHeight: cardHeight * 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: players.length,
        itemBuilder: (context, index) {
          final player = players[index];
          final isCurrent =
              index == engine.currentPlayerIndex && !engine.gameOver;
          final isRemoved = engine.isSkipped(index);

          return Opacity(
            opacity: isRemoved ? 0.4 : 1.0,
            child: ActivePlayerHighlight(
              isActive: isCurrent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    child: Text(
                      player.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${engine.totalScores[index]}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
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

  Widget _buildHitButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _shanghaiHitLabel(
                '${engine.currentTarget}', () => _onHit(HitType.single)),
            Container(
                width: 2,
                color: Theme.of(context).colorScheme.outline),
            _shanghaiHitLabel(
                'D${engine.currentTarget}', () => _onHit(HitType.double_)),
            Container(
                width: 2,
                color: Theme.of(context).colorScheme.outline),
            _shanghaiHitLabel(
                'T${engine.currentTarget}', () => _onHit(HitType.triple)),
          ],
        ),
      ),
    );
  }

  Widget _buildBackMissRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Visibility(
              visible: !engine.gameOver,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _onUndo,
                  icon: const Icon(Icons.undo, size: 20),
                  label: const Text('Back', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed:
                    engine.gameOver ? null : () => _onHit(HitType.miss),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Miss',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shanghaiHitLabel(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: engine.gameOver ? null : onTap,
        borderRadius: BorderRadius.circular(11),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: engine.gameOver
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
