import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../widgets/dart_board.dart';
import '../data/checkout_table.dart';
import '../services/player_storage.dart';
import '../models/saved_player.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/meme_service.dart';
import '../services/sound_service.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../services/stats_recorder.dart';
import '../widgets/player_avatar.dart';
import '../models/game_result.dart';
import '../services/game_logger.dart';
import 'post_game_screen.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../services/battery_sampler.dart';

enum _ThrowOutcome { continueTurn, finish, turnEndNoBust, bust }

class GameScreen extends StatefulWidget {
  final List<Player> players;
  final String masterOut; // 'none', 'double', 'master'
  final int startingScore;
  final bool handicap;
  final bool noBust;

  const GameScreen({
    super.key,
    required this.players,
    this.masterOut = 'none',
    required this.startingScore,
    this.handicap = false,
    this.noBust = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<Player> players;
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  List<DartThrow> throwHistory = [];
  int? winnerIndex;
  late int scoreAtStartOfTurn;
  int _turnIdCounter = 0;
  String? lastThrowLabel;
  final GameAnnouncer _announcer = GameAnnouncer();
  final MemeService _meme = MemeService();
  final GameLogger _log = GameLogger.instance;
  List<int> finishedPlayers = [];
  bool _gameFullyOver = false;
  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};
  final ScrollController _scoreboardController = ScrollController();
  bool _soundEnabled = true;
  bool _ttsEnabled = false;
  bool _offensiveEnabled = false;
  bool _missSoundPlayed = false;
  int _consecutiveMisses = 0;
  String? _pendingVideoEvent;

  // Round tracking for same-round checkout
  int _roundNumber = 0;
  Set<int> _playersCompletedThisRound = {};
  List<int> _finishedBeforeRound = [];
  List<_PendingCheckout> _pendingCheckouts = [];
  List<int> _suddenDeathPlayers = [];
  bool _inSuddenDeath = false;

  // No-bust mode state (only populated when widget.noBust == true)
  List<int> _totalDartsPerPlayer = [];
  final List<_FinishEntry> _finishes = [];

  static const double _playerCardHeight = 72.0;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    _totalDartsPerPlayer = List<int>.filled(players.length, 0, growable: true);
    scoreAtStartOfTurn = players[0].score;
    _announcer.init();
    _meme.init();
    _log.logGameStart(
      gameMode: 'X01 ${widget.startingScore} ${widget.masterOut == 'double' ? 'Double-Out' : widget.masterOut == 'master' ? 'Master-Out' : 'Free-Out'}${widget.noBust ? ' No-Bust' : ''}',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: players.map((p) => p.score).toList(),
      config: {'handicap': widget.handicap, 'masterOut': widget.masterOut, 'noBust': widget.noBust},
    );
    BatterySampler.instance.start('X01');
    AppSettings.getSoundEffectsEnabled().then((v) {
      setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
      _meme.setEnabled(v);
    });
    AppSettings.getTtsEnabled().then((v) => setState(() => _ttsEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    _scoreboardController.dispose();
    super.dispose();
  }

  /// Classifies a throw outcome based on resulting score, multiplier, out-rule,
  /// and no-bust mode. Pure helper — no state mutation.
  _ThrowOutcome _classifyThrow(int newScore, int multiplier) {
    final isValidOut = widget.masterOut == 'double'
        ? multiplier == 2
        : widget.masterOut == 'master'
            ? multiplier >= 2
            : true;
    final needsSpecialOut = widget.masterOut != 'none';

    if (widget.noBust) {
      if (newScore > 1) return _ThrowOutcome.continueTurn;
      if (newScore == 1) {
        return needsSpecialOut
            ? _ThrowOutcome.turnEndNoBust
            : _ThrowOutcome.continueTurn;
      }
      // newScore <= 0
      return isValidOut ? _ThrowOutcome.finish : _ThrowOutcome.turnEndNoBust;
    }

    // Standard X01 (existing logic, expressed via outcomes)
    if (newScore < 0) return _ThrowOutcome.bust;
    if (newScore == 0 && needsSpecialOut && !isValidOut) return _ThrowOutcome.bust;
    if (newScore == 1 && needsSpecialOut) return _ThrowOutcome.bust;
    if (newScore == 0) return _ThrowOutcome.finish;
    return _ThrowOutcome.continueTurn;
  }

  void _scrollToCurrentPlayer() {
    if (!_scoreboardController.hasClients) return;
    final maxScroll = _scoreboardController.position.maxScrollExtent;
    // Center the current player in the visible area (show ~3 players)
    final targetOffset = (currentPlayerIndex * _playerCardHeight -
            _playerCardHeight) // one card above
        .clamp(0.0, maxScroll);
    _scoreboardController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onDartHit(int segment, int multiplier) async {
    if (finishedPlayers.contains(currentPlayerIndex)) return;

    final points = segment * multiplier;
    final player = players[currentPlayerIndex];
    final scoreBefore = player.score;
    final newScore = player.score - points;

    bool isBust = false;

    final needsSpecialOut = widget.masterOut != 'none';
    final isValidOut = widget.masterOut == 'double'
        ? multiplier == 2
        : widget.masterOut == 'master'
            ? multiplier >= 2
            : true;

    if (newScore < 0) {
      isBust = true;
    } else if (newScore == 0 && needsSpecialOut && !isValidOut) {
      isBust = true;
    } else if (newScore == 1 && needsSpecialOut) {
      // Score 1 is impossible to check out with double-out (min D1=2)
      // or master-out (min D1=2 or T1=3)
      isBust = true;
    }

    final dartThrow = DartThrow(
      playerIndex: currentPlayerIndex,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: scoreBefore,
      turnNumber: dartsInTurn,
      scoreAtStartOfTurn: scoreAtStartOfTurn,
      turnId: _turnIdCounter,
      roundNumber: _roundNumber,
    );

    // Pre-roll video dice and track per-dart events
    final vc = _meme.frequencyChance;
    final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;

    if (segment == 25 && multiplier == 2) _pendingVideoEvent ??= 'bullseye';
    if (segment == 0) {
      _consecutiveMisses++;
      if (_consecutiveMisses >= 3) {
        _pendingVideoEvent ??= 'three_misses';
        _consecutiveMisses = 0;
      }
    } else {
      _consecutiveMisses = 0;
    }

    bool isTurnEnd = false;

    setState(() {
      throwHistory.add(dartThrow);

      if (isBust) {
        isTurnEnd = true;
        // 50/50 between video and sound for bust
        final bustShowVideo = videoRoll && Random().nextBool();
        if (bustShowVideo) _pendingVideoEvent = 'bust';
        player.score = scoreAtStartOfTurn;
        lastThrowLabel = '${dartThrow.label} - BUST!';
        _log.logThrow(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, label: dartThrow.label, points: points, scoreBefore: scoreBefore, scoreAfter: scoreAtStartOfTurn, dartNumber: dartsInTurn, extra: 'BUST');
        _log.logBust(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, playerName: player.name, throwLabel: dartThrow.label, scoreReset: scoreAtStartOfTurn);
        _announcer.announceGameEvent('Bust');
        // Play random bust sound only if video won't play
        if (_soundEnabled && !bustShowVideo) {
          _meme.markSoundPlayed();
          SoundService.instance.playRandomMaybe([
            'x01/negative/out',
            if (_offensiveEnabled) 'x01/offensive/end of round',
          ], chance: vc);
        }
        if (bustShowVideo) _meme.markSoundPlayed();
        _meme.resetTurn();
        _playersCompletedThisRound.add(currentPlayerIndex);
        _advancePlayer();
      } else if (newScore == 0) {
        // Checkout! Add as pending — don't end game until round completes
        isTurnEnd = true;
        _pendingVideoEvent = 'checkout'; // highest priority
        player.score = 0;
        lastThrowLabel = dartThrow.label;
        _log.logThrow(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, label: dartThrow.label, points: points, scoreBefore: scoreBefore, scoreAfter: 0, dartNumber: dartsInTurn, extra: 'CHECKOUT');
        _log.logCheckout(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, playerName: player.name, dartsUsed: dartsInTurn + 1, checkoutScore: scoreAtStartOfTurn);
        _announcer.announceGameEvent('${player.name} checks out!');
        _meme.onThrow(dartThrow, remainingScore: 0);
        if (videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();

        finishedPlayers.add(currentPlayerIndex);
        _pendingCheckouts.add(_PendingCheckout(
          playerIndex: currentPlayerIndex,
          dartsUsedInTurn: dartsInTurn + 1,
          checkoutScore: scoreAtStartOfTurn,
        ));

        _playersCompletedThisRound.add(currentPlayerIndex);

        // Check if all active players have finished their turn this round
        final roundComplete = _isRoundComplete();
        if (!roundComplete) {
          // Check if any remaining player can theoretically match or beat this checkout
          final bestDarts = _pendingCheckouts.map((c) => c.dartsUsedInTurn).reduce(min);
          final canMatch = _canAnyRemainingPlayerCheckout(bestDarts);
          _log.logState({
            'roundComplete': false,
            'canAnyRemainingCheckout': canMatch,
            'bestDarts': bestDarts,
            'pendingCheckouts': _pendingCheckouts.map((c) => 'P${c.playerIndex}(${c.dartsUsedInTurn}d,${c.checkoutScore})').toList(),
            'completedThisRound': _playersCompletedThisRound,
            'finishedPlayers': finishedPlayers,
          });
          _advancePlayer();
        } else {
          _log.logState({'roundComplete': true, 'completedThisRound': _playersCompletedThisRound, 'finishedPlayers': finishedPlayers});
        }
      } else {
        player.score = newScore;
        lastThrowLabel = dartThrow.label;
        _log.logThrow(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, label: dartThrow.label, points: points, scoreBefore: scoreBefore, scoreAfter: newScore, dartNumber: dartsInTurn);
        final memeTriggered = _meme.onThrow(dartThrow, remainingScore: newScore);
        if (!memeTriggered && !_missSoundPlayed) {
          _announcer.announceThrow(dartThrow.spokenLabel);
        }
        if (multiplier == 3 && segment >= 18 && segment <= 20) {
          if (_meme.frequency < 10) _meme.markSoundPlayed();
          SoundService.instance.playRandomMaybe(['triple'], chance: vc);
        } else if (segment == 25) {
          if (_meme.frequency < 10) _meme.markSoundPlayed();
          SoundService.instance.play('bull');
        }
        dartsInTurn++;
        if (dartsInTurn >= 3) {
          isTurnEnd = true;
          // Turn-end video events
          final turnTotal = scoreAtStartOfTurn - player.score;
          if (turnTotal >= 120) _pendingVideoEvent ??= 'high_round';
          else if (turnTotal < 10) _pendingVideoEvent ??= 'low_round';
          // Suppress meme sounds if video will play
          if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
          _meme.onTurnEnd();
          _playersCompletedThisRound.add(currentPlayerIndex);
          _advancePlayer();
        }
      }
    });

    // Show video at turn end only (awaited so it doesn't get hidden)
    if (isTurnEnd && _pendingVideoEvent != null && videoRoll) {
      await VideoService.instance.showRandomFromFolder(context, _pendingVideoEvent!, chance: 1);
    }
    if (isTurnEnd) _pendingVideoEvent = null;
    if (!mounted) return;

    // Check round completion after setState
    if (_isRoundComplete()) {
      await _resolveRoundEnd();
    }
  }

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  Future<void> _updateStats() async {
    if (_midGamePlayerChanges) {
      // Rating and stats skipped, but still record mid-game join/leave counters
      await _recordMidGameCounters();
      return;
    }
    final savedPlayers = await PlayerStorage.loadPlayers();

    // Capture ratings before update
    _ratingsBefore = {};
    for (final p in players) {
      if (p.savedPlayerId == null) continue;
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;

      final savedIndex = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (savedIndex < 0) continue;

      final sp = savedPlayers[savedIndex];
      sp.gamesPlayed++;
      if (finishedPlayers.isNotEmpty && finishedPlayers.first == pi) sp.gamesWon++;

      // Calculate turn scores for this player
      final playerThrows =
          throwHistory.where((t) => t.playerIndex == pi).toList();

      int currentTurnScore = 0;
      int? currentTurnStart;

      for (final t in playerThrows) {
        if (currentTurnStart != t.scoreAtStartOfTurn) {
          if (currentTurnStart != null) {
            sp.totalTurns++;
            sp.totalTurnScore += currentTurnScore;
            if (currentTurnScore > sp.highestTurnScore) {
              sp.highestTurnScore = currentTurnScore;
            }
          }
          currentTurnStart = t.scoreAtStartOfTurn;
          currentTurnScore = 0;
        }
        currentTurnScore += t.points;
      }
      // Save last turn
      if (currentTurnStart != null) {
        sp.totalTurns++;
        sp.totalTurnScore += currentTurnScore;
        if (currentTurnScore > sp.highestTurnScore) {
          sp.highestTurnScore = currentTurnScore;
        }
      }
    }

    // Build placements from finishedPlayers order
    final placements = List.generate(players.length, (i) {
      final idx = finishedPlayers.indexOf(i);
      if (idx >= 0) return idx + 1;
      return finishedPlayers.length + 1; // Unfinished players get last
    });
    // Build per-player mode counters
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final playerThrows = throwHistory.where((t) => t.playerIndex == pi).toList();

      int totalDarts = playerThrows.length;
      int doublesHit = 0;
      int triplesHit = 0;
      int bullsHit = 0, misses = 0;
      int totalTurnScoreMode = 0, totalTurnsMode = 0, highestTurnMode = 0;
      int turnsOver100 = 0;
      final segmentHits = <String, int>{};

      int currentTurnScore = 0;
      int? currentTurnStart;

      for (final t in playerThrows) {
        // Turn tracking
        if (currentTurnStart != t.scoreAtStartOfTurn) {
          if (currentTurnStart != null) {
            totalTurnsMode++;
            totalTurnScoreMode += currentTurnScore;
            if (currentTurnScore > highestTurnMode) highestTurnMode = currentTurnScore;
            if (currentTurnScore >= 100) turnsOver100++;
          }
          currentTurnStart = t.scoreAtStartOfTurn;
          currentTurnScore = 0;
        }
        currentTurnScore += t.points;

        // Per-segment hit tracking for heatmap
        final segKey = 'seg_${t.segment}';
        segmentHits[segKey] = (segmentHits[segKey] ?? 0) + 1;
        if (t.segment > 0) {
          final mulSuffix = t.multiplier == 3 ? '_t' : t.multiplier == 2 ? '_d' : '_s';
          final detailKey = 'seg_${t.segment}$mulSuffix';
          segmentHits[detailKey] = (segmentHits[detailKey] ?? 0) + 1;
        }

        // Dart-level stats
        if (t.segment == 0) {
          misses++;
        } else {
          if (t.segment == 25) bullsHit++;
          if (t.multiplier == 2) { doublesHit++; }
          else if (t.multiplier == 3) { triplesHit++; }
        }
      }
      // Save last turn
      if (currentTurnStart != null) {
        totalTurnsMode++;
        totalTurnScoreMode += currentTurnScore;
        if (currentTurnScore > highestTurnMode) highestTurnMode = currentTurnScore;
        if (currentTurnScore >= 100) turnsOver100++;
      }

      // Checkout dart (if player finished)
      int bestCheckout = 0;
      if (finishedPlayers.contains(pi) && playerThrows.isNotEmpty) {
        bestCheckout = playerThrows.last.scoreAtStartOfTurn;
      }

      modeCounters[playerId] = {
        'totalDarts': totalDarts,
        'totalTurnScore': totalTurnScoreMode,
        'totalTurns': totalTurnsMode,
        'max:highestTurn': highestTurnMode,
        'turnsOver100': turnsOver100,
        'doublesHit': doublesHit,
        'triplesHit': triplesHit,
        'bullsHit': bullsHit,
        'misses': misses,
        'checkouts': finishedPlayers.contains(pi) ? 1 : 0,
        'max:bestCheckout': bestCheckout,
        ...segmentHits,
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
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsAfter[p.savedPlayerId!] = sp.rating;
    }

    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _advancePlayer() {
    final fromIndex = currentPlayerIndex;
    dartsInTurn = 0;
    _missSoundPlayed = false;
    _turnIdCounter++;
    final startIndex = currentPlayerIndex;
    if (_inSuddenDeath) {
      // In sudden death, only cycle through sudden death players
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
        if (currentPlayerIndex == startIndex) break; // Safety: prevent infinite loop
      } while (!_suddenDeathPlayers.contains(currentPlayerIndex));
    } else {
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
        if (currentPlayerIndex == startIndex) break; // Safety: prevent infinite loop
      } while (finishedPlayers.contains(currentPlayerIndex));
    }
    scoreAtStartOfTurn = players[currentPlayerIndex].score;
    _log.logAdvance(roundNumber: _roundNumber, fromIndex: fromIndex, toIndex: currentPlayerIndex, toName: players[currentPlayerIndex].name, toScore: scoreAtStartOfTurn);
    _log.logTurnStart(roundNumber: _roundNumber, playerIndex: currentPlayerIndex, playerName: players[currentPlayerIndex].name, score: scoreAtStartOfTurn, checkoutHint: _checkoutFor(scoreAtStartOfTurn).isNotEmpty ? _checkoutFor(scoreAtStartOfTurn) : null);
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    if (!_inSuddenDeath) {
      _announcer.announceScore('${players[currentPlayerIndex].score} remaining');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
  }

  /// Check if all players who were active at the start of this round have completed their turn.
  bool _isRoundComplete() {
    if (_inSuddenDeath) {
      return _suddenDeathPlayers.every((i) => _playersCompletedThisRound.contains(i));
    }
    for (int i = 0; i < players.length; i++) {
      if (_finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue; // removed mid-game or finished this round
      if (!_playersCompletedThisRound.contains(i)) return false;
    }
    return true;
  }

  /// Called when a round completes. Resolves pending checkouts or starts new round.
  Future<void> _resolveRoundEnd() async {
    _log.logRoundComplete(roundNumber: _roundNumber, completedPlayers: _playersCompletedThisRound, finishedPlayers: finishedPlayers);

    if (_inSuddenDeath) {
      await _resolveSuddenDeath();
      return;
    }

    if (_pendingCheckouts.isEmpty) {
      // No checkouts this round — check if game should end
      final activePlayers = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .toList();
      if (activePlayers.length <= 1) {
        _log.logResolve(roundNumber: _roundNumber, details: 'no checkouts, active=${activePlayers.length} → gameOver');
        setState(() {
          if (activePlayers.length == 1) finishedPlayers.add(activePlayers.first);
          _gameFullyOver = true;
        });
        _updateStats().then((_) => _showPostGame());
        return;
      }
      // Start new round
      _log.logResolve(roundNumber: _roundNumber, details: 'no checkouts, active=$activePlayers → new round');
      setState(() {
        _roundNumber++;
        _playersCompletedThisRound = {};
        _finishedBeforeRound = List.from(finishedPlayers);
      });
      return;
    }

    // Sort by tiebreaker
    _pendingCheckouts.sort(_checkoutComparator);
    final checkoutSummary = _pendingCheckouts.map((c) => 'P${c.playerIndex}(${c.dartsUsedInTurn}d,${c.checkoutScore})').join(', ');

    // Check for ties at the top
    if (_pendingCheckouts.length > 1 &&
        _checkoutComparator(_pendingCheckouts[0], _pendingCheckouts[1]) == 0) {
      // Find all tied players
      final tied = <_PendingCheckout>[_pendingCheckouts[0]];
      for (int i = 1; i < _pendingCheckouts.length; i++) {
        if (_checkoutComparator(_pendingCheckouts[0], _pendingCheckouts[i]) == 0) {
          tied.add(_pendingCheckouts[i]);
        } else {
          break;
        }
      }
      _log.logResolve(roundNumber: _roundNumber, details: 'TIED checkouts [$checkoutSummary] → sudden death for ${tied.map((c) => 'P${c.playerIndex}').join(',')}');
      _startSuddenDeath(tied.map((c) => c.playerIndex).toList());
      return;
    }

    // Reorder finishedPlayers by tiebreaker result
    final pendingIndices = _pendingCheckouts.map((c) => c.playerIndex).toSet();
    finishedPlayers.removeWhere((i) => pendingIndices.contains(i));
    for (final checkout in _pendingCheckouts) {
      finishedPlayers.add(checkout.playerIndex);
    }

    // Check if game is fully over
    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    _log.logResolve(roundNumber: _roundNumber, details: 'checkouts=[$checkoutSummary] finished=$finishedPlayers active=$activePlayers gameOver=${activePlayers.length <= 1}');

    setState(() {
      winnerIndex = finishedPlayers.first;
      _pendingCheckouts.clear();
      _roundNumber++;
      _playersCompletedThisRound = {};
      _finishedBeforeRound = List.from(finishedPlayers);

      if (activePlayers.length <= 1) {
        if (activePlayers.length == 1) {
          finishedPlayers.add(activePlayers.first);
        }
        _gameFullyOver = true;
      }
    });

    // Only announce winner and play victory sound when game is fully over
    if (_gameFullyOver) {
      final winner = players[finishedPlayers.first];
      _log.logGameEnd(playerNames: players.map((p) => p.name).toList(), finishedOrder: finishedPlayers, gameFullyOver: true);
      BatterySampler.instance.stop();
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(winner.name);
      _updateStats().then((_) => _showPostGame());
    } else {
      _showPostGame();
    }
  }

  void _startSuddenDeath(List<int> tiedPlayers) {
    _log.log('SUDDEN_DEATH starting for ${tiedPlayers.map((i) => 'P$i(${players[i].name})').join(', ')}');
    setState(() {
      _inSuddenDeath = true;
      _suddenDeathPlayers = tiedPlayers;
      _playersCompletedThisRound = {};
      _roundNumber++;

      // Restore scores for sudden death (give them a fake high score to throw from)
      // In sudden death, we just compare turn scores, so set them all to 999
      for (final pi in tiedPlayers) {
        players[pi].score = 999;
        finishedPlayers.remove(pi);
      }

      currentPlayerIndex = tiedPlayers.first;
      dartsInTurn = 0;
      scoreAtStartOfTurn = players[currentPlayerIndex].score;
      _turnIdCounter++;
    });

    _announcer.announceGameEvent('Sudden death!');
  }

  Future<void> _resolveSuddenDeath() async {
    // Compare turn scores for sudden death players
    final scores = <int, int>{};
    for (final pi in _suddenDeathPlayers) {
      final turnThrows = throwHistory
          .where((t) => t.playerIndex == pi && t.roundNumber == _roundNumber)
          .toList();
      scores[pi] = turnThrows.fold<int>(0, (sum, t) => sum + t.points);
    }

    // Sort by highest score
    final sorted = _suddenDeathPlayers.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    // Check if still tied
    if (sorted.length > 1 && scores[sorted[0]] == scores[sorted[1]]) {
      // Still tied — another sudden death round
      final tiedScore = scores[sorted[0]]!;
      final stillTied = sorted.where((pi) => scores[pi] == tiedScore).toList();
      _startSuddenDeath(stillTied);
      return;
    }

    // Sudden death resolved — winner determined
    setState(() {
      _inSuddenDeath = false;
      // Set scores back to 0 for all sudden death players (they all checked out)
      for (final pi in _suddenDeathPlayers) {
        players[pi].score = 0;
        if (!finishedPlayers.contains(pi)) {
          finishedPlayers.add(pi);
        }
      }

      // Reorder finishedPlayers: put sudden death players in order
      final sdSet = _suddenDeathPlayers.toSet();
      finishedPlayers.removeWhere((i) => sdSet.contains(i));
      for (final pi in sorted) {
        finishedPlayers.add(pi);
      }

      winnerIndex = finishedPlayers.first;
      _suddenDeathPlayers.clear();
      _pendingCheckouts.clear();
      _playersCompletedThisRound = {};
      _roundNumber++;
      _finishedBeforeRound = List.from(finishedPlayers);

      final activePlayers = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .toList();
      if (activePlayers.length <= 1) {
        if (activePlayers.length == 1) {
          finishedPlayers.add(activePlayers.first);
        }
        _gameFullyOver = true;
      }
    });

    // Only announce winner and play victory sound when game is fully over
    if (_gameFullyOver) {
      final winner = players[finishedPlayers.first];
      _log.logGameEnd(playerNames: players.map((p) => p.name).toList(), finishedOrder: finishedPlayers, gameFullyOver: true);
      BatterySampler.instance.stop();
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(winner.name);
      _updateStats().then((_) => _showPostGame());
    } else {
      _showPostGame();
    }
  }

  /// Maximum score that can be checked out in [darts] throws.
  int _maxCheckoutForDarts(int darts) {
    if (widget.masterOut == 'double') {
      const maxes = [0, 50, 110, 170];
      return darts >= 1 && darts <= 3 ? maxes[darts] : 170;
    } else {
      // master-out or no requirement
      const maxes = [0, 60, 120, 180];
      return darts >= 1 && darts <= 3 ? maxes[darts] : 180;
    }
  }

  /// Check if any remaining (not yet thrown this round) player can theoretically
  /// check out in [maxDarts] or fewer darts.
  bool _canAnyRemainingPlayerCheckout(int maxDarts) {
    final maxScore = _maxCheckoutForDarts(maxDarts);
    for (int i = 0; i < players.length; i++) {
      if (_finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue;
      if (_playersCompletedThisRound.contains(i)) continue;
      if (players[i].score <= maxScore && players[i].score > 0) return true;
    }
    return false;
  }

  int _checkoutComparator(_PendingCheckout a, _PendingCheckout b) {
    // Rule 1: Fewer darts wins
    if (a.dartsUsedInTurn != b.dartsUsedInTurn) {
      return a.dartsUsedInTurn.compareTo(b.dartsUsedInTurn);
    }
    // Rule 2: Higher checkout score wins (checked out from further away)
    if (a.checkoutScore != b.checkoutScore) {
      return b.checkoutScore.compareTo(a.checkoutScore);
    }
    // Rule 3: True tie — sudden death
    return 0;
  }

  void _onMiss() {
    _missSoundPlayed = false;
    if (_soundEnabled) {
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

  void _handleOutsideBoardTap() {
    _onMiss();
  }

  String _checkoutFor(int score) {
    if (widget.masterOut != 'none') {
      return checkoutTable[score] ?? '';
    }
    return straightOutCheckout(score) ?? '';
  }

  String _lastDartsLabel(int playerIndex) {
    final darts =
        throwHistory.where((t) => t.playerIndex == playerIndex).toList();
    if (darts.isEmpty) return '';
    // For the current player, only show throws from the current turn
    if (playerIndex == currentPlayerIndex) {
      final currentTurnDarts = darts
          .where((t) => t.turnId == _turnIdCounter)
          .toList();
      if (currentTurnDarts.isEmpty) return '';
      return currentTurnDarts.map((t) => t.shortLabel).join(' \u00b7 ');
    }
    final last3 = darts.length <= 3 ? darts : darts.sublist(darts.length - 3);
    return last3.map((t) => t.shortLabel).join(' \u00b7 ');
  }

  void _undo() {
    if (throwHistory.isEmpty) return;
    _announcer.announceGameEvent('Back');

    setState(() {
      final lastThrow = throwHistory.removeLast();
      _log.logUndo(playerIndex: lastThrow.playerIndex, playerName: players[lastThrow.playerIndex].name, throwLabel: lastThrow.label, scoreRestored: lastThrow.scoreBefore, roundNumber: lastThrow.roundNumber);
      // If the undone throw was a checkout, remove from finished list and pending
      if (lastThrow.scoreBefore - lastThrow.points == 0 ||
          finishedPlayers.contains(lastThrow.playerIndex)) {
        finishedPlayers.remove(lastThrow.playerIndex);
        _pendingCheckouts.removeWhere((c) => c.playerIndex == lastThrow.playerIndex);
        _gameFullyOver = false;
        _inSuddenDeath = false;
        _suddenDeathPlayers.clear();
      }
      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
      players[lastThrow.playerIndex].score = lastThrow.scoreBefore;
      currentPlayerIndex = lastThrow.playerIndex;
      dartsInTurn = lastThrow.turnNumber;
      scoreAtStartOfTurn = lastThrow.scoreAtStartOfTurn;
      _turnIdCounter = lastThrow.turnId;
      _roundNumber = lastThrow.roundNumber;
      lastThrowLabel = null;

      // Rebuild round state from throw history
      _rebuildRoundState();
      _log.logState({'afterUndo': true, 'round': _roundNumber, 'currentPlayer': currentPlayerIndex, 'dartsInTurn': dartsInTurn, 'completedThisRound': _playersCompletedThisRound, 'finishedBefore': _finishedBeforeRound, 'finishedPlayers': finishedPlayers});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
  }

  /// Reconstruct round tracking state from throw history after undo.
  void _rebuildRoundState() {
    _playersCompletedThisRound = {};
    _finishedBeforeRound = [];

    // Find players who finished before this round
    for (final t in throwHistory) {
      if (t.roundNumber < _roundNumber && t.scoreBefore - t.points == 0) {
        if (!_finishedBeforeRound.contains(t.playerIndex)) {
          _finishedBeforeRound.add(t.playerIndex);
        }
      }
    }

    // Find completed turns in current round by grouping throws by turnId
    final currentRoundThrows =
        throwHistory.where((t) => t.roundNumber == _roundNumber).toList();
    final throwsByTurn = <int, List<DartThrow>>{};
    for (final t in currentRoundThrows) {
      throwsByTurn.putIfAbsent(t.turnId, () => []).add(t);
    }

    for (final entry in throwsByTurn.entries) {
      final throws = entry.value;
      final lastThrow = throws.last;
      final isCheckout = lastThrow.scoreBefore - lastThrow.points == 0;
      final isBust = lastThrow.scoreBefore == lastThrow.scoreAtStartOfTurn &&
          throws.length < 3 &&
          !isCheckout &&
          lastThrow != throwHistory.last; // Don't count incomplete current turn
      final isThirdDart = lastThrow.turnNumber == 2;

      if (isCheckout || isBust || isThirdDart) {
        _playersCompletedThisRound.add(lastThrow.playerIndex);
      }
    }
  }

  GameResult _buildGameResult() {
    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final playerThrows = throwHistory.where((t) => t.playerIndex == i).toList();
      final dartCount = playerThrows.length;

      // Compute per-player turn scores
      int highestTurn = 0;
      double totalTurnScore = 0;
      int turnCount = 0;
      int currentTurnScore = 0;
      int? currentTurnStart;

      for (final t in playerThrows) {
        if (currentTurnStart != t.scoreAtStartOfTurn) {
          if (currentTurnStart != null) {
            if (currentTurnScore > highestTurn) highestTurn = currentTurnScore;
            totalTurnScore += currentTurnScore;
            turnCount++;
          }
          currentTurnStart = t.scoreAtStartOfTurn;
          currentTurnScore = 0;
        }
        currentTurnScore += t.points;
      }
      if (currentTurnStart != null) {
        if (currentTurnScore > highestTurn) highestTurn = currentTurnScore;
        totalTurnScore += currentTurnScore;
        turnCount++;
      }

      // Checkout score (score at start of checkout turn = what they closed from)
      int? checkout;
      if (finishedPlayers.contains(i) && playerThrows.isNotEmpty) {
        checkout = playerThrows.last.scoreAtStartOfTurn;
      }

      // Determine placement
      int placement;
      final finishIdx = finishedPlayers.indexOf(i);
      if (finishIdx >= 0) {
        placement = finishIdx + 1;
      } else {
        placement = finishedPlayers.length + 1;
      }

      results.add(PlayerResult(
        name: p.name,
        avatarPath: p.avatarPath,
        placement: placement,
        stats: {
          'highestTurn': highestTurn,
          'avgTurn': turnCount > 0 ? totalTurnScore / turnCount : 0.0,
          'darts': dartCount,
          'checkout': ?checkout,
        },
        ratingBefore: p.savedPlayerId != null ? _ratingsBefore[p.savedPlayerId!] : null,
        ratingAfter: p.savedPlayerId != null ? _ratingsAfter[p.savedPlayerId!] : null,
      ));
    }

    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    return GameResult(
      gameMode: 'x01',
      results: results,
      canContinue: !_gameFullyOver && activePlayers.length > 1 && players.length > 2,
      statsSkipped: _midGamePlayerChanges,
    );
  }

  void _showPostGame() async {
    _log.log('→ PostGame (gameFullyOver=$_gameFullyOver)');
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PostGameScreen(result: _buildGameResult())),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo');
      _undo();
    } else if (result == 'continue') {
      // Continue with remaining players — start new round from first active player
      setState(() {
        winnerIndex = null;
        dartsInTurn = 0;
        _turnIdCounter++;
        // Find first non-finished player to start the new round
        for (int i = 0; i < players.length; i++) {
          if (!finishedPlayers.contains(i)) {
            currentPlayerIndex = i;
            break;
          }
        }
        scoreAtStartOfTurn = players[currentPlayerIndex].score;
      });
      _log.logPostGame(action: 'continue', details: 'startPlayer=P$currentPlayerIndex(${players[currentPlayerIndex].name}) score=${players[currentPlayerIndex].score}');
      _announcer.announceNextPlayer(players[currentPlayerIndex].name);
      _announcer.announceScore('${players[currentPlayerIndex].score} remaining');
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
    } else {
      // New Game — save stats if not already saved
      _log.logPostGame(action: 'newGame');
      _log.logGameEnd(playerNames: players.map((p) => p.name).toList(), finishedOrder: finishedPlayers, gameFullyOver: _gameFullyOver);
      BatterySampler.instance.stop();
      if (!_gameFullyOver) {
        _gameFullyOver = true;
        await _updateStats();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String get _appBarTitle {
    final outLabel = widget.masterOut == 'double'
        ? 'Double-Out'
        : widget.masterOut == 'master'
            ? 'Master-Out'
            : 'Free-Out';
    final suffix = widget.noBust ? ' (No-Bust)' : '';
    return '${widget.startingScore} - $outLabel$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = players[currentPlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(),
        ),
        actions: [
          IconButton(
            icon: Text(_soundEnabled ? '🤡' : '🤐', style: const TextStyle(fontSize: 22)),
            onPressed: () {
              setState(() => _soundEnabled = !_soundEnabled);
              SoundService.instance.setEnabled(_soundEnabled);
              _meme.setEnabled(_soundEnabled);
              AppSettings.setSoundEffectsEnabled(_soundEnabled);
              AppSettings.setMemeEnabled(_soundEnabled);
            },
            tooltip: 'Sound effects',
          ),
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.mic : Icons.mic_off),
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              TtsService.instance.setEnabled(_ttsEnabled);
            },
            tooltip: 'Text-to-speech',
          ),
          if (_soundEnabled)
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showSoundSettingsDialog,
              tooltip: 'Sound settings',
            ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _gameFullyOver ? null : _openPlayerManagement,
            tooltip: 'Manage players',
          ),
          if (throwHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo,
              tooltip: 'Undo',
            ),
        ],
      ),
      body: Column(
        children: [
          // Sudden death banner
          if (_inSuddenDeath)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFE53935),
              child: const Text(
                'SUDDEN DEATH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          // Pending checkouts banner
          if (_pendingCheckouts.isNotEmpty && !_inSuddenDeath)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.green.withAlpha(40),
              child: Text(
                _pendingCheckouts.length == 1
                    ? '${players[_pendingCheckouts.first.playerIndex].name} checked out! Round continues...'
                    : '${_pendingCheckouts.length} players checked out! Round continues...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green, fontSize: 14),
              ),
            ),
          // Current player info bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: playerColor(currentPlayerIndex).withAlpha(55),
              border: Border(
                bottom: BorderSide(
                  color: playerColor(currentPlayerIndex).withAlpha(160),
                  width: 1,
                ),
                left: BorderSide(
                  color: playerColor(currentPlayerIndex),
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                // Name + dart counter
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPlayer.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: playerColor(currentPlayerIndex),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Dart ${dartsInTurn + 1} of 3',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                          ),
                          const SizedBox(width: 10),
                          // Dart indicators — larger, player-colored
                          ...List.generate(3, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                i < dartsInTurn
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                size: 16,
                                color: playerColor(currentPlayerIndex),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                // Checkout suggestion (centered between name and score)
                if (_checkoutFor(currentPlayer.score).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber[400],
                          ),
                        ),
                        Text(
                          _checkoutFor(currentPlayer.score),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Score
                Text(
                  '${currentPlayer.score}',
                  style: const TextStyle(
                      fontSize: 52, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Dart board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DartBoard(
                onHit: !finishedPlayers.contains(currentPlayerIndex) ? _onDartHit : (a, b) {},
                onOutsideTap: !finishedPlayers.contains(currentPlayerIndex)
                    ? _handleOutsideBoardTap
                    : null,
              ),
            ),
          ),

          // Last throw info + Back/Miss buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                if (lastThrowLabel != null)
                  Expanded(
                    child: Text(
                      'Last: $lastThrowLabel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: lastThrowLabel!.contains('BUST')
                            ? const Color(0xFFE53935)
                            : Colors.white,
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                if (throwHistory.isNotEmpty) ...[
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _undo,
                      icon: const Icon(Icons.undo, size: 20),
                      label: const Text('Back', style: TextStyle(fontSize: 18)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(color: Colors.grey[700]!),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton(
                  onPressed: !finishedPlayers.contains(currentPlayerIndex) ? _onMiss : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Miss', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: !finishedPlayers.contains(currentPlayerIndex) ? _onMiss : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Player scoreboard (shows ~3 players, scrolls to active)
          Container(
            constraints: BoxConstraints(
              maxHeight: _playerCardHeight * 3,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: ListView.builder(
              controller: _scoreboardController,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final isCurrent =
                    index == currentPlayerIndex && winnerIndex == null;
                final isWinner = index == winnerIndex;
                final hasPendingCheckout =
                    _pendingCheckouts.any((c) => c.playerIndex == index);

                final isRemoved = _removedPlayerIndices.contains(index);
                return Opacity(
                  opacity: isRemoved ? 0.4 : 1.0,
                  child: Container(
                  height: _playerCardHeight,
                  color: isCurrent
                      ? playerColor(index).withAlpha(25)
                      : isWinner
                          ? Colors.green.withAlpha(25)
                          : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: hasPendingCheckout
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 24)
                            : isCurrent
                                ? Icon(Icons.arrow_right,
                                    color: playerColor(index), size: 24)
                                : isWinner
                                    ? const Icon(Icons.emoji_events,
                                        color: Colors.amber, size: 24)
                                    : null,
                      ),
                      const SizedBox(width: 8),
                      PlayerAvatar(
                        avatarPath: player.avatarPath,
                        name: player.name,
                        radius: 22,
                        backgroundColor: playerColor(index),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (_lastDartsLabel(index).isNotEmpty)
                              Text(
                                _lastDartsLabel(index),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        hasPendingCheckout ? 'OUT' : '${player.score}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: hasPendingCheckout || isWinner ? Colors.green : null,
                        ),
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSoundSettingsDialog() {
    int currentFreq = _meme.frequency;
    bool currentOffensive = _offensiveEnabled;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Sound settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Offensive sounds'),
                  Switch(
                    value: currentOffensive,
                    onChanged: (v) => setDialogState(() => currentOffensive = v),
                    activeTrackColor: Theme.of(ctx).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Meme frequency'),
              ),
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
                onChanged: (v) => setDialogState(() => currentFreq = v.round()),
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
                setState(() => _offensiveEnabled = currentOffensive);
                AppSettings.setMemeOffensive(currentOffensive);
                _meme.setOffensive(currentOffensive);
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
              backgroundColor: const Color(0xFFE53935),
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  void _openPlayerManagement() {
    showMidGamePlayerSheet(
      context: context,
      players: players,
      isRemoved: (i) => _removedPlayerIndices.contains(i),
      gameOver: _gameFullyOver,
      colorFor: playerColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: (saved) => _addSavedPlayerMidGame(saved),
      onRemove: (i) => _removePlayerMidGame(i),
    );
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content: const Text(
            'Statistics will not be recorded for this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final removed = players[playerIndex];
              setState(() {
                _midGamePlayerChanges = true;
                _removedPlayerIndices.add(playerIndex);
                if (removed.savedPlayerId != null) {
                  _leftMidGameIds.add(removed.savedPlayerId!);
                }
                finishedPlayers.remove(playerIndex);
                // Mark as finished so they're skipped in rotation
                if (!finishedPlayers.contains(playerIndex)) {
                  finishedPlayers.add(playerIndex);
                }
                // If removed player was current, advance
                if (playerIndex == currentPlayerIndex) {
                  dartsInTurn = 0;
                  _meme.resetTurn();
                  _advancePlayer();
                }
                // If only 1 (or 0) active players remain, end the game
                final remaining = List.generate(players.length, (i) => i)
                    .where((i) => !finishedPlayers.contains(i))
                    .toList();
                if (remaining.length <= 1) {
                  if (winnerIndex == null) {
                    winnerIndex = remaining.isNotEmpty
                        ? remaining.first
                        : finishedPlayers.isNotEmpty
                            ? finishedPlayers.first
                            : 0;
                  }
                  _gameFullyOver = true;
                }
              });
              if (_gameFullyOver) {
                _updateStats().then((_) => _showPostGame());
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordMidGameCounters() async {
    await StatsRecorder.recordMidGameChanges(
      joinedIds: _joinedMidGameIds,
      leftIds: _leftMidGameIds,
    );
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Avg of active players' remaining score; added as last in round
    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    final avgScore = activePlayers.isEmpty
        ? widget.startingScore
        : (activePlayers.fold<int>(0, (s, i) => s + players[i].score) /
                activePlayers.length)
            .round();
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: avgScore,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
    });
  }
}

class _PendingCheckout {
  final int playerIndex;
  final int dartsUsedInTurn; // 1, 2, or 3
  final int checkoutScore; // score at start of checkout turn (what they closed from)

  _PendingCheckout({
    required this.playerIndex,
    required this.dartsUsedInTurn,
    required this.checkoutScore,
  });
}

class _FinishEntry {
  final int playerIndex;
  final int totalDartsAtFinish;
  final int overshoot; // 0 if exact-out, else abs(newScore)
  final int turnId;

  _FinishEntry({
    required this.playerIndex,
    required this.totalDartsAtFinish,
    required this.overshoot,
    required this.turnId,
  });
}
