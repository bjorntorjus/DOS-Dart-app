import 'package:flutter/material.dart';
import '../data/checkout_table.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/gotcha_engine.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../services/achievement_service.dart';
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
import '../services/video_service.dart';
import '../theme/dossedart_tokens.dart';
import '../utils/join_seed.dart';
import '../utils/earned_feats_builder.dart';
import '../utils/gotcha_achievement_feats.dart';
import '../models/setup_prefill.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/gotcha/dossedart_gotcha_active_card.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';
import 'dossedart/dossedart_gotcha_setup_screen.dart';
import 'post_game_screen.dart';

/// The DOSSEDART Gotcha cockpit: race from 0 to an exact target, landing on
/// a living opponent's total resets them to 0. Assembles the [GotchaEngine]
/// (Task 2/3), [DossedartGotchaActiveCard] (Task 5) and the shared DOSSEDART
/// chrome (top bar / action bar / dartboard — identical to the X01 cockpit,
/// `game_screen.dart:1512-1617`) into a playable screen.
class GotchaGameScreen extends StatefulWidget {
  final List<Player> players;
  final GotchaConfig config;

  const GotchaGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<GotchaGameScreen> createState() => _GotchaGameScreenState();
}

class _GotchaGameScreenState extends State<GotchaGameScreen> {
  late List<Player> players;
  late GotchaEngine engine;

  @visibleForTesting
  GotchaEngine get engineForTest => engine;

  @visibleForTesting
  void onDartHitForTest(int segment, int multiplier) =>
      _onDartHit(segment, multiplier);

  @visibleForTesting
  void onUndoForTest() => _onUndo();

  @visibleForTesting
  Future<void> onGameEndForTest() => _onGameEnd();

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
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  @visibleForTesting
  List<int> rankPlayersForTest() => _rankPlayers();

  @visibleForTesting
  Future<void> updateStatsForTest() => _updateStats(_rankPlayers());

  /// Whether the roster changed mid-game — read by the stats/rating gating
  /// a later task adds (same contract as Shanghai's `_midGamePlayerChanges`).
  @visibleForTesting
  bool get midGamePlayerChangesForTest => _midGamePlayerChanges;

  final GameLogger _log = GameLogger.instance;

  // Per-dart history feeding the active card's live turn label (same
  // turnId-grouped pattern as the other DOSSEDART cockpits).
  List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;

  // Increments when the rotation wraps back to a seat at or before the
  // previous thrower's seat — mirrors the X01/Shanghai `_roundNumber`.
  int _roundNumber = 0;

  final MemeService _meme = MemeService();
  final GameAnnouncer _announcer = GameAnnouncer();

  // MemeService._enabled is private (no getter), so the explicit bust sound
  // hook below — which bypasses MemeService entirely — needs its own copy of
  // the toggle, loaded the same way as around_the_clock/cricket_game_screen.
  bool _memeEnabled = false;

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
    engine = GotchaEngine(
      target: widget.config.targetScore,
      playerCount: players.length,
      hardcore: widget.config.hardcore,
    );
    _log.logGameStart(
      gameMode: 'Gotcha',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {'targetScore': widget.config.targetScore, 'hardcore': widget.config.hardcore},
    );
    BatterySampler.instance.start('Gotcha');
    _meme.init();
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getSoundEffectsEnabled()
        .then((v) => SoundService.instance.setEnabled(v));
    _announcer.init();
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  void _onDartHit(int segment, int multiplier) {
    if (engine.gameOver) return;
    final playerIdx = engine.currentPlayerIndex;
    final dartNo = engine.dartsInTurn;
    final before = engine.totals[playerIdx];
    final turnStart = engine.turnStartScore;

    late GotchaDartResult result;
    setState(() => result = engine.applyDart(segment, multiplier));

    final delta = engine.totals[playerIdx] - before; // bust → negative revert
    final label = segment == 0
        ? 'miss'
        : (multiplier == 3
            ? 'T$segment'
            : multiplier == 2
                ? 'D$segment'
                : 'S$segment');

    throwHistory.add(DartThrow(
      playerIndex: playerIdx,
      segment: segment,
      multiplier: multiplier,
      points: delta,
      scoreBefore: before,
      turnNumber: dartNo,
      scoreAtStartOfTurn: turnStart,
      turnId: _turnIdCounter,
      roundNumber: _roundNumber,
      isBust: result.isBust,
    ));

    ShotClock.instance.registerDart();

    _log.logThrow(
      roundNumber: _roundNumber,
      playerIndex: playerIdx,
      label: label,
      points: delta,
      scoreBefore: before,
      scoreAfter: engine.totals[playerIdx],
      dartNumber: dartNo,
    );

    final memeTriggered = _meme.onThrow(throwHistory.last);

    if (result.playerWon) {
      _onGameEnd();
    } else if (result.isBust) {
      _announcer.announceGameEvent('Bust');
      // Explicit bust sound — announceGameEvent no longer carries it
      // (double-play fix, sound spec 2026-08-18). Reuses the same
      // frequency-derived chance as the miss-meme roll above. Gated on the
      // meme toggle: assets/sounds/bust/ already ships 15 real files, so an
      // ungated call here is audible today even with memes off.
      if (_memeEnabled) {
        SoundService.instance
            .playRandomMaybe(const ['bust'], chance: _meme.frequencyChance);
      }
    } else if (result.killed.isNotEmpty) {
      _announcer.announceKill(_killPhrase(result.killed));
      // Signature-moment video hook — folder has no assets in v1, silent
      // no-op (showRandomFromFolder degrades gracefully when empty).
      VideoService.instance.showRandomFromFolder(context, 'gotcha_kill');
    } else if (!memeTriggered) {
      _announcer.announceThrow(segment == 0 ? 'miss' : '${segment * multiplier}');
    }

    if (result.turnEnded) {
      _meme.onTurnEnd();
      if (!engine.gameOver) {
        _turnIdCounter++;
        if (engine.currentPlayerIndex <= playerIdx) _roundNumber++;
        _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
      }
    }
  }

