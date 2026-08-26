import 'dart:async';

import 'package:flutter/material.dart';
import '../app_version.dart';
import '../utils/join_seed.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/one_up_engine.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../models/setup_prefill.dart';
import '../services/achievement_service.dart';
import '../services/app_settings.dart';
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
import '../utils/dossedart_player_accents.dart';
import '../utils/earned_feats_builder.dart';
import '../utils/one_up_hit_suggestion.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';
import 'dossedart/dossedart_one_up_setup_screen.dart';
import 'post_game_screen.dart';

/// Overlay moments the 1UP cockpit shows, one at a time, full-frame on top
/// of the Stack — a life lost or an elimination (with placement). The
/// winner overlay was dropped (tablet-QA task 14): the post-game screen is
/// the sole winner surface. Every kind dismisses on tap, and auto-dismisses
/// after 1s via [_OneUpGameScreenState._overlayTimer].
enum _OuOverlay { lifeLost, eliminated }

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

  // Join/leave id sets populated by _addSavedPlayerMidGame/
  // _removePlayerMidGame, fed to StatsRecorder.recordMidGameChanges
  // alongside the full recordGame path (spec 2026-08-26: a roster change no
  // longer diverts away from stats/Elo/history — removed seats are excluded
  // via engine.skippedIndices instead).
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  /// Guards [_onGameEnd] against double-fire — it's called both from
  /// `_handleTurnEnd`'s playerWon branch and from `_removePlayerMidGame`
  /// when a removal ends the game, so both paths route through this same
  /// guard. Reset to false on the post-game 'undo' path since the game
  /// reopens and can legitimately be finished again.
  bool _gameEndFired = false;

  @visibleForTesting
  OneUpEngine get engineForTest => engine;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => engine.skippedIndices;

  @visibleForTesting
  void onGameEndForTest() => _onGameEnd();

  @visibleForTesting
  void onDartHitForTest(int s, int m) => _onDartHit(s, m);

  @visibleForTesting
  void onUndoForTest() => _onUndo();

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  // ─── Moment overlays (Task 8; auto-dismiss added task 14) ─────
  _OuOverlay? _overlay;
  String _momentName = '';
  int _momentTarget = 0;

  /// Auto-dismisses the current moment overlay after 1s (task 14 QA fix).
  /// [_overlayToken] is bumped each time an overlay is (re)shown so a stale
  /// timer firing after a later overlay replaced it — or after the overlay
  /// was already cleared by a tap/undo — is a no-op instead of clobbering
  /// unrelated state.
  Timer? _overlayTimer;
  int _overlayToken = 0;

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

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
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
    final outOfRoundNames = widget.config.variant == OneUpVariant.survivor &&
            engine.outOfRoundIndices.isNotEmpty
        ? engine.outOfRoundIndices.map((i) => players[i].name).join(',')
        : null;
    _log.log('R${engine.roundNumber} STATE '
        'target=${engine.target ?? '-'} '
        'setBy=${engine.targetSetBy >= 0 ? players[engine.targetSetBy].name : '-'} '
        'variant=${widget.config.variant.name}'
        '${outOfRoundNames != null ? ' out=[$outOfRoundNames]' : ''}');
  }

  void _onDartHit(int segment, int multiplier) {
    if (engine.gameOver || _overlay != null) return;
    final playerIdx = engine.currentPlayerIndex;
    final dartNo = engine.dartsInTurn;
    final turnBefore = engine.turnPoints;
    _lastThrowerSeat = playerIdx;
    _failedTarget = engine.target ?? 0;
    final roundNo = engine.roundNumber;

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
      roundNumber: roundNo,
    ));

    ShotClock.instance.registerDart();

    _log.logThrow(
      roundNumber: roundNo,
      playerIndex: playerIdx,
      label: label,
      points: result.points,
      scoreBefore: turnBefore,
      scoreAfter: turnBefore + result.points,
      dartNumber: dartNo,
    );

    // Full meme path (audit 2026-08-10, F3): 1UP used to reach tryMissSound
    // only, so 6-7 and the end-of-turn stings never fired here. Its
    // DartThrow.points are real turn points, so onTurnEnd's round-score
    // branch is safe — unlike Golf's placeholder points.
    final memeTriggered = _meme.onThrow(throwHistory.last);

    // Every dart gets a plain throw-result callout (Gotcha parity, task 14
    // QA fix — the mode was near-silent). Unlike Gotcha there's no per-dart
    // competing announcement (bust/kill) to gate this on; the turn-level
    // moments below (life lost/eliminated/etc.) are separate TTS lines that
    // queue after this one. Skipped when a meme sting already covers it.
    if (!memeTriggered) {
      _announcer.announceThrow(
          segment == 0 ? 'miss' : '${segment * multiplier}');
    }

    // A completed turn opens a fresh turnId group for the next thrower.
    if (result.turnEnded && !engine.gameOver) _turnIdCounter++;
    if (result.turnEnded) _meme.onTurnEnd();

    setState(() {});
    if (result.turnEnded) _handleTurnEnd(result);
  }

  void _onMiss() {
    if (engine.gameOver || _overlay != null) return;
    _meme.tryMissSound();
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
      // The post-game screen is the sole winner surface (task 14 QA fix) —
      // no overlay, no dedicated announceOneUp; _onGameEnd -> announceWinner
      // covers the TTS. _gameEndFired still guards double-fire inside it.
      _onGameEnd();
      return;
    }
    // Tracks whether this turn already produced a "moment" announcement
    // (life lost / elimination / big target / round win) — those name the
    // next beat themselves or hand off to an overlay, so the plain
    // next-player announcement below is skipped to avoid stepping on them.
    var momentAnnounced = false;
    if (result.eliminated) {
      _announcer.announceOneUp('$name is eliminated!',
          soundFolders: const ['one_up/eliminated']);
      _showOverlay(_OuOverlay.eliminated, momentName: name);
      momentAnnounced = true;
    } else if (result.lostLife) {
      _announcer.announceOneUp('$name loses a life!',
          soundFolders: engine.livesLeft[seat] == 1
              ? const ['one_up/last_life']
              : const ['one_up/life_lost']);
      _showOverlay(_OuOverlay.lifeLost,
          momentName: name, momentTarget: _failedTarget);
      momentAnnounced = true;
    } else if (engine.targetSetBy == seat && (engine.target ?? 0) >= 100) {
      _announcer.announceOneUp('${engine.target}! Beat that!',
          soundFolders: const ['one_up/target_set']);
      momentAnnounced = true;
    }
    // SURVIVOR: the round winner is announced via TTS only — the overlay
    // above (if any) already covered the moment for the player who just
    // failed; this is purely informational and never null when playerWon
    // (the engine doesn't set roundWonBy on a game-ending fail).
    if (result.roundWonBy != null) {
      _announcer.announceOneUp(
          '${players[result.roundWonBy!].name} wins the round!');
      momentAnnounced = true;
    }
    if (!momentAnnounced) {
      _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
    }
    _logTurn();
  }

  /// Shows a moment overlay and (re)starts its 1s auto-dismiss timer —
  /// cancelling any timer left over from a previous overlay first. The
  /// captured [token] lets the delayed callback recognise a stale firing
  /// (overlay already replaced or cleared) and no-op instead of clearing
  /// unrelated state.
  void _showOverlay(_OuOverlay overlay, {String? momentName, int? momentTarget}) {
    _overlayTimer?.cancel();
    final token = ++_overlayToken;
    setState(() {
      _overlay = overlay;
      if (momentName != null) _momentName = momentName;
      if (momentTarget != null) _momentTarget = momentTarget;
    });
    _overlayTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || token != _overlayToken) return;
      setState(() => _overlay = null);
    });
  }

  /// Dismisses the current moment overlay early (tap) and cancels its
  /// pending auto-dismiss timer so it can't fire later against whatever
  /// replaces `_overlay`.
  void _dismissOverlay() {
    _overlayTimer?.cancel();
    setState(() => _overlay = null);
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
    _overlayTimer?.cancel();
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
    _announcer.announceGameEvent('Back');
  }

  Future<void> _onGameEnd() async {
    if (_gameEndFired) return;
    _gameEndFired = true;
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
    final excludedSeats = Set<int>.unmodifiable(engine.skippedIndices);
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (int pi = 0; pi < players.length; pi++) {
      // A seat that left mid-game is excluded from this game's
      // rating (spec 2026-08-26), so it must not get a snapshot
      // either — otherwise buildEntry hands its history row a
      // ratingBefore == ratingAfter and it renders a +0 delta
      // where Family A leaves the column blank.
      if (excludedSeats.contains(pi)) continue;
      final p = players[pi];
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    EloService.updateRatings(
      gameMode: 'oneUp',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _placementsFromRanking(ranking),
      savedPlayers: savedPlayers,
      excludedSeats: excludedSeats,
    );

    _ratingsAfter = {};
    for (int pi = 0; pi < players.length; pi++) {
      // A seat that left mid-game is excluded from this game's
      // rating (spec 2026-08-26), so it must not get a snapshot
      // either — otherwise buildEntry hands its history row a
      // ratingBefore == ratingAfter and it renders a +0 delta
      // where Family A leaves the column blank.
      if (excludedSeats.contains(pi)) continue;
      final p = players[pi];
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }
    // savedPlayers are discarded unpersisted — this was display-only.
  }

  Future<void> _updateStats(List<int> ranking) async {
    // Join/leave counters first: they load+save players themselves, and the
    // block below holds its own copy of the list.
    await StatsRecorder.recordMidGameChanges(
      joinedIds: _joinedMidGameIds,
      leftIds: _leftMidGameIds,
    );
    // Removed players are excluded from this game's stats, Elo, H2H and
    // badges; joiners count fully (spec 2026-08-26). Seats are skipped, not
    // dropped — throws and feats index by seat.
    final excludedSeats = Set<int>.unmodifiable(engine.skippedIndices);
    final savedPlayers = await PlayerStorage.loadPlayers();

    _ratingsBefore = {};
    for (int pi = 0; pi < players.length; pi++) {
      // A seat that left mid-game is excluded from this game's
      // rating (spec 2026-08-26), so it must not get a snapshot
      // either — otherwise buildEntry hands its history row a
      // ratingBefore == ratingAfter and it renders a +0 delta
      // where Family A leaves the column blank.
      if (excludedSeats.contains(pi)) continue;
      final p = players[pi];
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
        // Always included (0 in BEAT THE LAST games) — simpler than gating
        // on variant, and harmless since the counter has no meaning there.
        'roundsWon': engine.roundsWon[pi],
      };
    }

    EloService.updateRatings(
      gameMode: 'oneUp',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      excludedSeats: excludedSeats,
    );

    _ratingsAfter = {};
    for (int pi = 0; pi < players.length; pi++) {
      // A seat that left mid-game is excluded from this game's
      // rating (spec 2026-08-26), so it must not get a snapshot
      // either — otherwise buildEntry hands its history row a
      // ratingBefore == ratingAfter and it renders a +0 delta
      // where Family A leaves the column blank.
      if (excludedSeats.contains(pi)) continue;
      final p = players[pi];
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
      excludedSeats: excludedSeats,
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
          '${widget.config.variant == OneUpVariant.survivor ? 'Survivor' : 'Beat the last'}'
          '${widget.config.randomOrder ? ' · Shuffle' : ''}',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
      excludedSeats: excludedSeats,
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
          'roundsWon': engine.roundsWon[i],
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
            gameMode: 'oneUp',
            results: results,
            durationSeconds:
                DateTime.now().difference(_gameStart).inSeconds,
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
          // The game reopens and can be finished again — let _onGameEnd
          // fire once more when it does.
          _gameEndFired = false;
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
          builder: (_) => DossedartOneUpSetupScreen(
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

  /// Winner first, then reverse elimination order, then (for aborted games)
  /// surviving non-winners by lives desc; excludes skipped seats.
  List<int> _rankPlayers() {
    final ranked = <int>[];
    final w = engine.winnerIndex;
    if (w != null && !engine.isSkipped(w)) ranked.add(w);
    final alive = engine.aliveIndices.where((i) => i != w).toList()
      ..sort(withSeatTiebreak(
          (a, b) => engine.livesLeft[b].compareTo(engine.livesLeft[a])));
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
      addInfoText: "Joins next round with the last-placed player's lives",
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not a full set of lives
    // (tester feedback 2026-08-10). Fewest lives is the worst position, and
    // there is deliberately no floor.
    final worst =
        worstSeat(engine.livesLeft, engine.aliveIndices, higherIsBetter: true);
    final seedLives =
        worst == null ? widget.config.lives : engine.livesLeft[worst];
    setState(() {
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: 0,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      engine.addPlayer(initialLives: seedLives);
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
    final removedId = players[playerIndex].savedPlayerId;
    setState(() {
      if (removedId != null) _leftMidGameIds.add(removedId);
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

  @visibleForTesting
  void removePlayerForTest(int i) => _removePlayerMidGame(i);

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
                    avatarPath: players[cur].avatarPath,
                    accentColor: dossedartAccent(cur),
                    lives: engine.livesLeft[cur],
                    maxLives: widget.config.lives,
                    target: engine.isFreeThrow ? null : engine.target,
                    turnTotal: engine.turnPoints,
                    currentDartIndex: engine.dartsInTurn,
                    cardMode: _cardMode,
                    survivor:
                        widget.config.variant == OneUpVariant.survivor,
                    roundNumber: engine.roundNumber,
                    targetBy: engine.isFreeThrow || engine.targetSetBy < 0
                        ? null
                        : players[engine.targetSetBy].name,
                    hitSuggestion: _cardMode == OneUpCardMode.normal &&
                            engine.target != null
                        ? oneUpHitSuggestion(engine.target! - engine.turnPoints)
                        : null,
                    standings: [
                      for (int i = 0; i < players.length; i++)
                        if (!engine.isSkipped(i)) // removed players stay out (X01 parity)
                          OneUpStanding(
                            name: players[i].name,
                            accent: dossedartAccent(i),
                            lives: engine.livesLeft[i],
                            maxLives: widget.config.lives,
                            eliminated: engine.isEliminated(i),
                            outOfRound: engine.isOutOfRound(i),
                            isActive: i == cur,
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
                      activePlayerCount: Iterable<int>.generate(players.length)
                          .where((i) => !engine.isSkipped(i))
                          .length,
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
          onTap: _dismissOverlay,
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
          onTap: _dismissOverlay,
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
