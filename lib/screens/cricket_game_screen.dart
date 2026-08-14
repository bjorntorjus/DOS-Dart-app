import 'dart:math';
import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/cricket_engine.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../utils/join_seed.dart';
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
import '../widgets/continue_prompt_dialog.dart';
import '../widgets/player_avatar.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
import '../utils/earned_feats_builder.dart';
import '../services/achievement_service.dart';
import '../utils/cricket_achievement_feats.dart';
import '../models/saved_player.dart';
import 'post_game_screen.dart';
import '../services/battery_sampler.dart';
import '../theme/dossedart_tokens.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_active_strip.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/dossedart_player_avatar.dart';
import '../utils/dossedart_player_accents.dart';
import '../models/setup_prefill.dart';
import 'player_setup_screen.dart';
import 'dossedart/dossedart_cricket_setup_screen.dart';

class CricketGameScreen extends StatefulWidget {
  final List<Player> players;
  final CricketConfig config;
  final bool useDossedartDesign;

  const CricketGameScreen({
    super.key,
    required this.players,
    required this.config,
    this.useDossedartDesign = false,
  });

  @override
  State<CricketGameScreen> createState() => _CricketGameScreenState();
}

class _CricketGameScreenState extends State<CricketGameScreen> {
  /// Shared height for mark buttons and progress bars — guarantees equal sizing.

  late List<Player> players;
  late List<int> targets;
  late CricketEngine engine;
  int _turnIdCounter = 0;
  List<DartThrow> throwHistory = [];
  String? lastThrowLabel;
  bool _gameFullyOver = false;

  // Delegating views onto the engine — all rules state (marks, scores,
  // rotation, darts-in-turn, finished/removed players, winner) lives in the
  // engine. These keep the ~1800 lines of UI code reading by the same names.
  List<Map<int, int>> get marks => engine.marks;
  List<int> get scores => engine.scores;
  int get currentPlayerIndex => engine.currentPlayerIndex;
  int get dartsInTurn => engine.dartsInTurn;
  List<int> get finishedPlayers => engine.finishedPlayers;
  int? get winnerIndex => engine.winnerIndexExcludingSkipped();
  Set<int> get _removedPlayerIndices => engine.skippedIndices;

  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  bool _soundEnabled = true;
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;
  bool _missSoundPlayed = false;
  int _consecutiveMisses = 0;
  int _scoreAtStartOfTurn = 0;
  String? _pendingVideoEvent;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    targets = widget.config.generateTargets();
    engine = CricketEngine(
      targets: targets,
      isCutthroat: widget.config.isCutthroat,
      playerCount: players.length,
    );
    for (final p in players) {
      p.score = 0;
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
      gameMode: widget.config.isCutthroat ? 'Cricket (Cutthroat)' : 'Cricket',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {
        'targets': targets.map((t) => t == 25 ? 'Bull' : '$t').toList(),
        if (widget.config.isCutthroat) 'cutthroat': true,
      },
      build: kAppVersion,
    );
    BatterySampler.instance.start('Cricket');
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  int get _roundNumber {
    if (throwHistory.isEmpty) return 1;
    final turnsForCurrentPlayer =
        throwHistory.where((t) => t.playerIndex == currentPlayerIndex).length;
    return (turnsForCurrentPlayer ~/ 3) + 1;
  }

