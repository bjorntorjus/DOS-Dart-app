import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
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
import '../services/video_service.dart';
import '../models/game_result.dart';
import 'post_game_screen.dart';
import '../widgets/player_avatar.dart';

enum KillerPhase { assignment, playing }

class KillerGameScreen extends StatefulWidget {
  final List<Player> players;
  final KillerConfig config;

  const KillerGameScreen({
    super.key,
    required this.players,
    required this.config,
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
  bool _missSoundPlayed = false;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  // Assignment phase tracking
  int assignmentPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    assignedNumbers = List.filled(players.length, 0);
    lives = List.filled(players.length, widget.config.lives);
    isKiller = List.filled(players.length, false);
    isEliminated = List.filled(players.length, false);
    shields = List.filled(players.length, 0);

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
      if (!widget.config.throwToPick) {
        _log.log('Assignment: random numbers ${List.generate(players.length, (i) => '${players[i].name}→${assignedNumbers[i]}').join(', ')}');
        _log.log('Phase: playing');
      } else {
        _log.log('Phase: assignment (throw to pick)');
      }
    });
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
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

      // Log elimination as a finish event
      for (int i = 0; i < players.length; i++) {
        if (isEliminated[i] && !_undoStack.last.isEliminatedBefore[i]) {
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
        _meme.onTurnEnd();
      } else if (dartsInTurn >= 3) {
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
      _updateStats().then((_) => _showPostGame());
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

  Future<void> _updateStats() async {
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
      };
    }

    EloService.updateRatings(
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
    );
    StatsRecorder.recordGame(
      gameMode: 'killer',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
    );

    // Capture ratings after update
    _ratingsAfter = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp =
          savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }

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

    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => PostGameScreen(
                result: GameResult(gameMode: 'killer', results: results),
              )),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo', details: 'user chose undo from post-game');
      _undo();
    } else {
      _log.logPostGame(action: 'exit', details: 'user exited to home');
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: Text(_memeEnabled ? '🤡' : '🤐', style: const TextStyle(fontSize: 22)),
            onPressed: () {
              setState(() => _memeEnabled = !_memeEnabled);
              AppSettings.setMemeEnabled(_memeEnabled);
              _meme.setEnabled(_memeEnabled);
            },
            tooltip: 'Meme sounds',
          ),
          if (_memeEnabled) ...[
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showMemeFrequencyDialog,
              tooltip: 'Meme frequency',
            ),
            IconButton(
              icon: Icon(_offensiveEnabled ? Icons.whatshot : Icons.whatshot_outlined),
              onPressed: () {
                setState(() => _offensiveEnabled = !_offensiveEnabled);
                AppSettings.setMemeOffensive(_offensiveEnabled);
                _meme.setOffensive(_offensiveEnabled);
              },
              tooltip: 'Offensive sounds',
            ),
          ],
          if (throwHistory.isNotEmpty || assignmentPlayerIndex > 0)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo,
              tooltip: 'Undo',
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

          // Last throw + Miss
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                if (lastThrowLabel != null)
                  Expanded(
                    child: Text('Last: $lastThrowLabel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: lastThrowLabel!.contains('KILLER')
                              ? Colors.amber
                              : lastThrowLabel!.contains('shield')
                                  ? Colors.blue
                                  : lastThrowLabel!.contains('Eliminated') ||
                                          lastThrowLabel!
                                              .contains('Lost') ||
                                          lastThrowLabel!
                                              .contains('Suicide')
                                      ? const Color(0xFFE53935)
                                      : lastThrowLabel!
                                              .contains('Must be Killer')
                                          ? Colors.orange
                                          : Colors.white,
                        )),
                  )
                else
                  const Expanded(child: SizedBox()),
                if (throwHistory.isNotEmpty || assignmentPlayerIndex > 0) ...[
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _undo,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Back', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(color: Colors.grey[700]!),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (phase == KillerPhase.playing)
                  ElevatedButton(
                    onPressed: winnerIndex == null ? _onMiss : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
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
        color: playerColor(pi).withAlpha(40),
        border: Border(
          bottom: BorderSide(color: playerColor(pi).withAlpha(80)),
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
                              color: Colors.grey[400], fontSize: 13)),
                      const SizedBox(width: 8),
                      ...List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            i < dartsInTurn
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 10,
                            color: playerColor(pi),
                          ),
                        );
                      }),
                    ],
                  )
                else
                  Text('Throw a dart to pick a number',
                      style:
                          TextStyle(color: Colors.grey[400], fontSize: 13)),
                // Hint for non-killers
                if (phase == KillerPhase.playing &&
                    !isKiller[pi] &&
                    !isEliminated[pi])
                  Text('Hit ${assignedNumbers[pi]} to become Killer!',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 12)),
              ],
            ),
          ),
          if (phase == KillerPhase.playing && assignedNumbers[pi] > 0)
            Column(
              children: [
                Text('Number',
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 11)),
                Text('${assignedNumbers[pi]}',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
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
                                color: playerColor(i), size: 18)
                            : null,
                      ),
                      PlayerAvatar(
                        avatarPath: players[i].avatarPath,
                        name: players[i].name,
                        radius: 12,
                        backgroundColor: playerColor(i),
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
                              style: TextStyle(color: Colors.grey[600])),
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
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
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

          return Container(
            color: eliminated
                ? Colors.red.withAlpha(15)
                : isCurrent
                    ? playerColor(index).withAlpha(25)
                    : isWinner
                        ? Colors.green.withAlpha(25)
                        : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: isCurrent
                      ? Icon(Icons.arrow_right,
                          color: playerColor(index), size: 20)
                      : isWinner
                          ? const Icon(Icons.emoji_events,
                              color: Colors.amber, size: 20)
                          : eliminated
                              ? const Icon(Icons.close,
                                  color: Colors.red, size: 20)
                              : null,
                ),
                const SizedBox(width: 8),
                PlayerAvatar(
                  avatarPath: player.avatarPath,
                  name: player.name,
                  radius: 14,
                  backgroundColor:
                      eliminated ? Colors.grey : playerColor(index),
                ),
                const SizedBox(width: 8),
                // Number badge
                if (assignedNumbers[index] > 0)
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: Text('${assignedNumbers[index]}',
                        style: const TextStyle(fontSize: 11)),
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
                      if (isKiller[index] && !eliminated)
                        const Text('KILLER',
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      if (_lastDartsLabel(index).isNotEmpty)
                        Text(
                          _lastDartsLabel(index),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
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
                        ...List.generate(shields[index], (_) {
                          return const Icon(
                            Icons.shield,
                            size: 16,
                            color: Colors.blue,
                          );
                        }),
                      if (widget.config.shields && shields[index] > 0)
                        const SizedBox(width: 4),
                      // Life hearts
                      ...List.generate(widget.config.lives, (li) {
                        final hasLife = li < lives[index];
                        return Icon(
                          hasLife ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: hasLife ? Colors.red : Colors.grey[700],
                        );
                      }),
                    ],
                  ),
              ],
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
                style: TextStyle(color: Colors.grey[400]),
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
                backgroundColor: const Color(0xFFE53935)),
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

  _KillerUndoData({
    required this.playerIndex,
    required this.dartsInTurn,
    required this.livesBefore,
    required this.isKillerBefore,
    required this.isEliminatedBefore,
    required this.shieldsBefore,
    required this.roundNumber,
  });
}
