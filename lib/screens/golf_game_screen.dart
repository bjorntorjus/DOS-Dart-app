import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/golf_engine.dart';
import '../models/player.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/game_logger.dart';
import '../services/meme_service.dart';
import '../services/sound_service.dart';
import '../theme/dossedart_tokens.dart';
import '../utils/dossedart_player_accents.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/golf/dossedart_golf_active_card.dart';
import '../widgets/dossedart/golf/golf_input_cells.dart';
import '../widgets/dossedart/golf/golf_scorecard.dart';

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
  // ignore: unused_field
  final DateTime _gameStart = DateTime.now(); // consumed by Task 7's duration calc

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

  void _onGameEnd() {
    // Task 7: ranking, stats persistence, post-game screen.
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