  Future<void> _registerHit(int segment, int multiplier) async {
    if (finishedPlayers.contains(currentPlayerIndex)) return;

    final points = segment * multiplier;
    final roundNum = _roundNumber;
    // Capture the pre-hit state the log/label/announcer lines need — the engine
    // advances the current player internally on a turn end, so these must be
    // read before applyHit.
    final playerIdxBefore = engine.currentPlayerIndex;
    final scoreBefore = engine.scores[playerIdxBefore];
    final isTargetSegment = segment > 0 && targets.contains(segment);
    final marksBeforeSeg =
        isTargetSegment ? (engine.marks[playerIdxBefore][segment] ?? 0) : 0;

    final dartThrow = DartThrow(
      playerIndex: playerIdxBefore,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: scoreBefore,
      turnNumber: engine.dartsInTurn,
      scoreAtStartOfTurn: scoreBefore,
      turnId: _turnIdCounter,
      // Without this every dart lands in round 0, so the MATCH FLOW chart
      // groups the whole game into one bucket and collapses to two points —
      // start and finish (tester feedback 2026-08-10). roundNum is captured
      // above, before the throw joins throwHistory, because _roundNumber is
      // derived FROM throwHistory.
      roundNumber: roundNum,
    );

    // Video gating lives entirely in VideoService.shouldPlay (video-damping
    // 2026-07-22). The old meme-frequency pre-roll here meant the meme slider
    // silently changed how often videos played (audit 2026-08-10, F2).
    final videoRoll = VideoService.instance.shouldPlay();

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

    late final CricketHitResult result;

    setState(() {
      throwHistory.add(dartThrow);
      ShotClock.instance.registerDart();

      // All scoring / overflow / cutthroat / mark bookkeeping happens in the
      // engine. applyHit also pushes its own undo snapshot, runs the winner
      // check, and (on a non-finishing turn end) advances the current player.
      result = engine.applyHit(segment, multiplier);

      String? extraInfo;

      if (isTargetSegment) {
        final newMarks = engine.marks[playerIdxBefore][segment] ?? 0;
        final overflow =
            CricketEngine.computeOverflow(marksBeforeSeg, multiplier);
        final scoredOverflow = overflow > 0 && !engine.isClosedByAll(segment);
        if (scoredOverflow) {
          final pts = segment * overflow;
          extraInfo = widget.config.isCutthroat
              ? 'cutthroat ${pts}pts to opponents marks=$newMarks'
              : 'scoring ${pts}pts marks=$newMarks';
        } else {
          extraInfo = newMarks >= 3
              ? 'closed ${segment == 25 ? "Bull" : "T$segment"} marks=$newMarks'
              : 'marks=$newMarks';
        }

        final markStr = newMarks >= 3 ? '(Closed!)' : '($newMarks/3)';
        lastThrowLabel = '${dartThrow.label} $markStr';
        if (result.closedTarget) {
          _announcer.announceGameEvent('Closed');
        } else {
          _announcer.announceThrow(dartThrow.spokenLabel);
        }
      } else {
        lastThrowLabel = segment == 0 ? 'Miss' : dartThrow.label;
        extraInfo = segment == 0 ? 'miss' : 'non-target';
        if (!(segment == 0 && _missSoundPlayed)) {
          _announcer
              .announceThrow(segment == 0 ? 'Miss' : dartThrow.spokenLabel);
        }
      }

      _log.logThrow(
        roundNumber: roundNum,
        playerIndex: playerIdxBefore,
        label: dartThrow.label,
        points: engine.scores[playerIdxBefore] - scoreBefore,
        scoreBefore: scoreBefore,
        scoreAfter: engine.scores[playerIdxBefore],
        dartNumber: dartThrow.turnNumber,
        extra: extraInfo,
      );

      _meme.onThrow(dartThrow);

      if (result.playerFinished) {
        final finishedIdx = engine.finishedPlayers.last;
        _log.logFinish(
          roundNumber: roundNum,
          playerIndex: finishedIdx,
          playerName: players[finishedIdx].name,
          details:
              'score=${engine.scores[finishedIdx]} placement=#${engine.finishedPlayers.length}',
        );
        if (!engine.gameOver) {
          // Intermediate finish — announce immediately; no winner video coming
          _announcer.announceWinner(players[finishedIdx].name);
        }
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
      } else if (result.turnEnded) {
        // Turn ended by throwing three darts — the engine already advanced to
        // the next active player.
        final turnTotal = engine.scores[playerIdxBefore] - _scoreAtStartOfTurn;
        if (turnTotal >= 120) _pendingVideoEvent ??= 'high_round';
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
      }

      if (result.turnEnded) {
        // Mirror the old _advancePlayer's turnId bump so the next turn's darts
        // group under a fresh id (regression: cricket_turn_id_test).
        _turnIdCounter++;
      }

      if (engine.gameOver) _gameFullyOver = true;

      // Announce / log the newly active player only when the turn ended by
      // advancing — not on a finish (which keeps the finisher current for the
      // post-game screen) and not once the game is over.
      if (result.turnEnded && !result.playerFinished && !engine.gameOver) {
        _log.logAdvance(
          roundNumber: _roundNumber,
          fromIndex: playerIdxBefore,
          toIndex: engine.currentPlayerIndex,
          toName: players[engine.currentPlayerIndex].name,
          toScore: engine.scores[engine.currentPlayerIndex],
          reason: 'turn complete',
        );
        _log.logTurnStart(
          roundNumber: _roundNumber,
          playerIndex: engine.currentPlayerIndex,
          playerName: players[engine.currentPlayerIndex].name,
          score: engine.scores[engine.currentPlayerIndex],
        );
        _log.logStandings(
          roundNumber: _roundNumber,
          names: players.map((p) => p.name).toList(),
          scores: engine.scores,
        );
        _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
        _scoreAtStartOfTurn = engine.scores[engine.currentPlayerIndex];
      }
    });

    // Show video at turn end only
    if (result.turnEnded && _pendingVideoEvent != null && videoRoll) {
      await VideoService.instance
          .showRandomFromFolder(context, _pendingVideoEvent!,
              alreadyDecided: true);
    }
    if (result.turnEnded) _pendingVideoEvent = null;
    if (!mounted) return;

    if (_gameFullyOver && finishedPlayers.isNotEmpty) {
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(players[winnerIndex!].name);
      _showPostGame();
    } else if (finishedPlayers.contains(currentPlayerIndex) && !_gameFullyOver) {
      final active = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .length;
      if (active > 1) {
        _promptContinueOrEnd();
      } else {
        // One (or zero) active left — the game is decided; skip the question.
        _gameFullyOver = true;
        _showPostGame();
      }
    }
  }

