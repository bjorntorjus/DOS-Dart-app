import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_result.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../models/shanghai_engine.dart';
import '../services/app_settings.dart';
import '../services/battery_sampler.dart';
import '../services/elo_service.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/player_storage.dart';
import '../services/shot_clock.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../utils/join_seed.dart';
import '../utils/player_colors.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
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
import '../utils/dossedart_player_accents.dart';
import '../models/setup_prefill.dart';
import 'player_setup_screen.dart';
import 'dossedart/dossedart_shanghai_setup_screen.dart';

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

  @visibleForTesting
  void removePlayerForTest(int playerIndex) {
    setState(() {
      _midGamePlayerChanges = true;
      final removedId = players[playerIndex].savedPlayerId;
      if (removedId != null) _leftMidGameIds.add(removedId);
      engine.removePlayer(playerIndex);
    });
  }

  @visibleForTesting
  Future<void> updateStatsForTest() => _updateStats(_rankPlayers());

  @visibleForTesting
  List<HitType> get turnHitsForTest => _turnHits;

  @visibleForTesting
  List<DartThrow> get throwHistoryForTest => throwHistory;

  @visibleForTesting
  int bestRoundForTest(int playerIndex) => _bestRoundFor(playerIndex);

  final GameLogger _log = GameLogger.instance;

  // Per-turn hit history for the dart-slot display.
  // Reset whenever a new turn starts. Length matches engine.dartNumber.
  final List<HitType> _turnHits = [];

  // Per-dart history feeding the active strip's live turn label (same
  // turnId-grouped pattern as the other DOSSEDART cockpits).
  List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;

  final MemeService _meme = MemeService();
  final GameAnnouncer _announcer = GameAnnouncer();
  bool _soundEnabled = true;
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;

  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
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
      build: kAppVersion,
    );
    BatterySampler.instance.start('Shanghai');
    _meme.init();
    AppSettings.getSoundEffectsEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
    });
    AppSettings.getMemeEnabled().then((v) {
      if (mounted) setState(() => _memeEnabled = v);
    });
    AppSettings.getMemeOffensive().then((v) {
      if (mounted) setState(() => _offensiveEnabled = v);
    });
    _announcer.init().then((_) {
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
    // engine.currentRound must be read BEFORE recordThrow, or the last active
    // player's 3rd dart gets tagged with the round the engine just advanced
    // to (recordThrow bumps currentRound on that dart), colliding with the
    // next round's bucket. Same capture-before-apply pattern as
    // golf_game_screen.dart's roundNo / one_up_game_screen.dart.
    final roundNo = engine.currentRound;

    setState(() {
      engine.recordThrow(type);
      _turnHits.add(type);
    });

    final scoreAfter = engine.totalScores[playerIdx];
    final pointsDelta = scoreAfter - scoreBefore;
    final logLabel = _logLabelForHit(type, target);

    _log.logThrow(
      roundNumber: roundNo,
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
      roundNumber: roundNo,
    );
    throwHistory.add(dartThrow);
    ShotClock.instance.registerDart();

    // Play core sound (miss/nice) before meme so meme can mark and skip TTS.
    if (type == HitType.miss) {
      _meme.tryMissSound();
    } else {
      SoundService.instance.play('nice/nice');
    }

    final memeTriggered = _meme.onThrow(dartThrow);
    if (!memeTriggered) {
      _announcer.announceThrow(_spokenForHit(type, target));
    }

    // Did the engine just advance to the next turn?
    final turnEnded = engine.dartNumber == 0;
    if (turnEnded) {
      // All 3 darts landed on the round's number (any mix of S/D/T) but not
      // an instant Shanghai — that path never reaches here, since the
      // engine leaves dartNumber at 3 (not reset to 0) on an instant win, so
      // turnEnded is false for it (see ShanghaiGameEngine.recordThrow).
      final holeCleared =
          _turnHits.length == 3 && _turnHits.every((h) => h != HitType.miss);
      _meme.onTurnEnd();
      _turnHits.clear();
      _turnIdCounter++;
      if (holeCleared && _memeEnabled) {
        SoundService.instance.playRandomMaybe(
          const ['shanghai/hole_cleared'],
          chance: _meme.frequencyChance,
        );
      }
      if (!engine.gameOver) {
        _log.logTurnStart(
          roundNumber: engine.currentRound,
          playerIndex: engine.currentPlayerIndex,
          playerName: players[engine.currentPlayerIndex].name,
          score: engine.totalScores[engine.currentPlayerIndex],
        );
        _log.logStandings(
          roundNumber: engine.currentRound,
          names: players.map((p) => p.name).toList(),
          scores: engine.totalScores,
        );
        _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
      }
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
    await _fireWinnerCelebration(players[ranking.first].name);
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
      gameMode: 'shanghai',
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

  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (engine.isInstantShanghai) {
      // Plain playRandom (not meme-gated) so this instant-win sting always
      // layers under the winner flow below, same as the other modes' win
      // stings.
      SoundService.instance.playRandom(const ['shanghai/shanghai']);
      _announcer.announceGameEvent('Instant Shanghai!');
    }
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }

  Future<void> _updateStats(List<int> ranking) async {
    if (_midGamePlayerChanges) {
      // Roster changed — record only join/leave counters and write NO game
      // entry. Recording a full game here stored placement 0 for removed
      // players (which sorts above 1st in history) and lost join/leave
      // counters entirely (audit 2026-07-06, F10). Now matches the other
      // five modes.
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

    // Reached only when the roster was unchanged (mid-game changes returned
    // early above), so Elo / achievements / persistence always apply here.
    EloService.updateRatings(
      gameMode: 'shanghai',
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
    final earnedFeats =
        buildEarnedFeats(eventsByIndex: events, unlocksByIndex: unlocks);

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

    await PlayerStorage.savePlayers(savedPlayers);
  }

  /// Max single-round points sum for [playerIndex], grouped by [DartThrow.
  /// roundNumber] from this screen's [throwHistory]. 0 when the player has no
  /// throws recorded (never happens post-game, but keeps this total).
  int _bestRoundFor(int playerIndex) {
    final byRound = <int, int>{};
    for (final t in throwHistory) {
      if (t.playerIndex != playerIndex) continue;
      byRound[t.roundNumber] = (byRound[t.roundNumber] ?? 0) + t.points;
    }
    if (byRound.isEmpty) return 0;
    return byRound.values.reduce((a, b) => a > b ? a : b);
  }

  void _showPostGame(List<int> ranking) {
    final results = <PlayerResult>[];
    for (int rank = 0; rank < ranking.length; rank++) {
      final i = ranking[rank];
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: rank + 1,
        stats: {
          'score': engine.totalScores[i],
          'bestRound': _bestRoundFor(i),
          // Only meaningful for the winner — an early sudden-death win via
          // an instant Shanghai (all three of a hole in one turn).
          if (engine.isInstantShanghai && i == engine.winnerIndex)
            'shanghai': true,
        },
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
          result: GameResult(
            durationSeconds:
                DateTime.now().difference(_gameStart).inSeconds,
            gameMode: 'shanghai',
            results: results,
            // Chart lines index by seat; a changed roster misaligns them —
            // suppress instead of mislabeling.
            throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory),
            progressionMode: _midGamePlayerChanges ? null : 'shanghai',
          ),
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
          // Post-game undo used to leave _turnHits stale (e.g. 3 slots after
          // an instant Shanghai) — rebuild it from the engine (F13).
          _rebuildTurnHits();
        });
        return;
      }
      if (action == 'again') {
        await _updateStats(ranking);
        if (!mounted) return;
        final ids = rematchPlayerIds(players, engine.isSkipped);
        final nav = Navigator.of(context);
        nav.popUntil((route) => route.isFirst);
        nav.push(MaterialPageRoute(
          builder: (_) => widget.useDossedartDesign
              ? DossedartShanghaiSetupScreen(
                  initialConfig: widget.config, initialPlayerIds: ids)
              : PlayerSetupScreen(
                  gameMode: GameMode.shanghai,
                  prefill: SetupPrefill(playerIds: ids, config: widget.config),
                ) as Widget,
        ));
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
    indices.sort(withSeatTiebreak(
        (a, b) => engine.totalScores[b].compareTo(engine.totalScores[a])));
    if (engine.isInstantShanghai && engine.winnerIndex != null) {
      indices.remove(engine.winnerIndex!);
      indices.insert(0, engine.winnerIndex!);
    }
    return indices;
  }

  /// Rebuilds the in-progress turn's dart slots ([_turnHits]) from the engine
  /// state and throwHistory. [_turnHits] is display-only state mirroring the
  /// engine; deriving it after an undo avoids the desync from trying to pop it
  /// (audit 2026-07-06, F13).
  void _rebuildTurnHits() {
    _turnHits.clear();
    final n = engine.dartNumber; // darts already thrown in the current turn
    if (n <= 0) return;
    final mine = throwHistory
        .where((t) => t.playerIndex == engine.currentPlayerIndex)
        .toList();
    final slice = mine.length <= n ? mine : mine.sublist(mine.length - n);
    for (final t in slice) {
      _turnHits.add(_hitTypeForThrow(t));
    }
  }

  HitType _hitTypeForThrow(DartThrow t) {
    if (t.segment == 0) return HitType.miss;
    switch (t.multiplier) {
      case 2:
        return HitType.double_;
      case 3:
        return HitType.triple;
      default:
        return HitType.single;
    }
  }

  void _onUndo() {
    if (engine.gameOver) return;
    // Add/remove player clears the engine's undo stack and engine.undo()
    // silently no-ops when empty — rewinding the screen-side history then
    // would desync the strip's turn grouping.
    if (!engine.canUndo) return;
    setState(() {
      engine.undo();
      if (throwHistory.isNotEmpty) {
        final lastThrow = throwHistory.removeLast();
        _turnIdCounter = lastThrow.turnId;
      }
      // Derive the in-progress turn's slots from the engine rather than
      // popping _turnHits — a turn-boundary undo (or post-game undo) can't be
      // reconstructed by removeLast, which desynced the dart slots (F13).
      _rebuildTurnHits();
    });
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.totalScores[engine.currentPlayerIndex],
      roundNumber: engine.currentRound,
    );
    _announcer.announceGameEvent('Back');
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
      isRemoved: (i) => engine.isSkipped(i),
      gameOver: engine.gameOver,
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
    // (tester feedback 2026-08-10). Shanghai accumulates, so the LOWEST total
    // is the worst position.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    final worst =
        worstSeat(engine.totalScores, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 0 : engine.totalScores[worst];
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: seedScore,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer(initialScore: seedScore);
    });
    _log.logRoster(
      action: 'ADD',
      playerIndex: players.length - 1,
      playerName: sp.name,
      names: players.map((p) => p.name).toList(),
      scores: engine.totalScores,
    );
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
              final removedId = players[playerIndex].savedPlayerId;
              setState(() {
                _midGamePlayerChanges = true;
                if (removedId != null) _leftMidGameIds.add(removedId);
                final wasCurrent = engine.currentPlayerIndex == playerIndex;
                engine.removePlayer(playerIndex);
                if (wasCurrent) _turnHits.clear();
                if (engine.gameOver) {
                  _onGameEnd();
                }
              });
              // removePlayer flags the index in the engine's skip set rather
              // than splicing — players[playerIndex] is still the removed
              // player after the mutation, so the name read below is safe.
              _log.logRoster(
                action: 'REMOVE',
                playerIndex: playerIndex,
                playerName: players[playerIndex].name,
                names: players.map((p) => p.name).toList(),
                scores: engine.totalScores,
              );
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
                accentColor: dossedartAccent(engine.currentPlayerIndex),
                dartsInTurn: engine.dartNumber,
                modeSlot: DossedartStripSlot(
                  label: 'ROUND ${engine.currentTarget}',
                  value: 'TARGET ${engine.currentTarget}',
                  subLine:
                      'S${engine.currentTarget} · D${engine.currentTarget * 2} · T${engine.currentTarget * 3}',
                ),
                scoreLabel: 'TOTAL',
                scoreValue: '${engine.totalScores[engine.currentPlayerIndex]}',
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
    ]..sort(withSeatTiebreak(
        (a, b) => engine.totalScores[b].compareTo(engine.totalScores[a])));
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
        ? 'HIT T$target FOR INSTANT WIN!'
        : 'S + D + T IN ONE TURN = INSTANT WIN';
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
                Text(hit ? '✓ HIT' : '—',
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
                      color: Theme.of(context).colorScheme.tertiary, width: 2)
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
