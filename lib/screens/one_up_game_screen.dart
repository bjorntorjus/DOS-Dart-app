import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/one_up_engine.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../services/achievement_service.dart';
import '../services/app_settings.dart';
import '../services/elo_service.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/player_storage.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/video_service.dart';
import '../theme/dossedart_tokens.dart';
import '../utils/dossedart_player_accents.dart';
import '../utils/earned_feats_builder.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';
import 'post_game_screen.dart';

/// Overlay moments the 1UP cockpit shows, one at a time, full-frame on top
/// of the Stack — a life lost, an elimination (with placement), or the
/// winner. Every kind dismisses on tap; [_OuOverlay.winner] additionally
/// triggers [_OneUpGameScreenState._onGameEnd] on dismiss.
enum _OuOverlay { lifeLost, eliminated, winner }

/// The DOSSEDART 1UP cockpit: each 3-dart turn must match or beat the
/// standing target or the thrower loses a life. Last player alive wins.
/// Assembles the [OneUpEngine] (Tasks 2-4), [DossedartOneUpActiveCard]
/// (Task 5) and the shared DOSSEDART chrome (top bar / action bar /
/// dartboard — identical to the other cockpits) into a playable screen.
///
/// Task 6 builds the core loop; Task 7 fills in `_onGameEnd`/stats and
/// Task 8 layers the turn-end overlays/announcements into `_handleTurnEnd`.
class OneUpGameScreen extends StatefulWidget {
  const OneUpGameScreen({super.key, required this.players, required this.config});

  final List<Player> players;
  final OneUpConfig config;

  @override
  State<OneUpGameScreen> createState() => _OneUpGameScreenState();
}

class _OneUpGameScreenState extends State<OneUpGameScreen> {
  late final OneUpEngine engine;
  late final List<Player> players;
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;
  final DateTime _gameStart = DateTime.now();

  // Roster-change gating for the deferred-stats protocol (Shanghai/Gotcha
  // parity). Not yet wired to the player sheet — Task 9 adds full roster
  // stats and flips these from add/removePlayerMidGame.
  // ignore: prefer_final_fields  // Task 9 mutates this to true.
  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  @visibleForTesting
  OneUpEngine get engineForTest => engine;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => engine.skippedIndices;

  @visibleForTesting
  void onGameEndForTest() => _onGameEnd();

  @visibleForTesting
  void onDartHitForTest(int s, int m) => _onDartHit(s, m);

  // ─── Moment overlays (Task 8) ────────────────────────────────
  _OuOverlay? _overlay;
  String _momentName = '';
  int _momentTarget = 0;

  /// The thrower's seat, captured in [_onDartHit] BEFORE `engine.applyDart`
  /// — `_handleTurnEnd` runs after the engine has already advanced
  /// `currentPlayerIndex` to the next player, so it can't be read there.
  int _lastThrowerSeat = 0;

  /// `engine.target` captured in [_onDartHit] BEFORE `engine.applyDart` —
  /// in BEAT THE LAST a failed turn overwrites `engine.target` with the
  /// (lower) failed total as a side effect of `_endTurn`, so by the time
  /// `_handleTurnEnd` runs the live value is no longer the number the
  /// thrower actually failed to beat.
  int _failedTarget = 0;

