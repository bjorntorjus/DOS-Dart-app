import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/halve_it_round.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/join_seed.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/shot_clock.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../models/game_result.dart';
import '../widgets/player_avatar.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
import '../utils/earned_feats_builder.dart';
import '../services/achievement_service.dart';
import '../models/saved_player.dart';
import 'post_game_screen.dart';
import '../services/battery_sampler.dart';
import '../theme/dossedart_tokens.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_active_strip.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../utils/dossedart_player_accents.dart';
import '../models/setup_prefill.dart';
import 'player_setup_screen.dart';
import 'dossedart/dossedart_splitscore_setup_screen.dart';

class HalveItGameScreen extends StatefulWidget {
  final List<Player> players;
  final HalveItConfig config;
  final bool useDossedartDesign;

  const HalveItGameScreen({
    super.key,
    required this.players,
    required this.config,
    this.useDossedartDesign = false,
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
  int _turnIdCounter = 0;
  int turnPoints = 0; // points accumulated this turn
  bool turnHasHit = false; // whether any dart hit the target this turn

  /// Players who landed a last-dart hit after the first two missed, saving
  /// themselves from a halving this game (CLUTCH SAVE).
  final Set<int> _clutchSavers = {};

  @visibleForTesting
  Set<int> get clutchSaversForTest => _clutchSavers;

  @visibleForTesting
  Future<void> onDartHitForTest(int segment, int multiplier) =>
      _onDartHit(segment, multiplier);

  @visibleForTesting
  void undoForTest() => _undo();

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => _removedPlayerIndices;

  @visibleForTesting
  GameResult buildGameResultForTest() => _buildGameResult();

  @visibleForTesting
  void removePlayerForTest(int playerIndex) => _performRemovePlayer(playerIndex);

  @visibleForTesting
  int get currentPlayerIndexForTest => currentPlayerIndex;

  @visibleForTesting
  int get currentRoundIndexForTest => currentRoundIndex;

  @visibleForTesting
  List<int> get totalScoresForTest => totalScores;

  List<DartThrow> throwHistory = [];
  bool gameOver = false;
  String? lastThrowLabel;

  // Undo data per throw
  final List<_HalveItUndoData> _undoStack = [];
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final ScrollController _scoreboardController = ScrollController();
  bool _soundEnabled = true;
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
  final DateTime _gameStart = DateTime.now();
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
    AppSettings.getSoundEffectsEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
    });
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    TtsService.instance.init().then((_) {
      if (mounted) setState(() => _ttsEnabled = TtsService.instance.enabled);
    });
    _log.logGameStart(
      gameMode: 'Splitscore',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 40),
      config: {
        'rounds': rounds.map((r) => r.label).toList(),
        'isRandom': widget.config.isRandom,
      },
      build: kAppVersion,
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
      turnId: _turnIdCounter,
      // Without this every dart lands in round 0, so the MATCH FLOW chart
      // groups the whole game into one bucket and collapses to two points —
      // start and finish (tester feedback 2026-08-10).
      roundNumber: currentRoundIndex,
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
      clutchSaversBefore: Set.of(_clutchSavers),
    ));

    // Video gating lives entirely in VideoService.shouldPlay (video-damping
    // 2026-07-22). The old meme-frequency pre-roll here meant the meme slider
    // silently changed how often videos played (audit 2026-08-10, F2).
    final videoRoll = VideoService.instance.shouldPlay();

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
      ShotClock.instance.registerDart();

      if (hit) {
        if (dartsInTurn == 2 && !turnHasHit) {
          _clutchSavers.add(currentPlayerIndex); // first two missed, 3rd saves it
          SoundService.instance.playRandom(const ['halve_it/clutch']);
        }
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
      await VideoService.instance.showRandomFromFolder(context, _pendingVideoEvent!,
          alreadyDecided: true);
      _pendingVideoEvent = null;
      if (!mounted) return;
    }
    _pendingVideoEvent = null;

    if (gameOver) {
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _prepareRatingPreview().then((_) => _showPostGame());
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
      SoundService.instance.playRandom(const ['halve_it/halved']);
      _log.log('HALVED P$pi(${players[pi].name}) score $before → $halved');
    }
    players[pi].score = totalScores[pi];

    // Next player or next round
    dartsInTurn = 0;
    _turnIdCounter++;
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
    _log.logTurnStart(
      roundNumber: currentRoundIndex + 1,
      playerIndex: currentPlayerIndex,
      playerName: players[currentPlayerIndex].name,
      score: totalScores[currentPlayerIndex],
    );
    _log.logStandings(
      roundNumber: currentRoundIndex + 1,
      names: players.map((p) => p.name).toList(),
      scores: totalScores,
    );
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
  }

  void _onMiss() {
    _missSoundPlayed = _meme.tryMissSound();
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
    // A removed player's throws are frozen: undoing one would make them the
    // current thrower again (audit 2026-07-06, F9).
    if (_removedPlayerIndices.contains(undoneThrow.playerIndex)) return;
    final undoData = _undoStack.last;
    _announcer.announceGameEvent('Back');

    setState(() {
      throwHistory.removeLast();
      _turnIdCounter = undoneThrow.turnId;
      final data = _undoStack.removeLast();
      currentRoundIndex = data.roundIndex;
      currentPlayerIndex = data.playerIndex;
      dartsInTurn = data.dartsInTurn;
      turnPoints = data.turnPoints;
      turnHasHit = data.turnHasHit;
      _clutchSavers
        ..clear()
        ..addAll(data.clutchSaversBefore);
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

  /// Computes the rating deltas this finish WILL produce so the result screen
  /// can show them, without persisting anything. Actual recording is deferred
  /// until the user leaves the result screen (see [_showPostGame]) so that
  /// "↶ Back" never leaves stats behind — the double-record fix from the
  /// 2026-07-06 audit (F2).
  Future<void> _prepareRatingPreview() async {
    if (_midGamePlayerChanges) return; // no rating changes to preview
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    EloService.updateRatings(
      gameMode: 'halveIt',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _buildPlacements(),
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

  /// Rank by total score (higher = better placement); equal scores tie.
  List<int> _buildPlacements() {
    final sorted = List.generate(players.length, (i) => i)
      ..sort(withSeatTiebreak(
          (a, b) => totalScores[b].compareTo(totalScores[a])));
    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < sorted.length; rank++) {
      if (rank > 0 && totalScores[sorted[rank]] == totalScores[sorted[rank - 1]]) {
        placements[sorted[rank]] = placements[sorted[rank - 1]]; // tie
      } else {
        placements[sorted[rank]] = rank + 1;
      }
    }
    return placements;
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
    // A shared best score is a draw — nobody gets win credit.
    final tieForBest =
        totalScores.where((s) => s == bestScore).length > 1;

    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];
      sp.gamesPlayed++;
      if (pi == winnerIdx && !tieForBest) sp.gamesWon++;

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
    final placements = _buildPlacements();
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
      gameMode: 'halveIt',
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

    final achEvents = <int, List<AchievementEvent>>{
      for (final i in _clutchSavers) i: [AchievementEvent.clutchSave],
    };
    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.halveIt,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      eventsByIndex: achEvents,
    );

    StatsRecorder.recordGame(
      gameMode: 'halveIt',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: 'Splitscore',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex:
          buildEarnedFeats(eventsByIndex: achEvents, unlocksByIndex: unlocks),
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _showPostGame() async {
    // Rank players by total score descending
    final indexed = List.generate(players.length, (i) => i);
    indexed.sort(
        withSeatTiebreak((a, b) => totalScores[b].compareTo(totalScores[a])));

    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: indexed,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => PostGameScreen(result: _buildGameResult())),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo');
      _undo();
    } else if (result == 'again') {
      _log.logPostGame(action: 'again');
      await _updateStats();
      if (!mounted) return;
      final ids = rematchPlayerIds(players, _removedPlayerIndices.contains);
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
      nav.push(MaterialPageRoute(
        builder: (_) => widget.useDossedartDesign
            ? DossedartSplitscoreSetupScreen(
                initialConfig: widget.config, initialPlayerIds: ids)
            : PlayerSetupScreen(
                gameMode: GameMode.halveIt,
                prefill: SetupPrefill(playerIds: ids, config: widget.config),
              ) as Widget,
      ));
    } else {
      _log.logPostGame(action: 'exit');
      // Leaving the game — record stats now. Recording is deferred to this
      // point (not done when the game ended) so a post-game Undo never
      // strands persisted stats; see _prepareRatingPreview.
      await _updateStats();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  GameResult _buildGameResult() {
    // Players removed mid-game must not appear on the result screen at all —
    // and never as the winner. Rank only the remaining players by total score
    // (higher = better) so a removed leader cannot take 1st place.
    final indexed = List.generate(players.length, (i) => i)
        .where((i) => !_removedPlayerIndices.contains(i))
        .toList()
      ..sort(withSeatTiebreak(
          (a, b) => totalScores[b].compareTo(totalScores[a])));

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
    return GameResult(
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      gameMode: 'halveIt',
      results: results,
      // Chart lines index by seat; a changed roster misaligns them —
      // suppress instead of mislabeling.
      throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory),
      progressionMode: _midGamePlayerChanges ? null : 'halveIt',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
    return _buildClassicScaffold(context);
  }

  // ---------------------------------------------------------------------------
  // DOSSEDART arcade cockpit — scorecard hero + red jeopardy bar + adaptive
  // input (S/D/T cells for number/bull rounds, a 1–20 keypad for double/triple
  // rounds). Every tap feeds the same _onDartHit; halving stays in _finishTurn.
  // ---------------------------------------------------------------------------

  Widget _buildDossedartCockpit(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: 'SPLITSCORE',
                onExit: _confirmExit,
                trailing: 'RND ${currentRoundIndex + 1}/${rounds.length}',
              ),
              DossedartActiveStrip(
                playerName: players[currentPlayerIndex].name,
                avatarPath: players[currentPlayerIndex].avatarPath,
                accentColor: dossedartAccent(currentPlayerIndex),
                dartsInTurn: dartsInTurn,
                modeSlot: DossedartStripSlot(
                  label: 'TARGET',
                  value: rounds[currentRoundIndex].label.toUpperCase(),
                  subLine:
                      'MISS HALVES ${totalScores[currentPlayerIndex]} › ${totalScores[currentPlayerIndex] ~/ 2}',
                  subLineColor: DossedartTokens.red,
                ),
                scoreLabel: 'POINTS',
                scoreValue: '${totalScores[currentPlayerIndex]}',
                smallScore: true,
              ),
              // Jeopardy bar + scorecard + input area share one flexible,
              // scrollable slot; only TopBar/Strip/ActionBar are genuinely
              // fixed-height chrome. This matters because the input area is
              // NOT actually fixed-height: an "any double" round renders a
              // 5-row keypad (S/D/T rows plus a D-BULL row) that's taller
              // than "any triple"'s 4-row keypad or the single-row
              // number/bull layout. On a short surface, if "Double" happens
              // to be the CURRENT round, that extra row alone was enough to
              // overflow this Column even with the scorecard already
              // shrunk to nothing (PR #12 CI failure — see
              // test/screens/halve_it_random_hidden_test.dart).
              //
              // ConstrainedBox(minHeight: <available height>) + a plain
              // Column let mainAxisAlignment.spaceBetween push all slack
              // into the single gap between the scorecard and the input
              // when there's room (matching the old shrink-wrap look on
              // generous screens — see
              // test/screens/strip_turn_label_test.dart), while the
              // SingleChildScrollView means a genuine height shortage (e.g.
              // the double keypad on a short screen) scrolls instead of
              // throwing a RenderFlex overflow.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _splitJeopardyBar(),
                                _splitScorecard(),
                              ],
                            ),
                            _splitInput(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              DossedartActionBar(
                onUndo: _undo,
                onMiss: _onMiss,
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

  Widget _splitJeopardyBar() {
    final round = rounds[currentRoundIndex];
    final total = totalScores[currentPlayerIndex];
    final safe = turnHasHit;
    final c = safe ? DossedartTokens.green : DossedartTokens.red;
    final text = safe
        ? '✓ SECURED · +$turnPoints THIS ROUND'
        : '⚠ HIT ${round.label.toUpperCase()} OR HALVE · $total → ${total ~/ 2}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c, width: 2),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 12)],
      ),
      // FittedBox + maxLines: 1 pins this bar to a single, constant text-line
      // height no matter what the message says. Without it, the sentence's
      // length rides on the round label ("HIT TRIPLE OR HALVE" vs. "HIT 7 OR
      // HALVE") and on the score digit count, so it could silently wrap from
      // one line to two — growing the bar by ~19px and overflowing the
      // cockpit Column below, since every other element in that Column is
      // genuinely fixed-height. Scaling down (not truncating) keeps the full
      // message readable even if it would otherwise be too wide.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: c,
            letterSpacing: 1,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _splitScorecard() {
    final magenta55 = DossedartTokens.magenta.withValues(alpha: 0.33);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: magenta55, width: 2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Inside the scroll view so the card can shrink below the
                    // header height without overflowing on short screens; on
                    // the tablet target nothing scrolls, so it stays pinned.
                    _splitScoreHeader(),
                    for (int ri = 0; ri < rounds.length; ri++)
                      _splitScoreRow(ri),
                    _splitSumRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitScoreHeader() {
    final magenta = DossedartTokens.magenta;
    return Container(
      decoration: BoxDecoration(
        color: magenta.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: magenta.withValues(alpha: 0.33), width: 2),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 70,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('ROUND',
                    style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: Colors.white54,
                        letterSpacing: 1)),
              ),
            ),
          ),
          for (int pi = 0; pi < players.length; pi++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                color: pi == currentPlayerIndex
                    ? DossedartTokens.cyan.withValues(alpha: 0.11)
                    : null,
                child: Text(
                  players[pi].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: pi == currentPlayerIndex
                        ? DossedartTokens.cyan
                        : DossedartTokens.phosphor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Future rounds stay a surprise in random mode.
  String _roundLabelFor(int ri) {
    if (widget.config.isRandom && ri > currentRoundIndex) return '?';
    return rounds[ri].label.toUpperCase();
  }

  Widget _splitScoreRow(int ri) {
    final magenta = DossedartTokens.magenta;
    final isCurrent = ri == currentRoundIndex;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? DossedartTokens.cyan.withValues(alpha: 0.06) : null,
        border: Border(
          bottom: BorderSide(color: magenta.withValues(alpha: 0.13), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Text(
                _roundLabelFor(ri),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: isCurrent
                      ? DossedartTokens.yellow
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          for (int pi = 0; pi < players.length; pi++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                color: pi == currentPlayerIndex
                    ? DossedartTokens.cyan.withValues(alpha: 0.06)
                    : null,
                child: Center(child: _splitCellText(roundScores[ri][pi])),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitCellText(int? v) {
    if (v == null) {
      return Text('·',
          style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.18)));
    }
    if (v < 0) {
      return Text('-${-v} ✗',
          style: const TextStyle(
              fontFamily: 'VT323', fontSize: 20, color: DossedartTokens.red));
    }
    return Text('$v',
        style: const TextStyle(
            fontFamily: 'VT323', fontSize: 22, color: Colors.white));
  }

  Widget _splitSumRow() {
    int leader = 0;
    for (int i = 1; i < players.length; i++) {
      if (totalScores[i] > totalScores[leader]) leader = i;
    }
    return Container(
      decoration: BoxDecoration(
        color: DossedartTokens.magenta.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.33), width: 2),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 70,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Center(
                child: Text('SUM',
                    style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: Colors.white70)),
              ),
            ),
          ),
          for (int pi = 0; pi < players.length; pi++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '${totalScores[pi]}',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 16,
                      color: pi == leader
                          ? DossedartTokens.yellow
                          : pi == currentPlayerIndex
                              ? DossedartTokens.cyan
                              : DossedartTokens.phosphor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitInput() {
    final round = rounds[currentRoundIndex];
    switch (round.type) {
      case HalveItRoundType.number:
        final n = round.targetNumber!;
        return _splitCellRow([('$n', n, 1), ('D$n', n, 2), ('T$n', n, 3)]);
      case HalveItRoundType.bull:
        return _splitCellRow([('BULL', 25, 1), ('D-BULL', 25, 2)]);
      case HalveItRoundType.anyDouble:
        return _splitKeypad(2, includeDBull: true);
      case HalveItRoundType.anyTriple:
        return _splitKeypad(3, includeDBull: false);
    }
  }

  Widget _splitCellRow(List<(String, int, int)> subs) {
    const c = DossedartTokens.cyan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final (label, seg, mult) in subs)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _onDartHit(seg, mult),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.07),
                      border: Border.all(color: c, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: c,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitKeypad(int mult, {required bool includeDBull}) {
    final prefix = mult == 2 ? 'D' : 'T';
    Widget row(List<int> nums) => Row(
          children: [
            for (final k in nums) ...[
              Expanded(child: _splitKeypadBtn('$prefix$k', k, mult)),
              if (k != nums.last) const SizedBox(width: 8),
            ],
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([1, 2, 3, 4, 5]),
          const SizedBox(height: 8),
          row([6, 7, 8, 9, 10]),
          const SizedBox(height: 8),
          row([11, 12, 13, 14, 15]),
          const SizedBox(height: 8),
          row([16, 17, 18, 19, 20]),
          if (includeDBull) ...[
            const SizedBox(height: 8),
            _splitKeypadBtn('D-BULL', 25, 2),
          ],
        ],
      ),
    );
  }

  Widget _splitKeypadBtn(String label, int segment, int mult) {
    const c = DossedartTokens.cyan;
    return GestureDetector(
      onTap: () => _onDartHit(segment, mult),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          border: Border.all(color: c, width: 1),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 15,
              color: c,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicScaffold(BuildContext context) {
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'players':
                  if (!gameOver) _openPlayerManagement();
                  break;
                case 'sound':
                  setState(() => _soundEnabled = !_soundEnabled);
                  SoundService.instance.setEnabled(_soundEnabled);
                  AppSettings.setSoundEffectsEnabled(_soundEnabled);
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
                enabled: !gameOver,
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
                value: 'sound',
                child: Row(
                  children: [
                    Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
                    const SizedBox(width: 12),
                    Text(_soundEnabled ? 'Sound on' : 'Sound off'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'tts',
                child: Row(
                  children: [
                    Icon(_ttsEnabled ? Icons.mic : Icons.mic_off),
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
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary, fontSize: 14)),
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
                            ? Theme.of(context).colorScheme.primary.withAlpha(30)
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                    border: isCurrent
                        ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 2)
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Last throw label (always reserves space)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lastThrowLabel != null ? 'Last: $lastThrowLabel' : ' ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: lastThrowLabel != null && lastThrowLabel!.contains('✓')
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                ),
              ),
            ),
          ),

          // Target buttons (uses remaining space)
          Expanded(child: _buildTargetButtons(currentRound)),

          // Back button (always reserves space)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Visibility(
                    visible: throwHistory.isNotEmpty,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
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
                ),
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
                                color: lastRoundScore < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
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
            'D-Bull', () => _onDartHit(25, 2), Colors.orange[800]!));
        return _compactButtonGrid(buttons, includeMiss: true);

      case HalveItRoundType.anyTriple:
        final buttons = <Widget>[];
        for (int i = 1; i <= 20; i++) {
          buttons.add(_compactButton(
              'T$i', () => _onDartHit(i, 3),
              Theme.of(context).colorScheme.onSurfaceVariant));
        }
        return _compactButtonGrid(buttons, includeMiss: true);

      case HalveItRoundType.bull:
        return _buildNumberButtons(null); // null = Bull mode
    }
  }

  /// Big buttons for a specific target number (or Bull if n == null).
  Widget _buildNumberButtons(int? n) {
    final isBull = n == null;
    final cs = Theme.of(context).colorScheme;

    final entries = isBull
        ? [
            ('Bull', () => _onDartHit(25, 1)),
            ('DBull', () => _onDartHit(25, 2)),
          ]
        : [
            ('$n', () => _onDartHit(n, 1)),
            ('D$n', () => _onDartHit(n, 2)),
            ('T$n', () => _onDartHit(n, 3)),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Outline-wrap with plain labels separated by 2px vlines
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: 90,
              child: Row(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      Container(width: 2, height: 60, color: cs.outline),
                    Expanded(
                      child: InkWell(
                        onTap: entries[i].$2,
                        borderRadius: BorderRadius.circular(11),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              entries[i].$1,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onMiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.surfaceContainerHigh,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Miss',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactButton(String label, VoidCallback onTap, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
          ),
        ),
      ),
    );
  }

  Widget _compactButtonGrid(List<Widget> buttons, {bool includeMiss = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.4,
              children: buttons,
            ),
          ),
          if (includeMiss) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onMiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHigh,
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

  void _openDossedartPlayerSheet() {
    final rows = <DossedartStandingRow>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      rows.add(DossedartStandingRow(
        playerIndex: i,
        name: p.name,
        avatarPath: p.avatarPath,
        isActive: i == currentPlayerIndex,
        isRemoved: _removedPlayerIndices.contains(i),
        primary: '${totalScores[i]}',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: gameOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
          'A new player starts level with whoever is in last place. '
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
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
          'A new player starts level with whoever is in last place. '
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Splitscore accumulates, so the LOWEST
    // total is the worst position. Every player plays every round here, so
    // "active" is only about removal.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !_removedPlayerIndices.contains(i))
        .toList();
    final worst = worstSeat(totalScores, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 40 : totalScores[worst];

    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: seedScore,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      totalScores.add(seedScore);
      // Backfill roundScores for rounds already played with null (skipped)
      for (int ri = 0; ri < rounds.length; ri++) {
        roundScores[ri].add(null);
      }
    });
    _log.logRoster(
      action: 'ADD',
      playerIndex: players.length - 1,
      playerName: sp.name,
      names: players.map((p) => p.name).toList(),
      scores: totalScores,
    );
  }

  /// Production removal logic, shared by the confirm dialog and tests.
  void _performRemovePlayer(int playerIndex) {
    final removed = players[playerIndex];
    setState(() {
      _midGamePlayerChanges = true;
      _removedPlayerIndices.add(playerIndex);
      if (removed.savedPlayerId != null) {
        _leftMidGameIds.add(removed.savedPlayerId!);
      }
      if (playerIndex == currentPlayerIndex) {
        // The removed player's half-played turn must not leak to the next
        // player (audit 2026-07-06, F6).
        dartsInTurn = 0;
        _turnIdCounter++;
        turnPoints = 0;
        turnHasHit = false;
        _advanceAfterRemoval();
      }
      // If only 1 (or 0) active players remain, end the game.
      final remaining = List.generate(players.length, (i) => i)
          .where((i) => !_removedPlayerIndices.contains(i))
          .toList();
      if (remaining.length <= 1) gameOver = true;
    });
    _log.logRoster(
      action: 'REMOVE',
      playerIndex: playerIndex,
      playerName: removed.name,
      names: players.map((p) => p.name).toList(),
      scores: totalScores,
    );
    if (gameOver) {
      _prepareRatingPreview().then((_) => _showPostGame());
    }
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content: const Text('Statistics will not be recorded for this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () {
              Navigator.pop(ctx);
              _performRemovePlayer(playerIndex);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Advances past a removed current player with the same round rules as
  /// [_finishTurn]: reaching the end of the rotation moves to the next round
  /// (or ends the game) — a modulo-wrap would replay the current round and
  /// double-count earlier players' turns (audit 2026-07-06, F6).
  void _advanceAfterRemoval() {
    int next = currentPlayerIndex + 1;
    while (next < players.length && _removedPlayerIndices.contains(next)) {
      next++;
    }
    if (next < players.length) {
      currentPlayerIndex = next;
      return;
    }
    // End of round
    if (currentRoundIndex == rounds.length - 1) {
      gameOver = true;
      return;
    }
    currentRoundIndex++;
    int first = 0;
    while (first < players.length && _removedPlayerIndices.contains(first)) {
      first++;
    }
    if (first >= players.length) {
      gameOver = true;
    } else {
      currentPlayerIndex = first;
    }
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
  final Set<int> clutchSaversBefore;

  _HalveItUndoData({
    required this.roundIndex,
    required this.playerIndex,
    required this.dartsInTurn,
    required this.turnPoints,
    required this.turnHasHit,
    required this.totalScoreBefore,
    required this.roundScoreBefore,
    required this.clutchSaversBefore,
  });
}
