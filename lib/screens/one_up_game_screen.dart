import 'package:flutter/material.dart';
import '../app_version.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/one_up_engine.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
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
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';

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
  // ignore: unused_field  // read by Task 7's _updateStats duration.
  final DateTime _gameStart = DateTime.now();

  @visibleForTesting
  OneUpEngine get engineForTest => engine;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => engine.skippedIndices;

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
    if (engine.gameOver) return;
    final playerIdx = engine.currentPlayerIndex;
    final dartNo = engine.dartsInTurn;
    final turnBefore = engine.turnPoints;

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
    SoundService.instance.play('miss/miss');
    _onDartHit(0, 0);
  }

  void _handleTurnEnd(OneUpDartResult result) {
    // Task 8 layers overlays/announcements here; core flow:
    if (result.playerWon) {
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
      scoreRestored: engine.livesLeft[engine.currentPlayerIndex],
      roundNumber: engine.roundNumber,
    );
  }

  // Empty stub — Task 7 wires the winner celebration / stats / result screen.
  void _onGameEnd() {}

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
              // Task 8 slots its turn-end / elimination / winner overlays into
              // this outer Stack without re-layout.
            ],
          ),
        ),
      ),
    );
  }
}
