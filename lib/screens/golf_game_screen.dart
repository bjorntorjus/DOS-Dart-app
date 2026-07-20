import 'dart:async';

import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/golf_engine.dart';
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
import '../widgets/dossedart/golf/dossedart_golf_active_card.dart';
import '../widgets/dossedart/golf/golf_input_cells.dart';
import '../widgets/dossedart/golf/golf_scorecard.dart';
import 'post_game_screen.dart';

/// The DOSSEDART Golf cockpit: each hole is one dartboard number (1..holes),
/// hole ends on the first hit, misses stack strokes. Lowest total after
/// every hole wins; a tie for 1st goes to sudden death (see [GolfEngine]).
/// Assembles the [GolfEngine] (Tasks 1-3), [DossedartGolfActiveCard] /
/// [GolfInputCells] (Task 4) and [GolfScorecardStrip] (Task 5) with the
/// shared DOSSEDART chrome (top bar / action bar) into a playable screen.
///
/// Task 6 builds the core loop; Task 7 fills in `_onGameEnd`/stats and
/// Task 8 layers the hole-end moments/overlays into `_handleHoleEnd`.
class GolfGameScreen extends StatefulWidget {
  const GolfGameScreen({super.key, required this.players, required this.config});

  final List<Player> players;
  final GolfConfig config;

  @override
  State<GolfGameScreen> createState() => _GolfGameScreenState();
}

class _GolfGameScreenState extends State<GolfGameScreen> {
  late final GolfEngine engine;
  late final List<Player> players;
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;
  final DateTime _gameStart = DateTime.now();

  // Roster-change gating for the deferred-stats protocol (1UP/Shanghai
  // parity). Set unconditionally and FIRST by every roster-change path
  // (_addSavedPlayerMidGame / _removePlayerMidGame, including the
  // removePlayerForTest seam) so a skipped seat can never be misread as the
  // winner by EloService/AchievementService/StatsRecorder (placement 0 vs.
  // "best" ambiguity) — see _updateStats' short-circuit below.
  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  /// Guards [_onGameEnd] against double-fire — it's reachable both from
  /// `_handleHoleEnd`'s gameOver branch and from `removePlayerForTest`
  /// (and, from Task 9, a mid-game removal that ends the game). Reset to
  /// false on the post-game 'undo' path since the game reopens and can
  /// legitimately be finished again.
  bool _gameEndFired = false;

  @visibleForTesting
  GolfEngine get engineForTest => engine;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => engine.skippedIndices;

  /// Proves the mid-game stats gate got flipped (Task 9 review — a skipped
  /// seat's placement 0 must never reach the full recordGame/Elo path via
  /// EloService/AchievementService/StatsRecorder, since those read
  /// placement 0 as "best"). Same convention as Wildcard/Gotcha's
  /// `midGamePlayerChangesForTest`.
  @visibleForTesting
  bool get midGamePlayerChangesForTest => _midGamePlayerChanges;

  @visibleForTesting
  void onDartHitForTest(int multiplier) => _onDartHit(multiplier);

  @visibleForTesting
  void onGameEndForTest() => _onGameEnd();

  @visibleForTesting
  void onUndoForTest() => _onUndo();

  // ─── Moments (Task 8): hole-result display window + sudden-death overlay ──
  // Both timers are token-guarded (1UP QA pattern, task 14): the token is
  // bumped every time the timer is (re)started, so a stale callback firing
  // after a NEWER result/overlay replaced it — or after undo already
  // cleared the state — is a no-op instead of clobbering unrelated state.
  Timer? _resultTimer;
  int _resultToken = 0;
  Timer? _overlayTimer;
  int _overlayToken = 0;
  bool _overlaySuddenDeath = false;

  /// Test seam for the player-sheet's remove flow — drives the real removal
  /// path (sets the mid-game-changes flag), same convention as 1UP's
  /// `removePlayerForTest`.
  @visibleForTesting
  void removePlayerForTest(int i) => _removePlayerMidGame(i);

