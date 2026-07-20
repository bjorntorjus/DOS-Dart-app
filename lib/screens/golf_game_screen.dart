import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/golf_engine.dart';
import '../models/player.dart';
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
  // parity). Task 9 wires the add/remove player-sheet flow to flip this true
  // (and populate the joined/left id sets below); for now it stays false so
  // _updateStats always takes the full recordGame/Elo path.
  // ignore: prefer_final_fields
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

  @visibleForTesting
  void onDartHitForTest(int multiplier) => _onDartHit(multiplier);

  @visibleForTesting
  void onGameEndForTest() => _onGameEnd();

  /// Minimal roster-removal hook — the full add/remove player-sheet flow
  /// (mid-game stats gating, join/leave tracking) lands in Task 9. For now
  /// this just drives the engine's own removePlayer/game-over handling so
  /// later tasks' tests have something real to call.
  @visibleForTesting
  void removePlayerForTest(int i) {
    setState(() {
      engine.removePlayer(i);
      if (engine.gameOver) _onGameEnd();
    });
  }

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
    if (engine.gameOver) return;
    final seat = engine.currentPlayerIndex;
    final target = engine.targetNumber;
    // Golf strokes only land on the scorecard when the hole ends (a hit, or
    // the 3rd miss) — so the total BEFORE this dart doubles as both
    // scoreBefore and scoreAtStartOfTurn for the log/history entry.
    final scoreBefore = engine.total(seat);
    final dartNo = engine.missesThisHole;
    final result = engine.applyDart(multiplier);
    throwHistory.add(DartThrow(
      playerIndex: seat,
      segment: multiplier == 0 ? 0 : target,
      multiplier: multiplier,
      points: multiplier == 0 ? 0 : target * multiplier,
      scoreBefore: scoreBefore,
      turnNumber: dartNo,
      scoreAtStartOfTurn: scoreBefore,
      turnId: _turnIdCounter,
      roundNumber: engine.holeNumber,
    ));
    _announcer.announceThrow(
        multiplier == 0 ? 'miss' : '${target * multiplier}');
    setState(() {});
    if (result.holeEnded) {
      _turnIdCounter++;
      _handleHoleEnd(seat, result);
    }
  }

  void _onMiss() {
    if (engine.gameOver) return;
    SoundService.instance.play('miss/miss');
    _onDartHit(0);
  }

  void _handleHoleEnd(int seat, GolfDartResult result) {
    // Task 8 fills in the hole-end moment overlay/announcement here; the
    // core loop only needs to end the game or advance the turn log.
    if (result.gameOver) {
      _onGameEnd();
      return;
    }
    _logTurn();
  }

  void _onUndo() {
    if (engine.gameOver) return;
    if (!engine.canUndo) return;
    setState(() {
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
    _showPostGame(placements);
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

  int? _lastHoleStrokes; // set in _handleHoleEnd, cleared on next dart/undo (Task 8 wires the 1s display window alongside overlays)

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

  String get _holeLabel => engine.inSuddenDeath
      ? 'SUDDEN DEATH · ${engine.targetNumber == 25 ? 'BULL' : engine.targetNumber}'
      : 'HOLE ${engine.holeNumber} · PAR 3';

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

  /// Player-sheet roster entry point. The shared [showDossedartCockpitMenu]
  /// requires a callback here, but the full add/remove wiring (mid-game
  /// stats gating, join/leave tracking, [showDossedartPlayerSheet] rows)
  /// lands in Task 9 — kept as a named no-op until then.
  void _openDossedartPlayerSheet() {}

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
                    title: '⛳ GOLF',
                    trailing: engine.inSuddenDeath
                        ? 'SUDDEN DEATH'
                        : 'HOLE ${engine.holeNumber}/${widget.config.holes}',
                    onExit: _confirmExit,
                  ),
                  DossedartGolfActiveCard(
                    playerName: players[cur].name,
                    avatarPath: players[cur].avatarPath,
                    accentColor: dossedartAccent(cur),
                    holeLabel: _holeLabel,
                    dartsThrown: engine.missesThisHole +
                        (_lastHoleStrokes != null ? 1 : 0),
                    total: engine.total(cur),
                    vsPar: engine.vsPar(cur),
                    phase: _phase,
                    statusLine: _statusLine,
                    holeStrokes: _lastHoleStrokes,
                    opponents: [
                      for (int i = 0; i < players.length; i++)
                        if (i != cur && !engine.isSkipped(i))
                          GolfOpponentEntry(
                            name: players[i].name,
                            total: engine.total(i),
                            vsPar: engine.vsPar(i),
                            doneThisHole: engine.inSuddenDeath
                                ? (!engine.playoffParticipants.contains(i) ||
                                    engine.playoffStrokes[i] != null)
                                : engine.scorecards[i][engine.currentHole] !=
                                    null,
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
                          enabled: !engine.gameOver,
                        ),
                      ),
                    ),
                  ),
                  // Playoff holes have no per-player card row — the strip is
                  // regulation-only.
                  if (!engine.inSuddenDeath)
                    GolfScorecardStrip(
                      strokes: engine.scorecards[cur],
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
            ],
          ),
        ),
      ),
    );
  }
}