  void _onMiss() {
    _missSoundPlayed = _meme.tryMissSound();
    _registerHit(0, 0);
  }

  /// The finisher's seat is still current when this fires (the engine leaves
  /// the finisher current so the screen can show them).
  Future<void> _promptContinueOrEnd() async {
    final finisherName = players[currentPlayerIndex].name;
    final remaining = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .length;
    final keepPlaying = await showContinuePrompt(
      context,
      finisherName: finisherName,
      remainingCount: remaining,
      dossedart: widget.useDossedartDesign,
    );
    if (!mounted) return;
    if (keepPlaying) {
      _log.logPostGame(action: 'continue', details: 'game continues with remaining players');
      setState(_advanceToNextActivePlayer);
      return;
    }
    setState(() => _gameFullyOver = true);
    _showPostGame(); // does the rating preview itself when fully over
  }

  /// Advances the engine's current seat to the next active (not finished, not
  /// removed) player. Used only by the continue-prompt flow — after an
  /// intermediate finish the engine leaves the finisher current so the screen
  /// can show them, so resuming play needs an explicit advance. The engine
  /// exposes no public advance, so this walks its public rotation state.
  void _advanceToNextActivePlayer() {
    final start = engine.currentPlayerIndex;
    var idx = start;
    do {
      idx = (idx + 1) % engine.playerCount;
      if (idx == start) break;
    } while (engine.finishedPlayers.contains(idx) || engine.isSkipped(idx));
    engine.currentPlayerIndex = idx;
    engine.dartsInTurn = 0;
    _turnIdCounter++;
    _scoreAtStartOfTurn = engine.scores[idx];
    _log.logAdvance(
      roundNumber: _roundNumber,
      fromIndex: start,
      toIndex: idx,
      toName: players[idx].name,
      toScore: engine.scores[idx],
      reason: 'continue',
    );
    _announcer.announceNextPlayer(players[idx].name);
  }