  @override
  void initState() {
    super.initState();
    players = List.of(widget.players);
    engine = GolfEngine(playerCount: players.length, holes: widget.config.holes);
    _announcer.init();
    _meme.init();
    AppSettings.getSoundEffectsEnabled()
        .then((v) => SoundService.instance.setEnabled(v));
    _log.logGameStart(
      gameMode: 'Golf',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {'holes': widget.config.holes},
      build: kAppVersion,
    );
    _logTurn();
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _logTurn() {
    _log.logTurnStart(
      roundNumber: engine.holeNumber,
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      score: engine.total(engine.currentPlayerIndex),
    );
    _log.logStandings(
      roundNumber: engine.holeNumber,
      names: players.map((p) => p.name).toList(),
      scores: [for (var i = 0; i < players.length; i++) engine.total(i)],
    );
    _log.log('H${engine.holeNumber} STATE target=${engine.targetNumber} '
        'sd=${engine.inSuddenDeath} misses=${engine.missesThisHole}');
  }

  void _onDartHit(int multiplier) {
    if (engine.gameOver || _overlaySuddenDeath) return;
    final seat = engine.currentPlayerIndex;
    final target = engine.targetNumber;
    // Golf strokes only land on the scorecard when the hole ends (a hit, or
    // the 3rd miss) — so the total BEFORE this dart doubles as both
    // scoreBefore and scoreAtStartOfTurn for the log/history entry.
    final scoreBefore = engine.total(seat);
    final dartNo = engine.missesThisHole;
    // Captured BEFORE applyDart: when the finishing seat is last in
    // rotation, _advanceToNextActive() (inside applyDart) may already have
    // incremented currentHole / advanced the playoff target, so reading the
    // label afterwards would show the NEXT hole/target next to this hole's
    // just-finished result. _liveHoleLabel (not _holeLabel) so a still-open
    // window from a previous hole can't poison this capture.
    final holeLabel = _liveHoleLabel;
    // Same reasoning as holeLabel above — engine.holeNumber must be read
    // BEFORE applyDart, or the hole-closing dart for the last seat in
    // rotation gets tagged with the hole applyDart just advanced to (and the
    // final regulation dart with holes+1, colliding with the playoff
    // bucket). See one_up_game_screen.dart's roundNo capture for the fasit.
    final roundNo = engine.holeNumber;
    final result = engine.applyDart(multiplier);

    final label = multiplier == 0
        ? 'miss'
        : (multiplier == 3 ? 'T$target' : multiplier == 2 ? 'D$target' : 'S$target');
    // Strokes only land on the scorecard when the hole ends, so this dart's
    // contribution to the running total is 0 until then, then the whole
    // hole's stroke count at once — mirrors scoreBefore/scoreAfter's meaning
    // in the sibling cockpits (running score before/after this dart).
    final strokesThisDart = result.holeEnded ? result.holeStrokes! : 0;
    _log.logThrow(
      roundNumber: roundNo,
      playerIndex: seat,
      label: label,
      points: strokesThisDart,
      scoreBefore: scoreBefore,
      scoreAfter: scoreBefore + strokesThisDart,
      dartNumber: dartNo,
    );

    throwHistory.add(DartThrow(
      playerIndex: seat,
      segment: multiplier == 0 ? 0 : target,
      multiplier: multiplier,
      // Placeholder dart-arithmetic for the shared DartThrow model — Golf
      // scores strokes, not points, and never reads this field back; it's
      // only here to satisfy the model's shape.
      points: multiplier == 0 ? 0 : target * multiplier,
      scoreBefore: scoreBefore,
      turnNumber: dartNo,
      scoreAtStartOfTurn: scoreBefore,
      turnId: _turnIdCounter,
      roundNumber: roundNo,
    ));
    _announcer.announceThrow(
        multiplier == 0 ? 'miss' : '${target * multiplier}');
    setState(() {});
    if (result.holeEnded) {
      _turnIdCounter++;
      // dartNo was captured BEFORE applyDart, i.e. the misses already
      // stacked on this hole for `seat` — so dartNo + 1 is this dart,
      // giving the total darts thrown this hole for both a hit (misses +
      // the made dart) and a wash (2 misses + the 3rd miss = 3).
      _handleHoleEnd(seat, dartNo + 1, result, holeLabel);
    }
  }

  void _onMiss() {
    if (engine.gameOver || _overlaySuddenDeath) return;
    SoundService.instance.play('miss/miss');
    _onDartHit(0);
  }

  /// Routes a completed hole to its moment: the golf-term announcement
  /// (always) plus a 1s scorecard-strip result window, then either ends the
  /// game, opens the sudden-death overlay, or announces the next playoff
  /// target — `announceNextPlayer` always fires last, queueing after the
  /// term via the TTS queue so both staples are heard (spec §6).
  void _handleHoleEnd(
      int seat, int darts, GolfDartResult result, String holeLabel) {
    final strokes = result.holeStrokes!;
    _showHoleResult(seat, strokes, darts, holeLabel);

    final phrase = switch (strokes) {
      1 => 'Ace! Hole in one!',
      6 => 'Triple bogey.',
      _ => '${golfTerm(strokes).toLowerCase()}!',
    };
    _announcer.announceGolf(phrase, soundFolders: [
      'golf/${golfTerm(strokes).toLowerCase().replaceAll(' ', '_')}'
    ]);

    if (result.gameOver) {
      _onGameEnd();
      return;
    }
    if (result.suddenDeathStarted) {
      _announcer.announceGolf('Sudden death!',
          soundFolders: const ['golf/sudden_death']);
      _showSuddenDeathOverlay();
    } else if (result.playoffContinued) {
      _announcer.announceGolf('Still tied! Next hole: '
          '${engine.targetNumber == 25 ? 'bull' : engine.targetNumber}.');
    }
    _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
    _logTurn();
  }

  /// Shows the just-finished hole's stroke result on the active card for 1s,
  /// then clears it — cancelling/replacing any window left over from a
  /// still-pending previous hole first. [_resultToken] guards the delayed
  /// clear against firing after a NEWER hole result (or undo) replaced it.
  ///
  /// [seat] and [darts] are captured alongside [strokes] so the card can
  /// keep showing the FINISHING player's identity/pips during the window —
  /// `engine.currentPlayerIndex`/`engine.missesThisHole` have already moved
  /// on to the next thrower by the time this runs. [label] is likewise the
  /// hole/sudden-death label as it read BEFORE this dart, since a rotation
  /// wrap may have already advanced `engine.currentHole`/the playoff target.
  void _showHoleResult(int seat, int strokes, int darts, String label) {
    _resultTimer?.cancel();
    final token = ++_resultToken;
    setState(() {
      _lastHoleStrokes = strokes;
      _lastHoleSeat = seat;
      _lastHoleDarts = darts;
      _lastHoleLabel = label;
    });
    _resultTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || token != _resultToken) return;
      setState(() {
        _lastHoleStrokes = null;
        _lastHoleSeat = null;
        _lastHoleDarts = null;
        _lastHoleLabel = null;
      });
    });
  }

  /// Shows the sudden-death overlay and (re)starts its 1s auto-dismiss timer
  /// — same token-guard construction as [_showHoleResult] (and 1UP's
  /// `_showOverlay`) so a stale timer can't dismiss a newer overlay.
  void _showSuddenDeathOverlay() {
    _overlayTimer?.cancel();
    final token = ++_overlayToken;
    setState(() => _overlaySuddenDeath = true);
    _overlayTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || token != _overlayToken) return;
      setState(() => _overlaySuddenDeath = false);
    });
  }

  /// Dismisses the sudden-death overlay early (tap) and invalidates its
  /// pending auto-dismiss timer so it can't fire later against whatever
  /// replaces `_overlaySuddenDeath`.
  void _dismissSuddenDeathOverlay() {
    _overlayTimer?.cancel();
    _overlayToken++;
    setState(() => _overlaySuddenDeath = false);
  }

  void _onUndo() {
    if (engine.gameOver) return;
    if (!engine.canUndo) return;
    _resultTimer?.cancel();
    _overlayTimer?.cancel();
    _resultToken++;
    _overlayToken++;
    setState(() {
      _lastHoleStrokes = null;
      _lastHoleSeat = null;
      _lastHoleDarts = null;
      _lastHoleLabel = null;
      _overlaySuddenDeath = false;
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
      scoreRestored: engine.total(engine.currentPlayerIndex),
      roundNumber: engine.holeNumber,
    );
    _announcer.announceGameEvent('Back');
  }

  /// Seats with a non-zero placement (i.e. not skipped), winner-first —
  /// shared by the game-end log and [_showPostGame]'s result ordering.
  List<int> _orderByPlacement(List<int> placements) {
    return [
      for (var i = 0; i < players.length; i++) if (placements[i] != 0) i,
    ]..sort((a, b) => placements[a].compareTo(placements[b]));
  }

  Future<void> _onGameEnd() async {
    if (_gameEndFired) return;
    _gameEndFired = true;
    final placements = engine.placements();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: _orderByPlacement(placements),
      gameFullyOver: true,
    );
    final winner = engine.winnerIndex;
    await _fireWinnerCelebration(winner != null ? players[winner].name : '');
    if (!mounted) return;
    // Preview rating deltas so they're visible on the result screen even
    // though recording is deferred until the user leaves (1UP/audit F17
    // parity — the plan omitted this step here).
    await _prepareRatingPreview(placements);
    if (!mounted) return;
    _showPostGame(placements);
  }

  /// Computes the rating deltas this finish WILL produce so the result screen
  /// can show them, without persisting anything. Actual recording stays
  /// deferred until the user leaves the result screen.
  Future<void> _prepareRatingPreview(List<int> placements) async {
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
      placements: placements,
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

  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }

  Future<void> _updateStats(List<int> placements) async {
    if (_midGamePlayerChanges) {
      // Roster changed — record only join/leave counters and write NO game
      // entry, matching the other cockpits (audit 2026-07-06, F10).
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

    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      if (engine.isSkipped(pi)) continue;
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'totalStrokes': engine.total(pi),
        'holesPlayed': engine.holesCompleted(pi),
        'aces': engine.aces[pi],
        'bogeys': engine.bogeys[pi],
        'firstDartHits': engine.firstDartHits[pi],
        if (engine.bestHole[pi] != null) 'min:bestHole': engine.bestHole[pi]!,
        if (engine.holesCompleted(pi) == widget.config.holes)
          'min:bestRound${widget.config.holes}': engine.total(pi),
        'totalDarts': engine.dartsThrown[pi],
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
      mode: GameMode.golf,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
    );
    final earnedFeats =
        buildEarnedFeats(eventsByIndex: const {}, unlocksByIndex: unlocks);

    StatsRecorder.recordGame(
      gameMode: 'golf',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: '${widget.config.holes} holes',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _showPostGame(List<int> placements) {
    final order = _orderByPlacement(placements);

    final results = <PlayerResult>[
      for (final i in order)
        PlayerResult(
          name: players[i].name,
          avatarPath: players[i].avatarPath,
          placement: placements[i],
          stats: {
            'strokes': engine.total(i),
            'vsPar': engine.vsPar(i),
            'aces': engine.aces[i],
            'bogeys': engine.bogeys[i],
            'firstDartHits': engine.firstDartHits[i],
            'holesPlayed': engine.holesCompleted(i),
            if (engine.bestHole[i] != null) 'bestHole': engine.bestHole[i],
          },
          ratingBefore: players[i].savedPlayerId != null
              ? _ratingsBefore[players[i].savedPlayerId!]
              : null,
          ratingAfter: players[i].savedPlayerId != null
              ? _ratingsAfter[players[i].savedPlayerId!]
              : null,
        ),
    ];

    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PostGameScreen(
          result: GameResult(
            gameMode: 'golf',
            results: results,
            canUndo: engine.canUndo,
            throwHistory: List<DartThrow>.from(throwHistory),
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
      // 'home' or back-button: persist stats now (deferred from _onGameEnd
      // so Undo doesn't strand the user with stats they didn't confirm),
      // then leave the game-screen entirely.
      await _updateStats(placements);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  // ---- card-state derivation ----
  GolfCardPhase get _phase {
    final done = _lastHoleStrokes;
    if (done != null) return done <= 3 ? GolfCardPhase.holeDoneGood : GolfCardPhase.holeDoneBad;
    return engine.missesThisHole == 0 ? GolfCardPhase.teeOff : GolfCardPhase.midHole;
  }

  // Result-window quartet: all four are set together in _showHoleResult and
  // cleared together (by its 1s timer or by undo) — never partially, so the
  // card's build-time derivation can gate on _lastHoleStrokes alone and
  // trust _lastHoleSeat/_lastHoleDarts/_lastHoleLabel are present too.
  int? _lastHoleStrokes; // finished hole's stroke count, shown on the card
  int? _lastHoleSeat; // seat that finished the hole (identity for the card)
  int? _lastHoleDarts; // darts thrown that hole, for the dart-pip display
  String? _lastHoleLabel; // hole/sudden-death label as of BEFORE this dart

  String get _statusLine {
    final done = _lastHoleStrokes;
    if (done != null) {
      return '${golfTerm(done)} — $done STROKE${done == 1 ? '' : 'S'}';
    }
    if (engine.missesThisHole == 0) {
      return engine.inSuddenDeath
          ? 'PLAYOFF — THROW AT ${engine.targetNumber == 25 ? 'BULL' : 'THE ${engine.targetNumber}'}'
          : 'TEE OFF — THROW AT THE ${engine.targetNumber}';
    }
    final left = 3 - engine.missesThisHole;
    return 'LYING ${engine.missesThisHole} — $left DART${left == 1 ? '' : 'S'} LEFT';
  }

  // Live derivation straight off the engine — used both as the label's
  // normal (no-window) value and as what _onDartHit captures BEFORE
  // applyDart, so that capture is never accidentally poisoned by a still-
  // open window left over from a previous hole.
  String get _liveHoleLabel => engine.inSuddenDeath
      ? 'SUDDEN DEATH · ${engine.targetNumber == 25 ? 'BULL' : engine.targetNumber}'
      : 'HOLE ${engine.holeNumber} · PAR 3';

  // While the hole-result window is active this must return the label as it
  // read for the FINISHED hole, not the live derivation — on a rotation
  // wrap `_advanceToNextActive` may have already bumped `engine.currentHole`
  // / the playoff target before this getter runs again during the window.
  String get _holeLabel {
    final lastLabel = _lastHoleLabel;
    if (_lastHoleStrokes != null && lastLabel != null) return lastLabel;
    return _liveHoleLabel;
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
              _log.logExit(gameMode: 'Golf');
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

  /// Player-sheet roster entry point, wired into the cockpit menu's
  /// player-overview hook (1UP parity). Score column shows the running
  /// total plus vs-par so a removal decision can weigh who's actually
  /// leading.
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
        primary: '${engine.total(i)} (${vsParLabel(engine.vsPar(i))})',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: engine.gameOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
          'Joins at hole ${engine.holeNumber} — earlier holes count as par.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
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
      scores: [for (var i = 0; i < players.length; i++) engine.total(i)],
    );
  }

  void _removePlayerMidGame(int playerIndex) {
    final removedId = players[playerIndex].savedPlayerId;
    setState(() {
      _midGamePlayerChanges = true;
      if (removedId != null) _leftMidGameIds.add(removedId);
      engine.removePlayer(playerIndex);
      if (engine.gameOver) _onGameEnd();
    });
    _log.logRoster(
      action: 'REMOVE',
      playerIndex: playerIndex,
      playerName: players[playerIndex].name,
      names: players.map((p) => p.name).toList(),
      scores: [for (var i = 0; i < players.length; i++) engine.total(i)],
    );
  }

  void _openScoreSheet() {
    showGolfScoreSheet(
      context,
      names: players.map((p) => p.name).toList(),
      scorecards: engine.scorecards,
      totals: [for (var i = 0; i < players.length; i++) engine.total(i)],
      vsPars: [for (var i = 0; i < players.length; i++) engine.vsPar(i)],
      skippedSeats: engine.skippedIndices,
    );
  }

  @override
  Widget build(BuildContext context) {
    // During the 1s hole-result window the active card must keep showing
    // the player who just FINISHED the hole (name/avatar/accent/total/vs-par
    // + the opponents-strip exclusion), not engine.currentPlayerIndex, which
    // applyDart already advanced to the next thrower before this build runs.
    final displaySeat = _lastHoleStrokes != null && _lastHoleSeat != null
        ? _lastHoleSeat!
        : engine.currentPlayerIndex;

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
                    title: '⛳ GOLF',
                    trailing: engine.inSuddenDeath
                        ? 'PLAYOFF'
                        : 'HOLE ${engine.holeNumber}/${widget.config.holes}',
                    onExit: _confirmExit,
                  ),
                  DossedartGolfActiveCard(
                    playerName: players[displaySeat].name,
                    avatarPath: players[displaySeat].avatarPath,
                    accentColor: dossedartAccent(displaySeat),
                    holeLabel: _holeLabel,
                    dartsThrown: _lastHoleStrokes != null &&
                            _lastHoleDarts != null
                        ? _lastHoleDarts!
                        : engine.missesThisHole,
                    total: engine.total(displaySeat),
                    vsPar: engine.vsPar(displaySeat),
                    phase: _phase,
                    statusLine: _statusLine,
                    holeStrokes: _lastHoleStrokes,
                    opponents: [
                      for (int i = 0; i < players.length; i++)
                        if (i != displaySeat && !engine.isSkipped(i))
                          GolfOpponentEntry(
                            name: players[i].name,
                            total: engine.total(i),
                            vsPar: engine.vsPar(i),
                            doneThisHole: engine.inSuddenDeath
                                ? (!engine.playoffParticipants.contains(i) ||
                                    engine.playoffStrokes[i] != null)
                                // Regulation ending outright (no sudden
                                // death) leaves currentHole == holes, one
                                // past the scorecard's valid indices — the
                                // game being over already means every hole
                                // is done, so short-circuit before indexing.
                                : (engine.gameOver ||
                                    engine.scorecards[i][engine.currentHole] !=
                                        null),
                            accent: engine.inSuddenDeath &&
                                    !engine.playoffParticipants.contains(i)
                                ? dossedartAccent(i).withValues(alpha: 0.35)
                                : dossedartAccent(i),
                          ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GolfInputCells(
                          targetNumber: engine.targetNumber,
                          onHit: _onDartHit,
                          enabled: !_overlaySuddenDeath && !engine.gameOver,
                        ),
                      ),
                    ),
                  ),
                  // Playoff holes have no per-player card row — the strip is
                  // regulation-only.
                  if (!engine.inSuddenDeath)
                    GolfScorecardStrip(
                      strokes: engine.scorecards[displaySeat],
                      currentHole: engine.currentHole,
                      onExpand: _openScoreSheet,
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
              if (_overlaySuddenDeath) _buildSuddenDeathOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MOMENTS overlay: sudden death (Task 8) ────────────────────
  // No ACE overlay, no winner overlay — per RULES-DELTA and the 1UP QA
  // lesson (task 14), the post-game screen is the sole winner surface and
  // aces are celebrated via sound/TTS only.

  Widget _buildSuddenDeathOverlay() {
    final targetLabel =
        engine.targetNumber == 25 ? 'BULL' : '${engine.targetNumber}';
    final names =
        engine.playoffParticipants.map((i) => players[i].name).join(' vs ');
    return _momentOverlay(
      tint: DossedartTokens.red,
      onTap: _dismissSuddenDeathOverlay,
      children: [
        const Text('⛳', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        const Text(
          'SUDDEN DEATH',
          style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 30,
              color: DossedartTokens.red,
              letterSpacing: 2,
              shadows: [
                Shadow(color: DossedartTokens.red, blurRadius: 20),
              ]),
        ),
        const SizedBox(height: 14),
        Text(
          'PLAYOFF ON $targetLabel',
          style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 2),
        ),
        const SizedBox(height: 10),
        Text(
          names,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 20,
              color: Colors.white70,
              letterSpacing: 1),
        ),
      ],
    );
  }

  /// Full-frame moment overlay: a radial tint over the whole cockpit Stack,
  /// tap-anywhere to dismiss via [onTap]. Static (no pulse) — a future
  /// pulse would need to respect `MediaQuery.disableAnimations`, same as
  /// 1UP's/Wildcard's equivalents.
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
