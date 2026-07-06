import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/dart_board.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/meme_service.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/game_logger.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../models/game_result.dart';
import 'post_game_screen.dart';
import '../widgets/player_avatar.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/achievement_event.dart';
import '../models/game_mode.dart';
import '../utils/earned_feats_builder.dart';
import '../services/achievement_service.dart';
import '../models/saved_player.dart';
import '../services/battery_sampler.dart';
import '../theme/dossedart_tokens.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_player_avatar.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';

enum KillerPhase { assignment, playing }

/// Tints owned/claimed wedges on top of the shared TWILIGHT dartboard, using
/// the board's own geometry constants. Ownership is shown purely by colour:
/// your number cyan, enemies red, eliminated/claimed a dark veil.
class _KillerBoardOverlayPainter extends CustomPainter {
  final Map<int, Color> tints; // segment number → fill colour
  _KillerBoardOverlayPainter({required this.tints});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    const slice = pi * 2 / 20;
    tints.forEach((number, color) {
      final idx = kSegmentOrder.indexOf(number);
      if (idx < 0) return;
      final start = -slice / 2 + idx * slice - pi / 2;
      final rIn = r * kBullR;
      final rOut = r * kDoubleR;
      final path = Path()
        ..moveTo(c.dx + cos(start) * rIn, c.dy + sin(start) * rIn)
        ..lineTo(c.dx + cos(start) * rOut, c.dy + sin(start) * rOut)
        ..arcTo(Rect.fromCircle(center: c, radius: rOut), start, slice, false)
        ..lineTo(c.dx + cos(start + slice) * rIn, c.dy + sin(start + slice) * rIn)
        ..arcTo(Rect.fromCircle(center: c, radius: rIn), start + slice, -slice,
            false)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    });
  }

  @override
  bool shouldRepaint(_KillerBoardOverlayPainter oldDelegate) => true;
}

class KillerGameScreen extends StatefulWidget {
  final List<Player> players;
  final KillerConfig config;
  final bool useDossedartDesign;

  const KillerGameScreen({
    super.key,
    required this.players,
    required this.config,
    this.useDossedartDesign = false,
  });

  @override
  State<KillerGameScreen> createState() => _KillerGameScreenState();
}

class _KillerGameScreenState extends State<KillerGameScreen> {
  late List<Player> players;
  late List<int> assignedNumbers; // number per player (1-20)
  late List<int> lives;
  late List<bool> isKiller;
  late List<bool> isEliminated;
  late List<int> shields;
  KillerPhase phase = KillerPhase.assignment;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  int? winnerIndex;
  String? lastThrowLabel;