  /// Builds the kill announcement phrase for [killed] victim indices, read
  /// AFTER `engine.applyDart` has already mutated `engine.totals` — halving
  /// mode reports the post-kill (halved) total, hardcore mode always reports
  /// zero. 'Double gotcha!' replaces 'Gotcha!' for 2+ victims (spec flavor).
  String _killPhrase(List<int> killed) {
    final prefix = killed.length > 1 ? 'Double gotcha!' : 'Gotcha!';
    if (widget.config.hardcore) {
      final names = [for (final k in killed) players[k].name].join(' and ');
      return '$prefix $names back to zero';
    }
    final parts = [
      for (final k in killed)
        '${players[k].name} halved to ${engine.totals[k]}'
    ].join(' and ');
    return '$prefix $parts';
  }

  void _onMiss() {
    _meme.tryMissSound();
    _onDartHit(0, 0);
  }

  void _onUndo() {
    if (engine.gameOver) return;
    if (!engine.canUndo) return;
    setState(() {
      engine.undo();
      if (throwHistory.isNotEmpty) {
        final lastThrow = throwHistory.removeLast();
        _turnIdCounter = lastThrow.turnId;
        _roundNumber = lastThrow.roundNumber;
      }
    });
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.totals[engine.currentPlayerIndex],
      roundNumber: _roundNumber,
    );
    _announcer.announceGameEvent('Back');
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
      gameMode: 'gotcha',
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
      if (rank > 0 && engine.totals[idx] == engine.totals[ranking[rank - 1]]) {
        placements[idx] = placements[ranking[rank - 1]];
      } else {
        placements[idx] = rank + 1;
      }
    }
    return placements;
  }

  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }

  /// Best non-bust 3-dart turn per player, from throwHistory turnId groups.
  Map<int, int> _highestTurns() {
    final byTurn = <(int, int), List<DartThrow>>{};
    for (final t in throwHistory) {
      (byTurn[(t.playerIndex, t.turnId)] ??= []).add(t);
    }
    final best = <int, int>{};
    for (final e in byTurn.entries) {
      if (e.value.any((t) => t.isBust)) continue;
      final sum = e.value.fold<int>(0, (s, t) => s + t.points);
      if (sum > (best[e.key.$1] ?? 0)) best[e.key.$1] = sum;
    }
    return best;
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
    final highestTurns = _highestTurns();

    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      if (engine.isSkipped(pi)) continue;
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'kills': engine.killsMade[pi],
        'timesKilled': engine.timesKilled[pi],
        'busts': engine.busts[pi],
        'max:highestTurn': highestTurns[pi] ?? 0,
        'totalDarts': throwHistory.where((t) => t.playerIndex == pi).length,
        'totalGames': 1,
      };
    }

    // Reached only when the roster was unchanged (mid-game changes returned
    // early above), so Elo / achievements / persistence always apply here.
    EloService.updateRatings(
      gameMode: 'gotcha',
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

    final events = gotchaEventsFromKillLog(engine.killLog);
    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.gotcha,
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
      gameMode: 'gotcha',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: 'Race to ${widget.config.targetScore}${widget.config.hardcore ? ' · Hardcore' : ''}',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _showPostGame(List<int> ranking) {
    final results = <PlayerResult>[];
    final highestTurns = _highestTurns();
    for (int rank = 0; rank < ranking.length; rank++) {
      final i = ranking[rank];
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: rank + 1,
        stats: {
          'score': engine.totals[i],
          'kills': engine.killsMade[i],
          'timesKilled': engine.timesKilled[i],
          'busts': engine.busts[i],
          'highestTurn': highestTurns[i] ?? 0,
          'darts': throwHistory.where((t) => t.playerIndex == i).length,
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
            gameMode: 'gotcha',
            results: results,
            // Chart lines index by seat; a changed roster misaligns them —
            // suppress instead of mislabeling.
            throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory),
            progressionMode: _midGamePlayerChanges ? null : 'gotcha',
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
            _roundNumber = lastThrow.roundNumber;
          }
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
          builder: (_) => DossedartGotchaSetupScreen(
            initialConfig: widget.config,
            initialPlayerIds: ids,
          ),
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
        (a, b) => engine.totals[b].compareTo(engine.totals[a])));
    if (engine.winnerIndex != null && !engine.isSkipped(engine.winnerIndex!)) {
      indices.remove(engine.winnerIndex!);
      indices.insert(0, engine.winnerIndex!);
    }
    return indices;
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
              _log.logExit(gameMode: 'Gotcha');
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
        primary: '${engine.totals[i]}',
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

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). Gotcha races up to a target, so the
    // LOWEST total is the worst position.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !engine.isSkipped(i))
        .toList();
    final worst = worstSeat(engine.totals, activeIndices, higherIsBetter: true);
    final seedScore = worst == null ? 0 : engine.totals[worst];
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
                engine.removePlayer(playerIndex);
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

  String? _checkoutRoute() {
    final remaining = engine.target - engine.totals[engine.currentPlayerIndex];
    final route =
        straightOutCheckout(remaining, dartsLeft: 3 - engine.dartsInTurn);
    return route?.replaceAll(' ', ' › ');
  }

  List<GotchaKillChip> _killChips() => [
        for (final (dart, idx) in engine.killTips())
          GotchaKillChip(dart: dart, name: players[idx].name.toUpperCase()),
      ];

  List<GotchaOpponentTick> _opponentTicks() {
    final dangerIdx = {for (final (_, idx) in engine.killTips()) idx};
    return [
      for (int i = 0; i < players.length; i++)
        if (i != engine.currentPlayerIndex && !engine.isSkipped(i))
          GotchaOpponentTick(
            initial:
                players[i].name.isEmpty ? '?' : players[i].name[0].toUpperCase(),
            total: engine.totals[i],
            danger: dangerIdx.contains(i),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cur = engine.currentPlayerIndex;

    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DossedartTopBar(
                title: '\u{1F480} GOTCHA \u{00B7} ${widget.config.targetScore}',
                onExit: _confirmExit,
                trailing: 'TARGET ${widget.config.targetScore}',
              ),
              DossedartGotchaActiveCard(
                playerName: players[cur].name,
                avatarPath: players[cur].avatarPath,
                // One-colour logic (locked design rule): the active thrower
                // is always cyan; chrome stays magenta.
                accentColor: DossedartTokens.cyan,
                total: engine.totals[cur],
                target: engine.target,
                currentDartIndex: engine.dartsInTurn,
                lastTurnLabel: throwHistory.recentTurnLabel(cur),
                lastTurnSum: throwHistory.recentTurnLabel(cur) == null
                    ? null
                    : throwHistory.recentTurnSum(cur),
                checkoutRoute: _checkoutRoute(),
                kills: _killChips(),
                opponents: _opponentTicks(),
              ),
              // The whole field below the score is a MISS zone; the board
              // sits on top, so any tap off the board registers as a miss.
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onMiss,
                      ),
                    ),
                    // Bottom-anchored so active-card height changes eat the
                    // gap ABOVE the board — tap targets never move between
                    // darts.
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 24,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: DossedartTokens.magenta
                                    .withValues(alpha: 0.23),
                                blurRadius: 70,
                              ),
                            ],
                          ),
                          child: DossedartX01Dartboard(
                            onTap: (zone) {
                              final (seg, mult) = zone.toSegmentMultiplier();
                              if (seg == 0) {
                                _onMiss();
                              } else {
                                _onDartHit(seg, mult);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DossedartActionBar(
                onUndo: _onUndo,
                onMiss: _onMiss,
                onMenu: () => showDossedartCockpitMenu(
                  context,
                  meme: _meme,
                  activePlayerCount: Iterable<int>.generate(players.length)
                      .where((i) => !engine.isSkipped(i))
                      .length,
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
}