  void _undo() {
    // Roster changes clear the engine's undo stack (a snapshot never outlives
    // an add/remove), so a removed player can never be resurrected and the
    // restored current seat is always a valid active player — the old manual
    // re-assertions (F9) are gone with the parallel state.
    if (throwHistory.isEmpty || !engine.canUndo) return;
    final lastThrow = throwHistory.last;
    _announcer.announceGameEvent('Back');
    setState(() {
      engine.undo();
      throwHistory.removeLast();
      _turnIdCounter = lastThrow.turnId;
      _gameFullyOver = false;
      lastThrowLabel = null;
    });
    _log.logUndo(
      playerIndex: lastThrow.playerIndex,
      playerName: players[lastThrow.playerIndex].name,
      throwLabel: lastThrow.label,
      scoreRestored: engine.scores[lastThrow.playerIndex],
      roundNumber: _roundNumber,
    );
  }

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final DateTime _gameStart = DateTime.now();
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};

  @visibleForTesting
  List<int> get finishedPlayersForTest => finishedPlayers;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => _removedPlayerIndices;

  @visibleForTesting
  int? get winnerIndexForTest => winnerIndex;

  @visibleForTesting
  int? computeWinnerForTest() => engine.winnerIndexExcludingSkipped();

  @visibleForTesting
  GameResult buildGameResultForTest() => _buildGameResult();

  @visibleForTesting
  Future<void> registerHitForTest(int segment, int multiplier) =>
      _registerHit(segment, multiplier);

  @visibleForTesting
  void undoForTest() => _undo();

  @visibleForTesting
  void removePlayerForTest(int playerIndex) => _performRemovePlayer(playerIndex);

  @visibleForTesting
  int get currentPlayerIndexForTest => currentPlayerIndex;

  @visibleForTesting
  int get scoreAtStartOfTurnForTest => _scoreAtStartOfTurn;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  /// Computes final placements for all players.
  /// Finished players keep their finish order.
  /// Remaining players are ranked by: score (desc/asc for cutthroat),
  /// then closed targets (desc), then total marks (desc). Ties share a rank.
  List<int> _computeExitPlacements() {
    final result = List<int>.filled(players.length, 0);
    // Removed players forfeited — exclude them from the finish ranking so a
    // removed player who landed first in [finishedPlayers] cannot push the real
    // finishers down a place (or take 1st themselves).
    final rankedFinished =
        finishedPlayers.where((p) => !_removedPlayerIndices.contains(p)).toList();
    for (int i = 0; i < rankedFinished.length; i++) {
      result[rankedFinished[i]] = i + 1;
    }
    final remaining = List.generate(players.length, (i) => i)
        .where((i) =>
            !finishedPlayers.contains(i) && !_removedPlayerIndices.contains(i))
        .toList();
    if (remaining.isEmpty) return result;

    remaining.sort(withSeatTiebreak((a, b) {
      final scoreComp = widget.config.isCutthroat
          ? scores[a].compareTo(scores[b])
          : scores[b].compareTo(scores[a]);
      if (scoreComp != 0) return scoreComp;
      final closedA = targets.where((t) => engine.isClosed(t, a)).length;
      final closedB = targets.where((t) => engine.isClosed(t, b)).length;
      if (closedB != closedA) return closedB.compareTo(closedA);
      final marksA = targets.fold(0, (s, t) => s + (marks[a][t] ?? 0));
      final marksB = targets.fold(0, (s, t) => s + (marks[b][t] ?? 0));
      return marksB.compareTo(marksA);
    }));

    final base = rankedFinished.length + 1;
    int place = base;
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0) {
        final prev = remaining[i - 1];
        final curr = remaining[i];
        final sameScore = scores[prev] == scores[curr];
        final prevClosed = targets.where((t) => engine.isClosed(t, prev)).length;
        final currClosed = targets.where((t) => engine.isClosed(t, curr)).length;
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

  /// Computes the rating deltas this finish WILL produce so the result screen
  /// can show them, without persisting anything. Actual recording is deferred
  /// until the user leaves the result screen (see [_showPostGame]) so that
  /// "↶ Back" never leaves stale or duplicate stats behind — the fix for the
  /// 2026-07-06 audit's F3 (the old _statsRecorded flag was never reset by
  /// undo, so a replayed ending was silently dropped).
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
      gameMode: widget.config.isCutthroat ? 'cricket_cutthroat' : 'cricket',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _computeExitPlacements(),
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
    // A shared first place (possible when the game ends early and remaining
    // players tie on score) is a draw — nobody gets win credit.
    final firstIsShared = placements.where((p) => p == 1).length > 1;
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      savedPlayers[idx].gamesPlayed++;
      if (placements[pi] == 1 && !firstIsShared) {
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
      gameMode: widget.config.isCutthroat ? 'cricket_cutthroat' : 'cricket',
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
    final achEvents = <int, List<AchievementEvent>>{};
    final targetSet = targets.toSet();
    for (int i = 0; i < players.length; i++) {
      if (cricketMaxMarksInTurn(
              throwHistory, targetSet, i, players.length) >=
          9) {
        achEvents[i] = [AchievementEvent.nineMarkTurn];
      }
    }
    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.cricket,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      eventsByIndex: achEvents,
    );
    StatsRecorder.recordGame(
      gameMode: widget.config.isCutthroat ? 'cricket_cutthroat' : 'cricket',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: widget.config.isCutthroat ? 'Cricket · Cutthroat' : 'Cricket',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex:
          buildEarnedFeats(eventsByIndex: achEvents, unlocksByIndex: unlocks),
    );
    await PlayerStorage.savePlayers(savedPlayers);
  }

  GameResult _buildGameResult() {
    final placements = _computeExitPlacements();
    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      // Players removed mid-game must not appear on the result screen at all —
      // and never as the winner.
      if (_removedPlayerIndices.contains(i)) continue;
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
    return GameResult(
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      gameMode: 'cricket',
      results: results,
      // Chart lines index by seat; a changed roster misaligns them —
      // suppress instead of mislabeling.
      throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory),
      progressionMode: _midGamePlayerChanges ? null : 'cricket',
    );
  }

  void _showPostGame() async {
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: finishedPlayers,
      gameFullyOver: _gameFullyOver,
    );
    BatterySampler.instance.stop();
    // Preview rating deltas so they're visible on the result screen; actual
    // recording is deferred until the user leaves (defer-until-leave).
    if (_gameFullyOver) {
      await _prepareRatingPreview();
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
    } else if (result == 'again') {
      _log.logPostGame(action: 'again');
      if (!_gameFullyOver) _gameFullyOver = true;
      await _updateStats();
      if (!mounted) return;
      final ids = rematchPlayerIds(players, _removedPlayerIndices.contains);
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
      nav.push(MaterialPageRoute(
        builder: (_) => widget.useDossedartDesign
            ? DossedartCricketSetupScreen(
                initialConfig: widget.config, initialPlayerIds: ids)
            : PlayerSetupScreen(
                gameMode: GameMode.cricket,
                prefill: SetupPrefill(playerIds: ids, config: widget.config),
              ) as Widget,
      ));
    } else {
      _log.logPostGame(action: 'exit', details: 'gameFullyOver=$_gameFullyOver');
      // Leaving the game — record stats now. Recording is deferred to this
      // point (not done when the game ended) so a post-game Undo never
      // strands persisted stats; see _prepareRatingPreview.
      if (!_gameFullyOver) _gameFullyOver = true;
      await _updateStats();
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

  /// In-progress turn's darts joined live (e.g. "S5 · S6 · MISS"); falls back
  /// to the active player's previous turn between turns. Per-dart suffixes
  /// (mark glyphs) are dropped — they do not fit the joined 3-dart row.
  String? get _stripTurnLabel =>
      throwHistory.recentTurnLabel(currentPlayerIndex);

  /// Total marks scored (own count toward closing/overflow, not opponents'
  /// cutthroat overflow) in the current player's most recent turn — the same
  /// turn window [_stripTurnLabel] groups by (turnId), derived from the same
  /// throwHistory data.
  int get _lastTurnMarks {
    final darts = throwHistory
        .where((t) => t.playerIndex == currentPlayerIndex)
        .toList();
    if (darts.isEmpty) return 0;
    final lastTurnId = darts.last.turnId;
    return darts
        .where((t) => t.turnId == lastTurnId)
        .fold(0, (sum, t) => sum + (targets.contains(t.segment) ? t.multiplier : 0));
  }

  /// Index of the UNIQUE best score among non-removed players — Cutthroat
  /// flips it (lowest score leads); any tie (including the all-zero opening
  /// state) yields no leader. Feeds the grid header's 👑.
  int? get _dossedartLeaderIndex {
    final activeIdx = List.generate(players.length, (i) => i)
        .where((i) => !_removedPlayerIndices.contains(i))
        .toList();
    if (activeIdx.isEmpty) return null;
    final best = widget.config.isCutthroat
        ? activeIdx.map((i) => scores[i]).reduce(min)
        : activeIdx.map((i) => scores[i]).reduce(max);
    final tops = activeIdx.where((i) => scores[i] == best).toList();
    return tops.length == 1 ? tops.first : null;
  }

  /// 3-char handle for the grid's compact header cells — same derivation as
  /// the other DOSSEDART cockpits (wildcard_game_screen/dossedart_home_screen
  /// `_handleFor`): strips non-alphanumerics, uppercases, pads short names.
  String _handleFor(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length >= 3) return cleaned.substring(0, 3);
    return cleaned.padRight(3, 'X');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
    return _buildClassicScaffold(context);
  }

  // ---------------------------------------------------------------------------
  // DOSSEDART arcade cockpit — input model A: the scoreboard IS the input.
  // The active player's column expands into tappable S/D/T cells; opponents
  // render read-only phosphor glyphs. A target is dead only when ALL have
  // closed it (isClosedByAll). No new game logic — every cell feeds the same
  // _registerHit(segment, multiplier) the classic screen uses.
  // ---------------------------------------------------------------------------

  Widget _buildDossedartCockpit(BuildContext context) {
    final title =
        'CRICKET · ${widget.config.isCutthroat ? 'CUTTHROAT' : 'STANDARD'}';
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: title,
                onExit: _confirmExit,
                trailing: 'RND $_roundNumber',
              ),
              DossedartActiveStrip(
                playerName: players[currentPlayerIndex].name,
                avatarPath: players[currentPlayerIndex].avatarPath,
                accentColor: dossedartAccent(currentPlayerIndex),
                dartsInTurn: dartsInTurn,
                modeSlot: DossedartStripSlot(
                  label: 'LAST TURN',
                  value: _stripTurnLabel ?? '— · — · —',
                  subLine: _stripTurnLabel != null
                      ? '= $_lastTurnMarks MARKS'
                      : 'NO DARTS YET',
                  dim: _stripTurnLabel == null,
                ),
                scoreLabel: 'POINTS',
                scoreValue: '${scores[currentPlayerIndex]}',
              ),
              Expanded(child: _dossedartMatrix()),
              DossedartActionBar(
                onUndo: _undo,
                onMiss: _onMiss,
                onMenu: () => _showDossedartMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dossedartMatrix() {
    final magenta55 = DossedartTokens.magenta.withValues(alpha: 0.33);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: magenta55, width: 2),
        ),
        child: Column(
          children: [
            _dossedartMatrixHeader(),
            for (int ti = 0; ti < targets.length; ti++)
              Expanded(
                child:
                    _dossedartMatrixRow(targets[ti], ti == targets.length - 1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dossedartMatrixHeader() {
    final magenta = DossedartTokens.magenta;
    return Container(
      decoration: BoxDecoration(
        color: magenta.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: magenta.withValues(alpha: 0.33), width: 2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const SizedBox(
              width: 56,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'TGT',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: Colors.white54,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            for (int pi = 0; pi < players.length; pi++)
              Expanded(
                flex: pi == currentPlayerIndex ? 27 : 10,
                child: _dossedartPlayerHeader(pi),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dossedartPlayerHeader(int pi) {
    final active = pi == currentPlayerIndex;
    final c = dossedartAccent(pi);
    final isLeader = pi == _dossedartLeaderIndex;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: active ? c.withValues(alpha: 0.08) : Colors.transparent,
        border: Border(
          left: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.2), width: 1),
          top: active ? BorderSide(color: c, width: 3) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DossedartPlayerAvatar(
            avatarPath: players[pi].avatarPath,
            size: 26,
            borderColor: c,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _handleFor(players[pi].name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    letterSpacing: 0.5,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              if (isLeader) ...[
                const SizedBox(width: 4),
                const Text('👑', style: TextStyle(fontSize: 10, height: 1)),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${scores[pi]}',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 17,
              color: c,
              shadows: [
                Shadow(color: c.withValues(alpha: 0.6), blurRadius: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dossedartMatrixRow(int target, bool isLast) {
    final closedByAll = engine.isClosedByAll(target);
    final isBull = target == 25;
    final label = isBull ? 'BULL' : '$target';
    final magenta = DossedartTokens.magenta;
    final yellow = DossedartTokens.yellow;
    return Opacity(
      opacity: closedByAll ? 0.3 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: magenta.withValues(alpha: 0.13), width: 1),
                ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: isBull ? 11 : 19,
                        color: closedByAll ? Colors.white38 : yellow,
                        letterSpacing: 1,
                        shadows: closedByAll
                            ? null
                            : [
                                Shadow(
                                    color: yellow.withValues(alpha: 0.55),
                                    blurRadius: 8),
                              ],
                      ),
                    ),
                    if (closedByAll) ...[
                      const SizedBox(height: 2),
                      Text(
                        'DEAD',
                        style: TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            for (int pi = 0; pi < players.length; pi++)
              Expanded(
                flex: pi == currentPlayerIndex ? 27 : 10,
                child: pi == currentPlayerIndex
                    ? _dossedartActiveCell(target)
                    : _dossedartGlyphCell(pi, marks[pi][target] ?? 0),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dossedartActiveCell(int target) {
    final c = dossedartAccent(currentPlayerIndex);
    final own = marks[currentPlayerIndex][target] ?? 0;
    // Artboard's own-closed ⊗-lock (hiding S/D/T once the active player's own
    // marks hit 3) dropped: it's a BEHAVIOR change vs. standard Cricket
    // overflow scoring, and rules win over artboards per the 2026-07-23
    // handover protocol. Only closedByAll (nobody can score any more) locks
    // the cell; a personally-closed-but-still-live target stays tappable —
    // the fully-filled meter below is the "you closed this" signal instead.
    final closedByAll = engine.isClosedByAll(target);
    final isBull = target == 25;
    final List<(String, int, bool)> subs = isBull
        ? const [('BULL', 1, false), ('D-BULL', 2, false), ('—', 0, true)]
        : [('$target', 1, false), ('D$target', 2, false), ('T$target', 3, false)];

    return Container(
      color: c.withValues(alpha: 0.06),
      child: Stack(
        children: [
          if (closedByAll)
            Center(
              child: Text(
                '⊗',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 26,
                  color: c.withValues(alpha: 0.85),
                  shadows: [
                    Shadow(color: c.withValues(alpha: 0.7), blurRadius: 12),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                for (final (label, mult, off) in subs)
                  Expanded(
                    child: off
                        ? Opacity(
                            opacity: 0.25,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                      color: c.withValues(alpha: 0.33),
                                      width: 1),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '—',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _registerHit(target, mult),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                      color: c.withValues(alpha: 0.33),
                                      width: 1),
                                ),
                              ),
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: label.length > 3 ? 11 : 14,
                                    color: c,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                          color: c.withValues(alpha: 0.6),
                                          blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
            Positioned(
              bottom: 5,
              left: 5,
              right: 5,
              child: IgnorePointer(
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          key: ValueKey('seg-$target-$i'),
                          height: 10,
                          decoration: BoxDecoration(
                            color: i < own
                                ? c
                                : Colors.black.withValues(alpha: 0.4),
                            border: Border.all(
                              color:
                                  i < own ? c : c.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: i < own
                                ? [
                                    BoxShadow(
                                        color: c.withValues(alpha: 0.7),
                                        blurRadius: 8),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dossedartGlyphCell(int pi, int n) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.13), width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: _dossedartGlyph(n, dossedartAccent(pi)),
    );
  }

  Widget _dossedartGlyph(int n, Color color) {
    if (n <= 0) {
      return Text(
        '·',
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 22,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      );
    }
    final size = players.length > 4 ? 20.0 : 24.0;
    if (n >= 3) {
      return Text(
        '⊗',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: size + 2,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.6), blurRadius: 9),
          ],
        ),
      );
    }
    return Text(
      n == 1 ? '/' : 'X',
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: size,
        color: color,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.6), blurRadius: 9),
        ],
      ),
    );
  }

  Future<void> _showDossedartMenu(BuildContext outerContext) {
    return showDossedartCockpitMenu(
      outerContext,
      meme: _meme,
      onTtsChanged: (v) => setState(() => _ttsEnabled = v),
      onPlayerOverview: _openDossedartPlayerSheet,
      onExit: _confirmExit,
    );
  }

  Widget _buildClassicScaffold(BuildContext context) {
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'players':
                  if (!_gameFullyOver) _openPlayerManagement();
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
                enabled: !_gameFullyOver,
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
          // Player header with avatars, scores, last darts
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow)),
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
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        i < dartsInTurn ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
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
                              ? Theme.of(context).colorScheme.primary
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
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4))
                              : null,
                        ),
                        child: Column(
                          children: [
                            PlayerAvatar(
                              avatarPath: players[pi].avatarPath,
                              name: players[pi].name,
                              radius: 18,
                              backgroundColor: avatarColor(pi),
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
                                color: Theme.of(context).colorScheme.onSurface,
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
                                    fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
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
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow)),
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                  final closedByAll = engine.isClosedByAll(target);
                  final isBull = target == 25;
                  // Every target — Bull included — closes at 3 marks (see
                  // _isClosed / marksForClose). The progress bar used 2 for
                  // Bull, so it read full at 2 of 3 (audit 2026-07-06, F12).
                  const maxMarks = 3;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: closedByAll
                            ? Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.47)
                            : Theme.of(context).colorScheme.surface,
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
                                  color: closedByAll ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Player columns — active player (flex 3) gets S/D/T buttons,
                          // inactive players (flex 1) get progress bars
                          ...List.generate(players.length, (pi) {
                            final isCurrent = pi == currentPlayerIndex;
                            final m = marks[pi][target] ?? 0;
                            final color = Theme.of(context).colorScheme.primary;
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
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
                    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
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
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
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
    final isDead = engine.isClosedByAll(target);
    final cs = Theme.of(context).colorScheme;
    final label = switch (multiplier) {
      2 => isBull ? 'DBull' : 'D$target',
      3 => 'T$target',
      _ => isBull ? 'Bull' : '$target',
    };
    return SizedBox.expand(
      child: Tooltip(
        message: isDead ? 'Closed by all players' : '',
        child: ElevatedButton(
          onPressed: isDead ? null : () => _registerHit(target, multiplier),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isFilled ? cs.primary.withValues(alpha: 0.7) : cs.surfaceContainer,
            foregroundColor: isFilled ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
            elevation: 0,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: isFilled ? cs.primary.withValues(alpha: 0.8) : cs.outline,
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
        primary: '${scores[i]}',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: _gameFullyOver,
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
      gameOver: _gameFullyOver,
      colorFor: avatarColor,
      addInfoText:
          'A new player starts level with whoever is in last place. '
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average — a
    // joiner should not arrive better off than the player who has been
    // struggling all game (tester feedback 2026-08-10). Active = not in
    // finishedPlayers; removed players are always also in finishedPlayers, so
    // this single check excludes them too.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    // The same ordering _computeExitPlacements uses, so "last" means the same
    // thing here as it does on the result screen — including cutthroat, where
    // the highest score is the worst.
    final worst = worstSeatBy(activeIndices, (a, b) {
      final scoreComp = widget.config.isCutthroat
          ? scores[a].compareTo(scores[b])
          : scores[b].compareTo(scores[a]);
      if (scoreComp != 0) return scoreComp;
      final closedA = targets.where((t) => engine.isClosed(t, a)).length;
      final closedB = targets.where((t) => engine.isClosed(t, b)).length;
      if (closedB != closedA) return closedB.compareTo(closedA);
      final marksA = targets.fold(0, (s, t) => s + (marks[a][t] ?? 0));
      final marksB = targets.fold(0, (s, t) => s + (marks[b][t] ?? 0));
      return marksB.compareTo(marksA);
    });

    final seedPoints = worst == null ? 0 : scores[worst];

    // A target closed by EVERY seat is dead. Copying a last-placed player who
    // never closed it would bring it back to life and let the whole table farm
    // it again — so the joiner is given 3 marks there regardless. Evaluated
    // before the add, or the joiner's own empty marks make isClosedByAll false.
    final newMarks = {
      for (final t in targets)
        t: engine.isClosedByAll(t)
            ? 3
            : (worst == null ? 0 : (marks[worst][t] ?? 0).clamp(0, 3))
    };

    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: seedPoints,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      // The engine grows its marks/scores lists (seeded with the table
      // averages) and resets its undo history — an undo snapshot taken before
      // the add has the old list lengths and would RangeError (audit
      // 2026-07-06, F8).
      engine.addPlayer(initialScore: seedPoints, initialMarks: newMarks);
    });
    _log.logRoster(
        action: 'ADD',
        playerIndex: players.length - 1,
        playerName: sp.name,
        names: players.map((p) => p.name).toList(),
        scores: engine.scores);
  }

  /// Production removal logic, shared by the confirm dialog and tests.
  void _performRemovePlayer(int playerIndex) {
    final removed = players[playerIndex];
    setState(() {
      _midGamePlayerChanges = true;
      if (removed.savedPlayerId != null) {
        _leftMidGameIds.add(removed.savedPlayerId!);
      }
      // The engine marks the seat skipped+finished, advances off it when it is
      // current, ends the game when ≤1 active player remains (F7), and clears
      // its undo history — all the rules state the screen used to touch here.
      final wasCurrent = engine.currentPlayerIndex == playerIndex;
      engine.removePlayer(playerIndex);
      if (wasCurrent) {
        _turnIdCounter++;
        if (!engine.gameOver) {
          // Restore the old _advancePlayer tail (log + announce + turn-start
          // refresh) that ran whenever the removed player was current — the
          // engine rewire dropped these, leaving a stale _scoreAtStartOfTurn
          // that skewed the next player's turnTotal (audit R5 final review).
          _log.logAdvance(
            roundNumber: _roundNumber,
            fromIndex: playerIndex,
            toIndex: engine.currentPlayerIndex,
            toName: players[engine.currentPlayerIndex].name,
            toScore: engine.scores[engine.currentPlayerIndex],
            reason: 'turn complete',
          );
          _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
          _scoreAtStartOfTurn = engine.scores[engine.currentPlayerIndex];
        }
      }
      if (engine.gameOver) _gameFullyOver = true;
    });
    _log.logRoster(
        action: 'REMOVE',
        playerIndex: playerIndex,
        playerName: removed.name,
        names: players.map((p) => p.name).toList(),
        scores: engine.scores);
    if (_gameFullyOver) _showPostGame();
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
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
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