  @override
  void initState() {
    super.initState();
    players = List.of(widget.players);
    engine = OneUpEngine(
      playerCount: players.length,
      startingLives: widget.config.lives,
      variant: widget.config.variant,
      randomOrder: widget.config.randomOrder,
    );
    _announcer.init();
    _meme.init();
    AppSettings.getSoundEffectsEnabled()
        .then((v) => SoundService.instance.setEnabled(v));
    _log.logGameStart(
      gameMode: '1UP',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, widget.config.lives),
      config: {
        'lives': widget.config.lives,
        'variant': widget.config.variant.name,
        'randomOrder': widget.config.randomOrder,
      },
      build: kAppVersion,
    );
    _logTurn();
  }

  void _logTurn() {
    _log.logTurnStart(
      roundNumber: engine.roundNumber,
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      score: engine.livesLeft[engine.currentPlayerIndex],
    );
    _log.logStandings(
      roundNumber: engine.roundNumber,
      names: players.map((p) => p.name).toList(),
      scores: engine.livesLeft,
    );
    _log.log('R${engine.roundNumber} STATE '
        'target=${engine.target ?? '-'} '
        'setBy=${engine.targetSetBy >= 0 ? players[engine.targetSetBy].name : '-'} '
        'variant=${widget.config.variant.name}');
  }

  void _onDartHit(int segment, int multiplier) {
    if (engine.gameOver || _overlay != null) return;
    final playerIdx = engine.currentPlayerIndex;
    final dartNo = engine.dartsInTurn;
    final turnBefore = engine.turnPoints;
    _lastThrowerSeat = playerIdx;
    _failedTarget = engine.target ?? 0;

    final result = engine.applyDart(segment, multiplier);

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
      points: result.points,
      scoreBefore: turnBefore,
      turnNumber: dartNo,
      scoreAtStartOfTurn: 0,
      turnId: _turnIdCounter,
      roundNumber: engine.roundNumber,
    ));

    _log.logThrow(
      roundNumber: engine.roundNumber,
      playerIndex: playerIdx,
      label: label,
      points: result.points,
      scoreBefore: turnBefore,
      scoreAfter: turnBefore + result.points,
      dartNumber: dartNo,
    );

    // A completed turn opens a fresh turnId group for the next thrower.
    if (result.turnEnded && !engine.gameOver) _turnIdCounter++;

    setState(() {});
    if (result.turnEnded) _handleTurnEnd(result);
  }

  void _onMiss() {
    if (engine.gameOver || _overlay != null) return;
    SoundService.instance.play('miss/miss');
    _onDartHit(0, 0);
  }

  /// Routes a completed turn to the right MOMENTS overlay (life lost /
  /// elimination / winner), or the "big target" callout for a fresh
  /// 100+ target — [_lastThrowerSeat]/[_failedTarget] (captured in
  /// [_onDartHit] before the engine advanced) stand in for
  /// `engine.currentPlayerIndex`, which by now points at the NEXT thrower.
  void _handleTurnEnd(OneUpDartResult result) {
    final seat = _lastThrowerSeat;
    final name = players[seat].name.toUpperCase();
    if (result.playerWon) {
      final winnerName = players[engine.winnerIndex!].name;
      _announcer.announceOneUp(
        '$winnerName wins! Last player standing!',
        soundFolders: const ['one_up/winner', 'win'],
      );
      setState(() {
        _overlay = _OuOverlay.winner;
        _momentName = winnerName.toUpperCase();
      });
      return;
    }
    if (result.eliminated) {
      _announcer.announceOneUp('$name is eliminated!',
          soundFolders: const ['one_up/eliminated']);
      setState(() {
        _overlay = _OuOverlay.eliminated;
        _momentName = name;
      });
    } else if (result.lostLife) {
      _announcer.announceOneUp('$name loses a life!',
          soundFolders: const ['one_up/life_lost']);
      setState(() {
        _overlay = _OuOverlay.lifeLost;
        _momentName = name;
        _momentTarget = _failedTarget;
      });
    } else if (engine.targetSetBy == seat && (engine.target ?? 0) >= 100) {
      _announcer.announceOneUp('${engine.target}! Beat that!');
    }
    _logTurn();
  }

  /// Placement for the just-eliminated seat: `activePlayerCount` already
  /// excludes them (their elimination happened in `_endTurn`, before
  /// `_handleTurnEnd` ran) — the seat lands one place below everyone still
  /// alive. Proven against the brief's scenarios: 4 players, 1st out with
  /// 3 left alive → 4TH; 2nd out with 2 left alive → 3RD; with one removed
  /// seat (3 in-game), 1st out with 2 left alive → 3RD.
  int get _eliminationPlacement => engine.activePlayerCount + 1;

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}TH';
    switch (n % 10) {
      case 1:
        return '${n}ST';
      case 2:
        return '${n}ND';
      case 3:
        return '${n}RD';
      default:
        return '${n}TH';
    }
  }

  void _onUndo() {
    if (engine.gameOver) return;
    if (!engine.canUndo) return;
    setState(() {
      _overlay = null;
      engine.undo();
      if (throwHistory.isNotEmpty) {
        final lastThrow = throwHistory.removeLast();
        _turnIdCounter = lastThrow.turnId;
      }
    });
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.livesLeft[engine.currentPlayerIndex],
      roundNumber: engine.roundNumber,
    );
  }

  Future<void> _onGameEnd() async {
    final ranking = _rankPlayers();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    await _fireWinnerCelebration(players[ranking.first].name);
    if (!mounted) return;
    // Preview rating deltas so they're visible on the result screen even
    // though recording is deferred until the user leaves (audit F17).
    await _prepareRatingPreview(ranking);
    if (!mounted) return;
    _showPostGame(ranking);
  }

  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }

  /// Placements from [ranking]: winner-first elimination order, no tie-sharing
  /// (a 1UP finish is always strictly ordered — see [_rankPlayers]). Skipped
  /// seats stay at placement 0 and are excluded from Elo, same as Gotcha.
  List<int> _placementsFromRanking(List<int> ranking) {
    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < ranking.length; rank++) {
      placements[ranking[rank]] = rank + 1;
    }
    return placements;
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
      placements: _placementsFromRanking(ranking),
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

  Future<void> _updateStats(List<int> ranking) async {
    if (_midGamePlayerChanges) {
      // Roster changed — record only join/leave counters and write NO game
      // entry, matching the other five modes (audit 2026-07-06, F10).
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

    final placements = _placementsFromRanking(ranking);

    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      if (engine.isSkipped(pi)) continue;
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'livesLost': engine.livesLost[pi],
        'targetsSet': engine.targetsSet[pi],
        'turnsSurvived': engine.turnsSurvived[pi],
        'lastDartSaves': engine.lastDartSaves[pi],
        'elimsDealt': engine.elimsDealt[pi],
        'max:highestTurn': engine.highestTurn[pi],
        'totalDarts': throwHistory.where((t) => t.playerIndex == pi).length,
        'totalGames': 1,
      };
    }

    // Reached only when the roster was unchanged (mid-game changes returned
    // early above), so Elo / achievements / persistence always apply here.
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

    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.oneUp,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
    );
    final earnedFeats =
        buildEarnedFeats(eventsByIndex: const {}, unlocksByIndex: unlocks);

    StatsRecorder.recordGame(
      gameMode: 'oneUp',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: '${widget.config.lives} lives · '
          '${widget.config.variant == OneUpVariant.beatTheBest ? 'Beat the best' : 'Beat the last'}'
          '${widget.config.randomOrder ? ' · Shuffle' : ''}',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
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
        stats: {
          'highestTurn': engine.highestTurn[i],
          'targetsSet': engine.targetsSet[i],
          'livesLost': engine.livesLost[i],
          'turnsSurvived': engine.turnsSurvived[i],
          'lastDartSaves': engine.lastDartSaves[i],
          'elimsDealt': engine.elimsDealt[i],
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
          result: GameResult(gameMode: 'oneUp', results: results),
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

  /// Winner first, then reverse elimination order, then (for aborted games)
  /// surviving non-winners by lives desc; excludes skipped seats.
  List<int> _rankPlayers() {
    final ranked = <int>[];
    final w = engine.winnerIndex;
    if (w != null && !engine.isSkipped(w)) ranked.add(w);
    final alive = engine.aliveIndices.where((i) => i != w).toList()
      ..sort((a, b) => engine.livesLeft[b].compareTo(engine.livesLeft[a]));
    ranked.addAll(alive);
    for (final i in engine.eliminationOrder.reversed) {
      if (!engine.isSkipped(i) && !ranked.contains(i)) ranked.add(i);
    }
    return ranked;
  }

  /// Which primary content the active card shows for the current thrower.
  OneUpCardMode get _cardMode {
    if (engine.isFreeThrow) return OneUpCardMode.free;
    if (engine.hasBeatenTarget) return OneUpCardMode.safe;
    if (!engine.canStillBeat) return OneUpCardMode.cantBeat;
    return OneUpCardMode.normal;
  }

  String get _variantChip => widget.config.variant == OneUpVariant.beatTheBest
      ? 'BEAT THE BEST · R${engine.roundNumber}'
      : 'BEAT THE LAST';

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
              _log.logExit(gameMode: '1UP');
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
        primary: engine.isEliminated(i) ? 'OUT' : '${engine.livesLeft[i]} ♥',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: engine.gameOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText: 'Joins next round with ${widget.config.lives} lives.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    setState(() {
      players.add(Player(
        name: sp.name,
        score: 0,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer();
    });
    _log.logRoster(
      action: 'ADD',
      playerIndex: players.length - 1,
      playerName: sp.name,
      names: players.map((p) => p.name).toList(),
      scores: engine.livesLeft,
    );
  }

  void _removePlayerMidGame(int playerIndex) {
    setState(() {
      engine.removePlayer(playerIndex);
      if (engine.gameOver) _onGameEnd();
    });
    _log.logRoster(
      action: 'REMOVE',
      playerIndex: playerIndex,
      playerName: players[playerIndex].name,
      names: players.map((p) => p.name).toList(),
      scores: engine.livesLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = engine.currentPlayerIndex;

    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DossedartTopBar(
                    title: '🕹️ 1UP',
                    trailing: '${engine.activePlayerCount} ALIVE',
                    onExit: _confirmExit,
                  ),
                  DossedartOneUpActiveCard(
                    playerName: players[cur].name,
                    accentColor: dossedartAccent(cur),
                    lives: engine.livesLeft[cur],
                    maxLives: widget.config.lives,
                    target: engine.target,
                    turnTotal: engine.turnPoints,
                    currentDartIndex: engine.dartsInTurn,
                    cardMode: _cardMode,
                    lastLife: engine.livesLeft[cur] == 1,
                    variantChip: _variantChip,
                    isRoundFree:
                        widget.config.variant == OneUpVariant.beatTheBest &&
                            engine.isFreeThrow &&
                            engine.roundNumber > 0,
                    opponents: [
                      for (int i = 0; i < players.length; i++)
                        if (i != cur && !engine.isSkipped(i))
                          OneUpOpponentEntry(
                            name: players[i].name,
                            accent: dossedartAccent(i),
                            lives: engine.livesLeft[i],
                            maxLives: widget.config.lives,
                            eliminated: engine.isEliminated(i),
                          ),
                    ],
                  ),
                  // The whole field below the card is a MISS zone; the board
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
                                  if (engine.gameOver || _overlay != null) return;
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
                      onPlayerOverview: _openDossedartPlayerSheet,
                      onExit: _confirmExit,
                    ),
                  ),
                ],
              ),
              if (_overlay != null) _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MOMENTS overlays ─────────────────────────────────────────

  Widget _buildOverlay() {
    switch (_overlay!) {
      case _OuOverlay.lifeLost:
        return _momentOverlay(
          tint: DossedartTokens.red,
          onTap: () => setState(() => _overlay = null),
          children: [
            const Text('💔', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 14),
            const Text(
              '−1 LIFE',
              style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 34,
                  color: DossedartTokens.red,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Text(
              '$_momentName FAILED TO BEAT $_momentTarget',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 24,
                  color: Colors.white,
                  letterSpacing: 2),
            ),
          ],
        );
      case _OuOverlay.eliminated:
        return _momentOverlay(
          tint: DossedartTokens.red,
          onTap: () => setState(() => _overlay = null),
          children: [
            const Text('💀', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              'ELIMINATED',
              style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 36,
                  color: DossedartTokens.red,
                  letterSpacing: 3),
            ),
            const SizedBox(height: 14),
            Text(
              '$_momentName · OUT OF LIVES',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 26,
                  color: Colors.white,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            Text(
              '${_ordinal(_eliminationPlacement)} PLACE',
              style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 13,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2),
            ),
          ],
        );
      case _OuOverlay.winner:
        return _momentOverlay(
          tint: DossedartTokens.yellow,
          onTap: () {
            setState(() => _overlay = null);
            _onGameEnd();
          },
          children: [
            const Text(
              '★ ★ ★',
              style: TextStyle(
                  fontSize: 34, letterSpacing: 6, color: DossedartTokens.yellow),
            ),
            const SizedBox(height: 14),
            const Text(
              '1UP!',
              style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 52,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 18),
            Text(
              '$_momentName WINS',
              style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            const Text(
              'LAST PLAYER STANDING',
              style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 22,
                  color: DossedartTokens.cyan,
                  letterSpacing: 2),
            ),
          ],
        );
    }
  }

  /// Full-frame moment overlay: a radial tint over the whole cockpit Stack,
  /// tap-anywhere to dismiss via [onTap]. Static (no pulse) — v1 per the
  /// brief; a future pulse would need to respect
  /// `MediaQuery.disableAnimations`, same as Wildcard's `_DangerVignette`.
  Widget _momentOverlay({
    required Color tint,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                tint.withValues(alpha: 0.13),
                DossedartTokens.bg.withValues(alpha: 0.86),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