  int _roundNumber = 1;
  List<DartThrow> throwHistory = [];
  final List<_KillerUndoData> _undoStack = [];
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;
  bool _missSoundPlayed = false;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final DateTime _gameStart = DateTime.now();
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};

  /// Kills the current player has racked up in the in-progress turn, and the
  /// best single-turn kill count per player index (for KILLING SPREE).
  int _killsThisTurn = 0;
  final Map<int, int> _maxKillsInTurn = {};

  @visibleForTesting
  int get killsThisTurnForTest => _killsThisTurn;

  @visibleForTesting
  Map<int, int> get maxKillsInTurnForTest => _maxKillsInTurn;

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
  void removePlayerForTest(int playerIndex) {
    setState(() {
      _midGamePlayerChanges = true;
      _removedPlayerIndices.add(playerIndex);
      isEliminated[playerIndex] = true;
    });
  }

  void _commitKillsThisTurn() {
    final cur = _maxKillsInTurn[currentPlayerIndex] ?? 0;
    if (_killsThisTurn > cur) _maxKillsInTurn[currentPlayerIndex] = _killsThisTurn;
    _killsThisTurn = 0;
  }

  // Assignment phase tracking
  int assignmentPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    assignedNumbers = List.filled(players.length, 0, growable: true);
    lives = List.filled(players.length, widget.config.lives, growable: true);
    isKiller = List.filled(players.length, false, growable: true);
    isEliminated = List.filled(players.length, false, growable: true);
    shields = List.filled(players.length, 0, growable: true);

    if (!widget.config.throwToPick) {
      _assignRandomNumbers();
      phase = KillerPhase.playing;
    }
    _announcer.init();
    _meme.init();
    _log.init().then((_) {
      _log.logGameStart(
        gameMode: 'Killer',
        playerNames: players.map((p) => p.name).toList(),
        playerScores: List.filled(players.length, widget.config.lives),
        config: {
          'lives': widget.config.lives,
          'throwToPick': widget.config.throwToPick,
          'shields': widget.config.shields,
          'multiplyHits': widget.config.multiplyHits,
        },
      );
      BatterySampler.instance.start('Killer');
      if (!widget.config.throwToPick) {
        _log.log('Assignment: random numbers ${List.generate(players.length, (i) => '${players[i].name}→${assignedNumbers[i]}').join(', ')}');
        _log.log('Phase: playing');
      } else {
        _log.log('Phase: assignment (throw to pick)');
      }
    });
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    _ttsEnabled = TtsService.instance.enabled;
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  void _assignRandomNumbers() {
    final rng = Random();
    final pool = List.generate(20, (i) => i + 1)..shuffle(rng);
    for (int i = 0; i < players.length; i++) {
      assignedNumbers[i] = pool[i];
    }
  }

  Future<void> _onDartHit(int segment, int multiplier) async {
    if (winnerIndex != null) return;

    if (phase == KillerPhase.assignment) {
      _handleAssignment(segment, multiplier);
      return;
    }

    await _handlePlaying(segment, multiplier);
  }

  void _handleAssignment(int segment, int multiplier) {
    if (segment == 0 || segment == 25) {
      setState(() {
        lastThrowLabel =
            segment == 0 ? 'Miss - throw again' : 'Bull - throw again';
      });
      _log.log('ASSIGNMENT P$assignmentPlayerIndex(${players[assignmentPlayerIndex].name}) threw ${segment == 0 ? "Miss" : "Bull"} - throw again');
      return;
    }

    // Check if number already taken
    if (assignedNumbers.contains(segment)) {
      setState(() {
        lastThrowLabel = '$segment is already taken - throw again';
      });
      _log.log('ASSIGNMENT P$assignmentPlayerIndex(${players[assignmentPlayerIndex].name}) threw $segment - already taken');
      return;
    }

    setState(() {
      assignedNumbers[assignmentPlayerIndex] = segment;
      lastThrowLabel =
          '${players[assignmentPlayerIndex].name} got $segment';
      _log.log('ASSIGNMENT P$assignmentPlayerIndex(${players[assignmentPlayerIndex].name}) assigned number $segment');
      _announcer.announceGameEvent(
          '${players[assignmentPlayerIndex].name} got $segment');
      assignmentPlayerIndex++;

      if (assignmentPlayerIndex >= players.length) {
        phase = KillerPhase.playing;
        currentPlayerIndex = 0;
        lastThrowLabel = 'Game starts!';
        _log.log('Assignment complete: ${List.generate(players.length, (i) => '${players[i].name}→${assignedNumbers[i]}').join(', ')}');
        _log.log('Phase: playing');
        _announcer.announceGameEvent('Game starts');
      }
    });
  }

  Future<void> _handlePlaying(int segment, int multiplier) async {
    final points = segment * multiplier;
    final livesBefore = List<int>.from(lives);

    // Save undo data
    _undoStack.add(_KillerUndoData(
      playerIndex: currentPlayerIndex,
      dartsInTurn: dartsInTurn,
      livesBefore: List.from(lives),
      isKillerBefore: List.from(isKiller),
      isEliminatedBefore: List.from(isEliminated),
      shieldsBefore: List.from(shields),
      roundNumber: _roundNumber,
      killsThisTurnBefore: _killsThisTurn,
      maxKillsInTurnBefore: Map.of(_maxKillsInTurn),
    ));

    final dartThrow = DartThrow(
      playerIndex: currentPlayerIndex,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: lives[currentPlayerIndex],
      turnNumber: dartsInTurn,
      scoreAtStartOfTurn: lives[currentPlayerIndex],
    );

    setState(() {
      throwHistory.add(dartThrow);

      final myNumber = assignedNumbers[currentPlayerIndex];

      String? extraLog;

      if (segment == 0) {
        lastThrowLabel = 'Miss';
        if (!_missSoundPlayed) {
          _announcer.announceThrow('Miss');
        }
      } else if (segment == 25 && widget.config.shields) {
        // Bull hit with shields enabled
        _handleBullHit(multiplier, dartThrow);
        final gained = multiplier == 2 ? 3 : 1;
        extraLog = '+$gained shield${gained > 1 ? 's' : ''}';
      } else if (segment == myNumber) {
        // Hit own number — special handling
        final wasKiller = isKiller[currentPlayerIndex];
        _handleOwnNumberHit(currentPlayerIndex, multiplier, dartThrow);
        if (!wasKiller) {
          extraLog = 'became killer';
        } else {
          final damage = widget.config.multiplyHits && multiplier >= 2
              ? multiplier
              : 1;
          extraLog = 'self hit for $damage damage, lives ${livesBefore[currentPlayerIndex]}→${lives[currentPlayerIndex]}';
          if (isEliminated[currentPlayerIndex]) {
            extraLog = '$extraLog, self-eliminated';
          }
        }
      } else if (_isEffectiveHit(multiplier)) {
        // Effective hit on another player's number
        final damage = _damageFor(multiplier);
        _handleOtherNumberHit(currentPlayerIndex, segment, damage, dartThrow);
        if (isKiller[currentPlayerIndex]) {
          final targetPlayer = assignedNumbers.indexWhere((n) => n == segment);
          if (targetPlayer >= 0 && !_undoStack.last.isEliminatedBefore[targetPlayer]) {
            final shieldsAbsorbed = _undoStack.last.shieldsBefore[targetPlayer] - shields[targetPlayer];
            final livesLost = livesBefore[targetPlayer] - lives[targetPlayer];
            final parts = <String>[];
            parts.add('hit P$targetPlayer(${players[targetPlayer].name}) for $damage damage');
            if (shieldsAbsorbed > 0) parts.add('shield absorbed $shieldsAbsorbed');
            if (livesLost > 0) parts.add('lives ${livesBefore[targetPlayer]}→${lives[targetPlayer]}');
            if (isEliminated[targetPlayer]) parts.add('eliminated ${players[targetPlayer].name}');
            extraLog = parts.join(', ');
          } else {
            extraLog = 'not killer yet, no effect';
          }
        } else {
          extraLog = 'not killer yet, no effect';
        }
      } else {
        lastThrowLabel = dartThrow.label;
        _announcer.announceThrow(dartThrow.spokenLabel);
      }

      _log.logThrow(
        roundNumber: _roundNumber,
        playerIndex: currentPlayerIndex,
        label: dartThrow.label,
        points: points,
        scoreBefore: livesBefore[currentPlayerIndex],
        scoreAfter: lives[currentPlayerIndex],
        dartNumber: dartsInTurn,
        extra: extraLog,
      );

      // Log elimination as a finish event + tally kills for the active player.
      for (int i = 0; i < players.length; i++) {
        if (isEliminated[i] && !_undoStack.last.isEliminatedBefore[i]) {
          if (i != currentPlayerIndex) _killsThisTurn++;
          _log.logFinish(
            roundNumber: _roundNumber,
            playerIndex: i,
            playerName: players[i].name,
            details: 'eliminated with ${livesBefore[i]}→0 lives',
          );
        }
      }

      _meme.onThrow(dartThrow);
      dartsInTurn++;
      if (winnerIndex != null) {
        _commitKillsThisTurn();
        _meme.onTurnEnd();
      } else if (dartsInTurn >= 3) {
        _commitKillsThisTurn();
        _meme.onTurnEnd();
        _advancePlayer();
      }
    });

    if (winnerIndex != null) {
      _log.logFinish(
        roundNumber: _roundNumber,
        playerIndex: winnerIndex!,
        playerName: players[winnerIndex!].name,
        details: 'winner, last player standing with ${lives[winnerIndex!]} lives',
      );
      _announcer.announceWinner(players[winnerIndex!].name);
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _prepareRatingPreview().then((_) => _showPostGame());
    }
  }

  /// Whether this multiplier triggers game effects
  bool _isEffectiveHit(int multiplier) {
    return multiplier >= 1; // all hits (single, double, triple) deal damage
  }

  /// How much damage this hit deals
  int _damageFor(int multiplier) {
    if (widget.config.multiplyHits) return multiplier;
    return 1;
  }

  void _handleBullHit(int multiplier, DartThrow dartThrow) {
    final pi = currentPlayerIndex;
    final gained = multiplier == 2 ? 3 : 1;
    shields[pi] += gained;
    lastThrowLabel = '${dartThrow.label} - +$gained shield${gained > 1 ? 's' : ''}!';
    _announcer.announceGameEvent('$gained shield${gained > 1 ? 's' : ''}');
  }

  void _handleOwnNumberHit(
      int pi, int multiplier, DartThrow dartThrow) {
    if (!isKiller[pi]) {
      // Any hit on own number makes you a Killer — no damage on this turn
      isKiller[pi] = true;
      lastThrowLabel = '${dartThrow.label} - KILLER!';
      _announcer.announceGameEvent('Killer');
    } else {
      // Already a Killer — hitting own number costs lives
      final damage = widget.config.multiplyHits && multiplier >= 2
          ? multiplier
          : 1;
      final dmgLabel = damage > 1 ? '$damage lives' : 'a life';
      lastThrowLabel = '${dartThrow.label} - Self hit! Lost $dmgLabel!';
      _applyDamage(pi, damage);
      _checkForWinner();
    }
  }

  void _handleOtherNumberHit(
      int pi, int segment, int damage, DartThrow dartThrow) {
    if (isKiller[pi]) {
      // Find whose number it is
      final targetPlayer = assignedNumbers.indexWhere((n) => n == segment);
      if (targetPlayer >= 0 && !isEliminated[targetPlayer]) {
        _applyDamage(targetPlayer, damage);
        if (isEliminated[targetPlayer]) {
          lastThrowLabel =
              '${dartThrow.label} - ${players[targetPlayer].name} eliminated!';
          _announcer.announceGameEvent(
              '${players[targetPlayer].name} eliminated');
        } else {
          final dmgLabel = damage > 1 ? '$damage lives' : 'a life';
          lastThrowLabel =
              '${dartThrow.label} - ${players[targetPlayer].name} lost $dmgLabel!';
          _announcer.announceGameEvent(
              '${players[targetPlayer].name} lost $dmgLabel');
        }
        _checkForWinner();
      } else {
        lastThrowLabel = dartThrow.label;
        _announcer.announceThrow(dartThrow.spokenLabel);
      }
    } else {
      // Not a Killer yet
      lastThrowLabel = '${dartThrow.label} - Must be Killer first!';
      _announcer.announceThrow(dartThrow.spokenLabel);
    }
  }

  /// Apply damage to a player, consuming shields first
  void _applyDamage(int playerIndex, int damage) {
    var remaining = damage;

    // Consume shields first
    if (shields[playerIndex] > 0) {
      final absorbed = shields[playerIndex].clamp(0, remaining);
      shields[playerIndex] -= absorbed;
      remaining -= absorbed;
    }

    // Apply remaining to lives
    if (remaining > 0) {
      lives[playerIndex] = (lives[playerIndex] - remaining).clamp(0, 999);
    }

    if (lives[playerIndex] <= 0) {
      isEliminated[playerIndex] = true;
      if (_memeEnabled) {
        SoundService.instance.playRandom([
          'killer/death',
          if (_offensiveEnabled) 'killer/offensive/death',
        ]);
      }
    } else if (remaining > 0) {
      if (_memeEnabled) {
        SoundService.instance.playRandom([
          'killer/hit',
          if (_offensiveEnabled) 'killer/offensive/hit',
        ]);
      }
    }
  }

  void _checkForWinner() {
    final alive = <int>[];
    for (int i = 0; i < players.length; i++) {
      if (!isEliminated[i]) alive.add(i);
    }
    if (alive.length == 1) {
      winnerIndex = alive.first;
    }
  }

  void _advancePlayer() {
    final fromIndex = currentPlayerIndex;
    dartsInTurn = 0;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    } while (isEliminated[currentPlayerIndex] && winnerIndex == null);
    // Increment round when we wrap back to or past the first alive player
    if (currentPlayerIndex <= fromIndex) {
      _roundNumber++;
    }
    if (winnerIndex == null) {
      _log.logAdvance(
        roundNumber: _roundNumber,
        fromIndex: fromIndex,
        toIndex: currentPlayerIndex,
        toName: players[currentPlayerIndex].name,
        toScore: lives[currentPlayerIndex],
        reason: 'turn complete',
      );
      _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    }
  }

  void _onMiss() {
    _missSoundPlayed = false;
    if (_memeEnabled) {
      _missSoundPlayed = SoundService.instance.playRandomMaybe([
        'miss',
        if (_offensiveEnabled) 'miss/offensive',
      ], chance: _meme.frequencyChance);
      if (_missSoundPlayed && _meme.frequency < 10) {
        _meme.markSoundPlayed();
      }
    }
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
    if (phase == KillerPhase.assignment) {
      if (assignmentPlayerIndex > 0) {
        final undonePlayer = players[assignmentPlayerIndex - 1].name;
        final undoneNumber = assignedNumbers[assignmentPlayerIndex - 1];
        setState(() {
          assignmentPlayerIndex--;
          assignedNumbers[assignmentPlayerIndex] = 0;
          lastThrowLabel = null;
        });
        _log.log('UNDO assignment: $undonePlayer loses number $undoneNumber');
      }
      return;
    }

    if (throwHistory.isEmpty || _undoStack.isEmpty) return;
    _announcer.announceGameEvent('Back');

    final lastThrow = throwHistory.last;
    final data = _undoStack.last;

    setState(() {
      throwHistory.removeLast();
      _undoStack.removeLast();
      currentPlayerIndex = data.playerIndex;
      dartsInTurn = data.dartsInTurn;
      lives = data.livesBefore;
      isKiller = data.isKillerBefore;
      isEliminated = data.isEliminatedBefore;
      shields = data.shieldsBefore;
      _killsThisTurn = data.killsThisTurnBefore;
      _maxKillsInTurn
        ..clear()
        ..addAll(data.maxKillsInTurnBefore);
      _roundNumber = data.roundNumber;
      winnerIndex = null;
      lastThrowLabel = null;
    });

    _log.logUndo(
      playerIndex: data.playerIndex,
      playerName: players[data.playerIndex].name,
      throwLabel: lastThrow.label,
      scoreRestored: data.livesBefore[data.playerIndex],
      roundNumber: data.roundNumber,
    );
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
      final sp =
          savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _buildPlacements(),
      savedPlayers: savedPlayers,
    );

    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp =
          savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }
    // savedPlayers are discarded unpersisted — this was display-only.
  }

  /// Rank: winner 1st, others by remaining lives (more = better).
  List<int> _buildPlacements() {
    final placements = List.filled(players.length, 0);
    placements[winnerIndex!] = 1;
    final nonWinners = List.generate(players.length, (i) => i)
      ..removeWhere((i) => i == winnerIndex);
    nonWinners.sort((a, b) => lives[b].compareTo(lives[a]));
    int rank = 2;
    for (int i = 0; i < nonWinners.length; i++) {
      if (i > 0 && lives[nonWinners[i]] < lives[nonWinners[i - 1]]) {
        rank = i + 2;
      }
      placements[nonWinners[i]] = rank;
    }
    return placements;
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

    // Capture ratings before update
    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp =
          savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];
      sp.gamesPlayed++;
      if (pi == winnerIndex) sp.gamesWon++;
    }

    // Rank: winner 1st, others by remaining lives (more = better)
    final placements = _buildPlacements();
    // Compute per-player killer stats from undo stack and game state
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;

      int kills = 0, shieldsGained = 0, attacksDealt = 0, attacksReceived = 0, selfHits = 0;

      // Walk through undo stack to reconstruct events
      for (int u = 0; u < _undoStack.length; u++) {
        final undo = _undoStack[u];
        // Get the state after this action by looking at next undo (or final state)
        final livesAfter = u + 1 < _undoStack.length
            ? _undoStack[u + 1].livesBefore
            : lives;
        final shieldsAfter = u + 1 < _undoStack.length
            ? _undoStack[u + 1].shieldsBefore
            : shields;
        final eliminatedAfter = u + 1 < _undoStack.length
            ? _undoStack[u + 1].isEliminatedBefore
            : isEliminated;

        final thrower = undo.playerIndex;

        for (int target = 0; target < players.length; target++) {
          final liveLost = undo.livesBefore[target] - livesAfter[target];
          final shieldGained = shieldsAfter[target] - undo.shieldsBefore[target];
          final wasEliminated = !undo.isEliminatedBefore[target] && eliminatedAfter[target];

          if (target == pi) {
            // Stats for this player as target
            if (shieldGained > 0 && thrower == pi) {
              shieldsGained += shieldGained;
            }
            if (liveLost > 0 && thrower != pi) {
              attacksReceived += liveLost;
            }
            if (liveLost > 0 && thrower == pi) {
              selfHits += liveLost;
            }
          }

          if (thrower == pi && target != pi) {
            // Stats for this player as attacker
            if (liveLost > 0) {
              attacksDealt += liveLost;
            }
            if (wasEliminated) {
              kills++;
            }
          }
        }
      }

      modeCounters[playerId] = {
        'kills': kills,
        'shieldsGained': shieldsGained,
        'attacksDealt': attacksDealt,
        'attacksReceived': attacksReceived,
        'selfHits': selfHits,
        'livesLeft': lives[pi],
      };
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
    );

    // Capture ratings after update (before recording history)
    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp =
          savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }

    final achEvents = <int, List<AchievementEvent>>{};
    for (int i = 0; i < players.length; i++) {
      if ((_maxKillsInTurn[i] ?? 0) >= 3) {
        achEvents[i] = [AchievementEvent.multiKill];
      }
    }
    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.killer,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      eventsByIndex: achEvents,
    );

    StatsRecorder.recordGame(
      gameMode: 'killer',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: 'Killer · ${widget.config.lives} lives',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex:
          buildEarnedFeats(eventsByIndex: achEvents, unlocksByIndex: unlocks),
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _showPostGame() async {
    // Build finished order: winner first, then eliminated order (reversed),
    // then any remaining
    final finishedOrder = <int>[];
    if (winnerIndex != null) finishedOrder.add(winnerIndex!);
    for (int i = 0; i < players.length; i++) {
      if (i != winnerIndex) finishedOrder.add(i);
    }

    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: finishedOrder,
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
      _log.logPostGame(action: 'undo', details: 'user chose undo from post-game');
      _undo();
    } else {
      _log.logPostGame(action: 'exit', details: 'user exited to home');
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
    // and never as the winner. (winnerIndex is already removed-safe: removed
    // players are flagged eliminated, so they never end up the last one alive.)
    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      if (_removedPlayerIndices.contains(i)) continue;
      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: i == winnerIndex ? 1 : (isEliminated[i] ? 3 : 2),
        stats: {'lives': lives[i]},
        ratingBefore: players[i].savedPlayerId != null
            ? _ratingsBefore[players[i].savedPlayerId!]
            : null,
        ratingAfter: players[i].savedPlayerId != null
            ? _ratingsAfter[players[i].savedPlayerId!]
            : null,
      ));
    }
    return GameResult(gameMode: 'killer', results: results);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
    return _buildClassicScaffold(context);
  }

  // ---------------------------------------------------------------------------
  // DOSSEDART arcade cockpit — reuses the TWILIGHT dartboard for both phases.
  // Ownership is shown purely by wedge colour (you=cyan, enemies=red) plus a
  // thin status-key strip; the assignment phase dims claimed numbers. Every tap
  // feeds the same _onDartHit / _onMiss as the classic screen.
  // ---------------------------------------------------------------------------

  Widget _buildDossedartCockpit(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: phase == KillerPhase.assignment
              ? _killerAssignmentView(context)
              : _killerPlayingView(context),
        ),
      ),
    );
  }

  Widget _killerBoard(Map<int, Color> tints) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Spec (x01-cockpit-final): no frame, glow only —
            // 0 0 70px magenta @ 0x3a ≈ alpha 0.23.
            boxShadow: [
              BoxShadow(
                color: DossedartTokens.magenta.withValues(alpha: 0.23),
                blurRadius: 70,
              ),
            ],
          ),
          child: Stack(
            children: [
              DossedartX01Dartboard(
                onTap: (zone) {
                  final (seg, mult) = zone.toSegmentMultiplier();
                  if (seg == 0) {
                    _onMiss();
                  } else {
                    _onDartHit(seg, mult);
                  }
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _KillerBoardOverlayPainter(tints: tints),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DossedartActionBar _killerActionBar(BuildContext context) {
    return DossedartActionBar(
      onUndo: _undo,
      onMiss: _onMiss,
      onMenu: () => showDossedartCockpitMenu(
        context,
        meme: _meme,
        onTtsChanged: (v) => setState(() => _ttsEnabled = v),
        onPlayerOverview: _openDossedartPlayerSheet,
        onExit: _confirmExit,
      ),
    );
  }

  Widget _killerPlayingView(BuildContext context) {
    final cfg = widget.config;
    final title = 'KILLER · ${cfg.lives} LIVES${cfg.shields ? ' · SHIELDS' : ''}';
    final tints = <int, Color>{};
    for (int i = 0; i < players.length; i++) {
      final n = assignedNumbers[i];
      if (n < 1) continue;
      if (isEliminated[i]) {
        tints[n] = Colors.black.withValues(alpha: 0.55);
      } else if (i == currentPlayerIndex) {
        tints[n] = DossedartTokens.cyan.withValues(alpha: 0.38);
      } else {
        tints[n] = DossedartTokens.red.withValues(alpha: 0.32);
      }
    }
    return Column(
      children: [
        DossedartTopBar(
          title: title,
          onExit: _confirmExit,
          trailing: 'RND $_roundNumber',
        ),
        _killerStatusKey(),
        Expanded(child: _killerBoard(tints)),
        _killerActionBar(context),
      ],
    );
  }

  Widget _killerStatusKey() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (int i = 0; i < players.length; i++) _killerKeyRow(i)],
      ),
    );
  }

  Widget _killerKeyRow(int i) {
    final active = i == currentPlayerIndex;
    final elim = isEliminated[i];
    final c = elim
        ? DossedartTokens.phosphor.withValues(alpha: 0.45)
        : active
            ? DossedartTokens.cyan
            : DossedartTokens.red;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(
            color: c.withValues(alpha: active ? 1 : 0.4), width: active ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: c, width: 2)),
            child: Text(
              assignedNumbers[i] > 0 ? '${assignedNumbers[i]}' : '—',
              style: TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: c),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              players[i].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: c,
                decoration: elim ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isKiller[i] && !elim)
            _killerTag('ARMED', DossedartTokens.orange),
          if (shields[i] > 0 && !elim)
            _killerTag('SH ${shields[i]}', DossedartTokens.green),
          const SizedBox(width: 8),
          Text(
            elim ? 'OUT' : '♥ ${lives[i]}',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 16,
              color: elim ? c : DossedartTokens.red,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _killerTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1)),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'PressStart2P', fontSize: 8, color: color),
      ),
    );
  }

  Widget _killerAssignmentView(BuildContext context) {
    final tints = <int, Color>{};
    for (final n in assignedNumbers) {
      if (n > 0) tints[n] = Colors.black.withValues(alpha: 0.5);
    }
    return Column(
      children: [
        DossedartTopBar(
          title: 'KILLER · TILDELING',
          onExit: _confirmExit,
          trailing: 'SPILLER ${assignmentPlayerIndex + 1}/${players.length}',
        ),
        _killerAssignmentPrompt(),
        Expanded(child: _killerBoard(tints)),
        _killerRoster(),
        _killerActionBar(context),
      ],
    );
  }

  Widget _killerAssignmentPrompt() {
    final claimer = players[assignmentPlayerIndex];
    const c = DossedartTokens.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.12), Colors.transparent],
        ),
        border: const Border(bottom: BorderSide(color: c, width: 3)),
      ),
      child: Row(
        children: [
          DossedartPlayerAvatar(
              size: 48, borderColor: c, avatarPath: claimer.avatarPath),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '▶ ${claimer.name.toUpperCase()} — KAST FOR Å VELGE DITT TALL',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: c,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _killerRoster() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (int i = 0; i < players.length; i++) _killerRosterChip(i)
        ],
      ),
    );
  }

  Widget _killerRosterChip(int i) {
    final claimed = assignedNumbers[i] > 0;
    final isCurrent = i == assignmentPlayerIndex;
    final c = claimed
        ? DossedartTokens.green
        : isCurrent
            ? DossedartTokens.cyan
            : DossedartTokens.phosphor.withValues(alpha: 0.5);
    final status = claimed
        ? '${assignedNumbers[i]} ✓'
        : isCurrent
            ? 'VELGER…'
            : 'VENTER';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: c, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            players[i].name,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12, color: c),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
                fontFamily: 'VT323', fontSize: 14, color: c, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(phase == KillerPhase.assignment
            ? 'Killer - Pick Number'
            : 'Killer'),
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
                  if (phase == KillerPhase.playing && winnerIndex == null) {
                    _openPlayerManagement();
                  }
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
              if (phase == KillerPhase.playing)
                PopupMenuItem(
                  value: 'players',
                  enabled: winnerIndex == null,
                  child: const Row(
                    children: [
                      Icon(Icons.group_add),
                      SizedBox(width: 12),
                      Text('Manage players'),
                    ],
                  ),
                ),
              if (phase == KillerPhase.playing) const PopupMenuDivider(),
              PopupMenuItem(
                value: 'tts',
                child: Row(
                  children: [
                    Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
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
          // Current player info
          _buildPlayerInfoBar(),

          // Phase-specific info
          if (phase == KillerPhase.assignment) _buildAssignmentInfo(),

          // Dart board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DartBoard(
                  onHit: winnerIndex == null ? _onDartHit : (a, b) {}),
            ),
          ),

          // Last throw + Miss (Back always reserves space to avoid layout shift)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: lastThrowLabel != null
                      ? Text('Last: $lastThrowLabel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: lastThrowLabel!.contains('KILLER')
                                ? Theme.of(context).colorScheme.tertiary
                                : lastThrowLabel!.contains('shield')
                                    ? Colors.blue
                                    : lastThrowLabel!.contains('Eliminated') ||
                                            lastThrowLabel!.contains('Lost') ||
                                            lastThrowLabel!.contains('Suicide')
                                        ? Theme.of(context).colorScheme.error
                                        : lastThrowLabel!
                                                .contains('Must be Killer')
                                            ? Theme.of(context).colorScheme.tertiary
                                            : Colors.white,
                          ))
                      : const SizedBox(),
                ),
                Visibility(
                  visible: throwHistory.isNotEmpty || assignmentPlayerIndex > 0,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (phase == KillerPhase.playing)
                  ElevatedButton(
                    onPressed: winnerIndex == null ? _onMiss : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    child: const Text('Miss', style: TextStyle(fontSize: 16)),
                  ),
              ],
            ),
          ),

          // Player list
          _buildPlayerList(),
        ],
      ),
    );
  }

  Widget _buildPlayerInfoBar() {
    final pi = phase == KillerPhase.assignment
        ? assignmentPlayerIndex
        : currentPlayerIndex;
    if (pi >= players.length) return const SizedBox();

    final player = players[pi];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
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
                        fontSize: 20, fontWeight: FontWeight.bold)),
                if (phase == KillerPhase.playing)
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
                    ],
                  )
                else
                  Text('Throw a dart to pick a number',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                // Hint for non-killers
                if (phase == KillerPhase.playing &&
                    !isKiller[pi] &&
                    !isEliminated[pi])
                  Text('Hit ${assignedNumbers[pi]} to become Killer!',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary, fontSize: 12)),
              ],
            ),
          ),
          if (phase == KillerPhase.playing && assignedNumbers[pi] > 0) ...[
            // Sword (Killer) or Shield (not yet Killer) for active thrower
            if (!isEliminated[pi])
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  isKiller[pi] ? '⚔️' : '🛡️',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Your number',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                Text('${assignedNumbers[pi]}',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Assignment Round',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(players.length, (i) {
                final assigned = assignedNumbers[i] > 0;
                final isCurrent = i == assignmentPlayerIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: isCurrent
                            ? Icon(Icons.arrow_right,
                                color: Theme.of(context).colorScheme.primary, size: 18)
                            : null,
                      ),
                      PlayerAvatar(
                        avatarPath: players[i].avatarPath,
                        name: players[i].name,
                        radius: 12,
                        backgroundColor: avatarColor(i),
                      ),
                      const SizedBox(width: 8),
                      Text(players[i].name,
                          style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      assigned
                          ? Text('${assignedNumbers[i]}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16))
                          : Text('...',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: players.length,
        itemBuilder: (context, index) {
          final player = players[index];
          final isCurrent = phase == KillerPhase.playing &&
              index == currentPlayerIndex &&
              winnerIndex == null;
          final isWinner = index == winnerIndex;
          final eliminated = isEliminated[index];
          final isRemoved = _removedPlayerIndices.contains(index);

          return Opacity(
            opacity: isRemoved ? 0.4 : 1.0,
            child: ActivePlayerHighlight(
              isActive: isCurrent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: eliminated
                    ? Theme.of(context).colorScheme.error.withAlpha(15)
                    : isWinner
                        ? Theme.of(context).colorScheme.primary.withAlpha(25)
                        : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: isCurrent
                          ? Icon(Icons.arrow_right,
                              color: Theme.of(context).colorScheme.primary, size: 20)
                          : isWinner
                              ? Icon(Icons.emoji_events,
                                  color: Theme.of(context).colorScheme.tertiary, size: 20)
                              : eliminated
                                  ? Icon(Icons.close,
                                      color: Theme.of(context).colorScheme.error, size: 20)
                                  : null,
                    ),
                    const SizedBox(width: 8),
                    PlayerAvatar(
                      avatarPath: player.avatarPath,
                      name: player.name,
                      radius: 14,
                      backgroundColor:
                          eliminated ? Colors.grey : avatarColor(index),
                    ),
                    const SizedBox(width: 8),
                    // Number badge — turns amber + filled when player is KILLER
                    if (assignedNumbers[index] > 0)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isKiller[index] && !eliminated
                              ? Theme.of(context).colorScheme.tertiary
                              : null,
                          border: Border.all(
                            color: isKiller[index] && !eliminated
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${assignedNumbers[index]}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isKiller[index] && !eliminated
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isKiller[index] && !eliminated
                                ? Colors.black
                                : null,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isCurrent ? FontWeight.bold : FontWeight.normal,
                              decoration: eliminated
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: eliminated ? Colors.grey : null,
                            ),
                          ),
                          // Reserve a single line for last-darts so the row
                          // height stays constant. KILLER status is now shown
                          // by the amber-filled number badge instead of a
                          // separate label.
                          Text(
                            _lastDartsLabel(index).isEmpty
                                ? ' '
                                : _lastDartsLabel(index),
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                    // Shields + Lives
                    if (phase == KillerPhase.playing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Shield icons
                          if (widget.config.shields)
                            ...List.generate(shields[index], (i) {
                              return Padding(
                                padding: EdgeInsets.only(
                                    right: i < shields[index] - 1 ? 3 : 0),
                                child: const Icon(
                                  Icons.shield,
                                  size: 22,
                                  color: Colors.blue,
                                ),
                              );
                            }),
                          if (widget.config.shields && shields[index] > 0)
                            const SizedBox(width: 8),
                          // Life hearts
                          ...List.generate(widget.config.lives, (li) {
                            final hasLife = li < lives[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                  right:
                                      li < widget.config.lives - 1 ? 3 : 0),
                              child: Icon(
                                hasLife
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 22,
                                color: hasLife
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.surfaceContainer,
                              ),
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
        primary: isEliminated[i] ? 'OUT' : '${lives[i]} ♥',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: winnerIndex != null,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
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
      gameOver: winnerIndex != null,
      colorFor: avatarColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player. '
          'New players get a random unused number and must qualify by hitting their double.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !isEliminated[i] && !_removedPlayerIndices.contains(i))
        .toList();

    // Avg lives, standard rounding
    final avgLives = activeIndices.isEmpty
        ? widget.config.lives
        : (activeIndices.map((i) => lives[i]).reduce((a, b) => a + b) /
                activeIndices.length)
            .round();

    // Random unused number
    final usedNumbers = assignedNumbers.toSet();
    final available = [for (int n = 1; n <= 20; n++) if (!usedNumbers.contains(n)) n];
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No free numbers — all 1–20 are in use.')),
      );
      return;
    }
    final number = available[Random().nextInt(available.length)];

    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: 0,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      assignedNumbers.add(number);
      lives.add(avgLives);
      isKiller.add(false); // must qualify
      isEliminated.add(false);
      shields.add(0);
    });
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content: const Text('Rating will not be updated for this game.'),
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
              final removed = players[playerIndex];
              setState(() {
                _midGamePlayerChanges = true;
                _removedPlayerIndices.add(playerIndex);
                if (removed.savedPlayerId != null) {
                  _leftMidGameIds.add(removed.savedPlayerId!);
                }
                // Mark as eliminated so rotation skips
                isEliminated[playerIndex] = true;
                if (playerIndex == currentPlayerIndex) {
                  dartsInTurn = 0;
                  _advancePlayer();
                }
              });
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

class _KillerUndoData {
  final int playerIndex;
  final int dartsInTurn;
  final List<int> livesBefore;
  final List<bool> isKillerBefore;
  final List<bool> isEliminatedBefore;
  final List<int> shieldsBefore;
  final int roundNumber;
  final int killsThisTurnBefore;
  final Map<int, int> maxKillsInTurnBefore;

  _KillerUndoData({
    required this.playerIndex,
    required this.dartsInTurn,
    required this.livesBefore,
    required this.isKillerBefore,
    required this.isEliminatedBefore,
    required this.shieldsBefore,
    required this.roundNumber,
    required this.killsThisTurnBefore,
    required this.maxKillsInTurnBefore,
  });
}
