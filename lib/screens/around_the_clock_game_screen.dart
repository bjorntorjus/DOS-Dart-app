import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/saved_player.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/clock_progress.dart';
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
import '../services/battery_sampler.dart';

class AroundTheClockGameScreen extends StatefulWidget {
  final List<Player> players;
  final AroundTheClockConfig config;

  const AroundTheClockGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<AroundTheClockGameScreen> createState() =>
      _AroundTheClockGameScreenState();
}

class _AroundTheClockGameScreenState extends State<AroundTheClockGameScreen> {
  late List<Player> players;
  late List<int> currentTargets; // current target per player
  int currentPlayerIndex = 0;
  int dartsInTurn = 0;
  List<DartThrow> throwHistory = [];
  int? winnerIndex;
  String? lastThrowLabel;
  List<int> finishedPlayers = [];
  bool _gameFullyOver = false;
  final GameAnnouncer _announcer = GameAnnouncer();
  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;
  bool _missSoundPlayed = false;
  int _turnIdCounter = 0;

  // Round tracking for same-round finish
  int _roundNumber = 0;
  Set<int> _playersCompletedThisRound = {};
  List<int> _finishedBeforeRound = [];
  List<_PendingFinish> _pendingFinishes = [];
  List<int> _suddenDeathPlayers = [];
  bool _inSuddenDeath = false;
  int _consecutiveMisses = 0;
  String? _pendingVideoEvent;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};

  bool get _isReverse => widget.config.reverse;
  int get _maxTarget => widget.config.includeBull ? 25 : 20;
  int get _startTarget => _isReverse ? (_maxTarget == 25 ? 25 : 20) : 1;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    final start = _startTarget;
    currentTargets = List.filled(players.length, start);
    for (final p in players) {
      p.score = start;
    }
    _announcer.init();
    _meme.init();
    _log.init();
    _log.logGameStart(
      gameMode: 'Around the Clock',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, start),
      config: {
        'reverse': _isReverse,
        'includeBull': widget.config.includeBull,
        'countMultiples': widget.config.countMultiples,
        'startTarget': start,
        'maxTarget': _maxTarget,
      },
    );
    BatterySampler.instance.start('AroundTheClock');
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    _ttsEnabled = TtsService.instance.enabled;
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  /// Check if a target value means "finished" (past the end of the sequence).
  bool _isFinished(int target) {
    if (_isReverse) return target < 1;
    return target > _maxTarget;
  }

  /// Advance target by one step in the correct direction.
  int _advanceTarget(int target) {
    if (_isReverse) {
      if (target == 25) return 20;
      if (target <= 1) return 0; // finished
      return target - 1;
    } else {
      if (target == 20 && widget.config.includeBull) return 25;
      if (target >= _maxTarget) return _maxTarget + 1; // finished
      if (target == 25) return 26; // finished
      return target + 1;
    }
  }

  /// How many segments remain for a player at [target] to finish.
  int _segmentsRemaining(int target) {
    if (_isFinished(target)) return 0;
    int count = 0;
    int t = target;
    while (!_isFinished(t)) {
      t = _advanceTarget(t);
      count++;
    }
    return count;
  }

  Future<void> _onDartHit(int segment, int multiplier) async {
    if (finishedPlayers.contains(currentPlayerIndex)) return;

    final target = currentTargets[currentPlayerIndex];
    final isHit = segment == target;
    final points = segment * multiplier;

    final dartThrow = DartThrow(
      playerIndex: currentPlayerIndex,
      segment: segment,
      multiplier: multiplier,
      points: points,
      scoreBefore: target,
      turnNumber: dartsInTurn,
      scoreAtStartOfTurn: currentTargets[currentPlayerIndex],
      turnId: _turnIdCounter,
      roundNumber: _roundNumber,
    );

    // Pre-roll video dice and track per-dart events
    final vc = _meme.frequencyChance;
    final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;

    if (segment == 0) {
      _consecutiveMisses++;
      if (_consecutiveMisses >= 3) {
        _pendingVideoEvent ??= 'three_misses';
        _consecutiveMisses = 0;
      }
    } else {
      _consecutiveMisses = 0;
    }

    bool playerJustFinished = false;
    bool isTurnEnd = false;

    setState(() {
      throwHistory.add(dartThrow);

      if (isHit) {
        final steps = widget.config.countMultiples
            ? (multiplier == 0 ? 1 : multiplier)
            : 1;

        int nextTarget = target;
        for (int s = 0; s < steps; s++) {
          nextTarget = _advanceTarget(nextTarget);
          if (_isFinished(nextTarget)) break;
        }

        currentTargets[currentPlayerIndex] = nextTarget;
        players[currentPlayerIndex].score = nextTarget;

        _log.logThrow(
          roundNumber: _roundNumber,
          playerIndex: currentPlayerIndex,
          label: dartThrow.label,
          points: points,
          scoreBefore: target,
          scoreAfter: nextTarget,
          dartNumber: dartsInTurn,
          extra: 'HIT target=$target steps=$steps',
        );

        if (_isFinished(nextTarget)) {
          finishedPlayers.add(currentPlayerIndex);
          playerJustFinished = true;

          _pendingFinishes.add(_PendingFinish(
            playerIndex: currentPlayerIndex,
            dartsUsedInTurn: dartsInTurn + 1,
            segmentsRemainingAtRoundStart: _segmentsRemaining(
              throwHistory
                  .where((t) => t.playerIndex == currentPlayerIndex && t.roundNumber == _roundNumber)
                  .first
                  .scoreBefore,
            ),
          ));

          _log.logFinish(
            roundNumber: _roundNumber,
            playerIndex: currentPlayerIndex,
            playerName: players[currentPlayerIndex].name,
            details: 'completed all targets, darts=${dartsInTurn + 1} in turn',
          );
        }

        if (steps > 1) {
          lastThrowLabel = '${dartThrow.label} +$steps steps';
        } else {
          lastThrowLabel = dartThrow.label;
        }
        _announcer.announceThrow('Hit');
        if (playerJustFinished) {
          _announcer.announceGameEvent('${players[currentPlayerIndex].name} finishes!');
        } else {
          final t = currentTargets[currentPlayerIndex];
          _announcer.announceScore('Target ${t == 25 ? 'Bull' : '$t'}');
        }
      } else {
        _log.logThrow(
          roundNumber: _roundNumber,
          playerIndex: currentPlayerIndex,
          label: segment == 0 ? 'Miss' : dartThrow.label,
          points: points,
          scoreBefore: target,
          scoreAfter: target,
          dartNumber: dartsInTurn,
          extra: 'MISS target=$target',
        );
        lastThrowLabel = segment == 0 ? 'Miss' : dartThrow.label;
        if (!(segment == 0 && _missSoundPlayed)) {
          _announcer.announceThrow(segment == 0 ? 'Miss' : dartThrow.spokenLabel);
        }
      }

      _meme.onThrow(dartThrow);
      dartsInTurn++;

      if (playerJustFinished) {
        isTurnEnd = true;
        // Suppress meme sounds if video will play
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
        _playersCompletedThisRound.add(currentPlayerIndex);

        final roundComplete = _isRoundComplete();
        if (!roundComplete) {
          // Check if any remaining player can theoretically finish in ≤ best darts
          final bestDarts = _pendingFinishes.map((f) => f.dartsUsedInTurn).reduce((a, b) => a < b ? a : b);
          if (_canAnyRemainingPlayerFinish(bestDarts)) {
            _advancePlayer();
          } else {
            // No one can match — mark all remaining as completed
            isTurnEnd = true;
            for (int i = 0; i < players.length; i++) {
              if (!_finishedBeforeRound.contains(i) && !finishedPlayers.contains(i)) {
                _playersCompletedThisRound.add(i);
              }
            }
          }
        }
      } else if (dartsInTurn >= 3) {
        isTurnEnd = true;
        // Suppress meme sounds if video will play
        if (_pendingVideoEvent != null && videoRoll) _meme.markSoundPlayed();
        _meme.onTurnEnd();
        _playersCompletedThisRound.add(currentPlayerIndex);
        _advancePlayer();
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

  void _advancePlayer() {
    final fromIndex = currentPlayerIndex;
    dartsInTurn = 0;
    _turnIdCounter++;
    final startIndex = currentPlayerIndex;
    if (_inSuddenDeath) {
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
        if (currentPlayerIndex == startIndex) break;
      } while (!_suddenDeathPlayers.contains(currentPlayerIndex));
    } else {
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
        if (currentPlayerIndex == startIndex) break;
      } while (finishedPlayers.contains(currentPlayerIndex));
    }
    _log.logAdvance(
      roundNumber: _roundNumber,
      fromIndex: fromIndex,
      toIndex: currentPlayerIndex,
      toName: players[currentPlayerIndex].name,
      toScore: currentTargets[currentPlayerIndex],
      reason: _inSuddenDeath ? 'sudden death' : null,
    );
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
  }

  bool _isRoundComplete() {
    if (_inSuddenDeath) {
      return _suddenDeathPlayers.every((i) => _playersCompletedThisRound.contains(i));
    }
    for (int i = 0; i < players.length; i++) {
      if (_finishedBeforeRound.contains(i)) continue;
      if (!_playersCompletedThisRound.contains(i)) return false;
    }
    return true;
  }

  /// Can any remaining (not yet thrown) player finish in [maxDarts] or fewer?
  /// In Around the Clock, a player needs at least as many darts as segments remaining.
  /// With countMultiples, a triple can skip 3 segments, so 1 dart = up to 3 segments.
  bool _canAnyRemainingPlayerFinish(int maxDarts) {
    final maxSegments = widget.config.countMultiples ? maxDarts * 3 : maxDarts;
    for (int i = 0; i < players.length; i++) {
      if (_finishedBeforeRound.contains(i)) continue;
      if (finishedPlayers.contains(i)) continue;
      if (_playersCompletedThisRound.contains(i)) continue;
      if (_segmentsRemaining(currentTargets[i]) <= maxSegments) return true;
    }
    return false;
  }

  Future<void> _resolveRoundEnd() async {
    if (_inSuddenDeath) {
      await _resolveSuddenDeath();
      return;
    }

    if (_pendingFinishes.isEmpty) {
      // No finishes this round — check if game should end
      final activePlayers = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .toList();
      if (activePlayers.length <= 1) {
        setState(() {
          if (activePlayers.length == 1) finishedPlayers.add(activePlayers.first);
          _gameFullyOver = true;
          winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
        });
        _updateStats().then((_) => _showPostGame());
        return;
      }
      setState(() {
        _roundNumber++;
        _playersCompletedThisRound = {};
        _finishedBeforeRound = List.from(finishedPlayers);
      });
      return;
    }

    // Sort by tiebreaker
    _pendingFinishes.sort(_finishComparator);

    // Check for ties at the top
    if (_pendingFinishes.length > 1 &&
        _finishComparator(_pendingFinishes[0], _pendingFinishes[1]) == 0) {
      final tied = <_PendingFinish>[_pendingFinishes[0]];
      for (int i = 1; i < _pendingFinishes.length; i++) {
        if (_finishComparator(_pendingFinishes[0], _pendingFinishes[i]) == 0) {
          tied.add(_pendingFinishes[i]);
        } else {
          break;
        }
      }
      _startSuddenDeath(tied.map((f) => f.playerIndex).toList());
      return;
    }

    // Reorder finishedPlayers by tiebreaker result
    final pendingIndices = _pendingFinishes.map((f) => f.playerIndex).toSet();
    finishedPlayers.removeWhere((i) => pendingIndices.contains(i));
    for (final finish in _pendingFinishes) {
      finishedPlayers.add(finish.playerIndex);
    }

    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    setState(() {
      winnerIndex = finishedPlayers.first;
      _pendingFinishes.clear();
      _roundNumber++;
      _playersCompletedThisRound = {};
      _finishedBeforeRound = List.from(finishedPlayers);

      if (activePlayers.length <= 1) {
        if (activePlayers.length == 1) finishedPlayers.add(activePlayers.first);
        _gameFullyOver = true;
      }
    });

    if (_gameFullyOver) {
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(players[winnerIndex!].name);
      _updateStats().then((_) => _showPostGame());
    } else {
      _showPostGame();
    }
  }

  void _startSuddenDeath(List<int> tiedPlayers) {
    setState(() {
      _inSuddenDeath = true;
      _suddenDeathPlayers = tiedPlayers;
      _playersCompletedThisRound = {};
      _roundNumber++;

      // In sudden death for ATC, reset targets to start — compare who advances further
      for (final pi in tiedPlayers) {
        final start = _startTarget;
        currentTargets[pi] = start;
        players[pi].score = start;
        finishedPlayers.remove(pi);
      }

      currentPlayerIndex = tiedPlayers.first;
      dartsInTurn = 0;
      _turnIdCounter++;
    });

    _announcer.announceGameEvent('Sudden death!');
  }

  Future<void> _resolveSuddenDeath() async {
    // Compare progress: who advanced furthest
    final progress = <int, int>{};
    for (final pi in _suddenDeathPlayers) {
      progress[pi] = _segmentsRemaining(currentTargets[pi]);
    }

    // Sort by fewest remaining segments (most progress)
    final sorted = _suddenDeathPlayers.toList()
      ..sort((a, b) => (progress[a] ?? 999).compareTo(progress[b] ?? 999));

    if (sorted.length > 1 && progress[sorted[0]] == progress[sorted[1]]) {
      // Still tied
      final tiedProgress = progress[sorted[0]]!;
      final stillTied = sorted.where((pi) => progress[pi] == tiedProgress).toList();
      _startSuddenDeath(stillTied);
      return;
    }

    setState(() {
      _inSuddenDeath = false;
      for (final pi in _suddenDeathPlayers) {
        // Mark as finished
        if (!finishedPlayers.contains(pi)) {
          finishedPlayers.add(pi);
        }
      }

      final sdSet = _suddenDeathPlayers.toSet();
      finishedPlayers.removeWhere((i) => sdSet.contains(i));
      for (final pi in sorted) {
        finishedPlayers.add(pi);
      }

      winnerIndex = finishedPlayers.first;
      _suddenDeathPlayers.clear();
      _pendingFinishes.clear();
      _playersCompletedThisRound = {};
      _roundNumber++;
      _finishedBeforeRound = List.from(finishedPlayers);

      final activePlayers = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .toList();
      if (activePlayers.length <= 1) {
        if (activePlayers.length == 1) finishedPlayers.add(activePlayers.first);
        _gameFullyOver = true;
      }
    });

    if (_gameFullyOver) {
      _announcer.stop();
      await VideoService.instance.showRandomFromFolder(context, 'winner');
      if (!mounted) return;
      _announcer.announceWinner(players[sorted.first].name);
      _updateStats().then((_) => _showPostGame());
    } else {
      _announcer.announceWinner(players[sorted.first].name);
      _showPostGame();
    }
  }

  int _finishComparator(_PendingFinish a, _PendingFinish b) {
    // Rule 1: Fewer darts wins
    if (a.dartsUsedInTurn != b.dartsUsedInTurn) {
      return a.dartsUsedInTurn.compareTo(b.dartsUsedInTurn);
    }
    // Rule 2: More segments remaining at round start = longer journey = wins
    if (a.segmentsRemainingAtRoundStart != b.segmentsRemainingAtRoundStart) {
      return b.segmentsRemainingAtRoundStart.compareTo(a.segmentsRemainingAtRoundStart);
    }
    // Rule 3: True tie — sudden death
    return 0;
  }

  Widget _buildHitButtons(int target) {
    final isActive = !finishedPlayers.contains(currentPlayerIndex);
    final isBull = target == 25;

    Widget hitBtn(String label, int seg, int mult) {
      final Color bg;
      if (mult == 3) bg = Colors.red[800]!;
      else if (mult == 2) bg = Colors.orange[800]!;
      else bg = Colors.blueGrey[700]!;

      return Expanded(
        child: SizedBox(
          height: 120,
          child: ElevatedButton(
            onPressed: isActive ? () => _onDartHit(seg, mult) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: Colors.white,
              disabledBackgroundColor: bg.withAlpha(60),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isBull ? 'Hit Bull' : 'Hit $target',
            style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isBull) ...[
                hitBtn('S.Bull', 25, 1),
                const SizedBox(width: 16),
                hitBtn('Bull', 25, 2),
              ] else ...[
                hitBtn('$target', target, 1),
                const SizedBox(width: 16),
                hitBtn('D$target', target, 2),
                const SizedBox(width: 16),
                hitBtn('T$target', target, 3),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: isActive ? _onMiss : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('MISS',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),
          if (throwHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: 0.6,
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
    if (throwHistory.isEmpty) return;
    _announcer.announceGameEvent('Back');

    final lastThrow = throwHistory.last;
    _log.logUndo(
      playerIndex: lastThrow.playerIndex,
      playerName: players[lastThrow.playerIndex].name,
      throwLabel: lastThrow.label,
      scoreRestored: lastThrow.scoreBefore,
      roundNumber: lastThrow.roundNumber,
    );

    setState(() {
      final last = throwHistory.removeLast();

      if (finishedPlayers.contains(last.playerIndex)) {
        finishedPlayers.remove(last.playerIndex);
        _pendingFinishes.removeWhere((f) => f.playerIndex == last.playerIndex);
        _gameFullyOver = false;
        _inSuddenDeath = false;
        _suddenDeathPlayers.clear();
      }

      winnerIndex = finishedPlayers.isNotEmpty ? finishedPlayers.first : null;
      currentPlayerIndex = last.playerIndex;
      currentTargets[currentPlayerIndex] = last.scoreBefore;
      players[currentPlayerIndex].score = last.scoreBefore;
      dartsInTurn = last.turnNumber;
      _turnIdCounter = last.turnId;
      _roundNumber = last.roundNumber;
      lastThrowLabel = null;

      _rebuildRoundState();
    });
  }

  void _rebuildRoundState() {
    _playersCompletedThisRound = {};
    _finishedBeforeRound = [];

    // Scan finished players: if their last throw was before this round, they finished earlier
    for (final pi in finishedPlayers) {
      final playerThrows = throwHistory.where((t) => t.playerIndex == pi).toList();
      if (playerThrows.isNotEmpty && playerThrows.last.roundNumber < _roundNumber) {
        _finishedBeforeRound.add(pi);
      }
    }

    // Find completed turns in current round
    final currentRoundThrows = throwHistory.where((t) => t.roundNumber == _roundNumber).toList();
    final throwsByTurn = <int, List<DartThrow>>{};
    for (final t in currentRoundThrows) {
      throwsByTurn.putIfAbsent(t.turnId, () => []).add(t);
    }

    for (final entry in throwsByTurn.entries) {
      final throws = entry.value;
      final lastThrow = throws.last;
      final isFinish = finishedPlayers.contains(lastThrow.playerIndex) &&
          !_finishedBeforeRound.contains(lastThrow.playerIndex);
      final isThirdDart = lastThrow.turnNumber == 2;

      if (isFinish || isThirdDart) {
        _playersCompletedThisRound.add(lastThrow.playerIndex);
      }
    }
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
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final idx = savedPlayers.indexWhere((sp) => sp.id == playerId);
      if (idx < 0) continue;
      final sp = savedPlayers[idx];
      sp.gamesPlayed++;
      if (finishedPlayers.isNotEmpty && finishedPlayers.first == pi) sp.gamesWon++;
    }

    // Build placements from finishedPlayers order, then rank remaining by progress
    final placements = List.generate(players.length, (i) {
      final idx = finishedPlayers.indexOf(i);
      if (idx >= 0) return idx + 1;
      return finishedPlayers.length + 1; // Unfinished players get last
    });
    // Compute per-player Clock stats
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final playerDarts = throwHistory.where((t) => t.playerIndex == pi).toList();
      int hits = 0, misses = 0;
      for (final t in playerDarts) {
        if (t.segment == 0) { misses++; }
        else if (t.segment == t.scoreBefore) { hits++; } // hit the target
        else { misses++; } // wrong segment
      }

      modeCounters[playerId] = {
        'totalDarts': playerDarts.length,
        'totalHits': hits,
        'misses': misses,
        if (finishedPlayers.contains(pi))
          'max:bestDartCount': playerDarts.length,
        'finished': finishedPlayers.contains(pi) ? 1 : 0,
        'reached': currentTargets[pi],
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
      gameMode: 'aroundTheClock',
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

  GameResult _buildGameResult() {
    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      final playerThrows = throwHistory.where((t) => t.playerIndex == i).toList();

      int placement;
      final finishIdx = finishedPlayers.indexOf(i);
      if (finishIdx >= 0) {
        placement = finishIdx + 1;
      } else {
        placement = finishedPlayers.length + 1;
      }

      results.add(PlayerResult(
        name: players[i].name,
        avatarPath: players[i].avatarPath,
        placement: placement,
        stats: {
          'reached': currentTargets[i],
          'darts': playerThrows.length,
        },
        ratingBefore: players[i].savedPlayerId != null ? _ratingsBefore[players[i].savedPlayerId!] : null,
        ratingAfter: players[i].savedPlayerId != null ? _ratingsAfter[players[i].savedPlayerId!] : null,
      ));
    }

    final activePlayers = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();

    return GameResult(
      gameMode: 'aroundTheClock',
      results: results,
      canContinue: !_gameFullyOver && activePlayers.length > 1 && players.length > 2,
    );
  }

  void _showPostGame() async {
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: finishedPlayers,
      gameFullyOver: _gameFullyOver,
    );
    BatterySampler.instance.stop();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PostGameScreen(result: _buildGameResult())),
    );
    if (!mounted) return;
    if (result == 'undo') {
      _log.logPostGame(action: 'undo');
      _undo();
    } else if (result == 'continue') {
      _log.logPostGame(action: 'continue', details: 'remaining players: ${players.length - finishedPlayers.length}');
      // Continue with remaining players
      setState(() {
        winnerIndex = null;
        _advancePlayer();
      });
    } else {
      _log.logPostGame(action: 'newGame');
      // New Game — save stats if not already saved
      if (!_gameFullyOver) {
        _gameFullyOver = true;
        await _updateStats();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = players[currentPlayerIndex];
    final currentTarget = currentTargets[currentPlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Around the Clock${_isReverse ? ' (Reverse)' : ''}${widget.config.includeBull ? ' + Bull' : ''}'),
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
                  if (!_gameFullyOver) _openPlayerManagement();
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
              PopupMenuItem(
                value: 'players',
                enabled: !_gameFullyOver,
                child: const Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 12),
                    Text('Manage players'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
          // Sudden death banner
          if (_inSuddenDeath)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.red.withAlpha(200),
              child: const Text('SUDDEN DEATH',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          // Pending finish banner
          if (_pendingFinishes.isNotEmpty && !_inSuddenDeath)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.green.withAlpha(150),
              child: Text(
                _pendingFinishes.length == 1
                    ? '${players[_pendingFinishes.first.playerIndex].name} finished! Round continues...'
                    : '${_pendingFinishes.length} players finished! Round continues...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          // Current player info
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentPlayer.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('Dart ${dartsInTurn + 1} of 3',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
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
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('Target',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                    Text(
                      _isFinished(currentTarget)
                          ? '✓'
                          : currentTarget == 25
                              ? 'Bull'
                              : '$currentTarget',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress
          ClockProgress(
            currentTarget: _isFinished(currentTarget)
                ? (_isReverse ? 0 : _maxTarget + 1)
                : currentTarget,
            includeBull: widget.config.includeBull,
            reverse: _isReverse,
          ),

          // Hit buttons for current target
          Expanded(
            child: Center(
              child: _buildHitButtons(currentTarget),
            ),
          ),

          // Last throw
          if (lastThrowLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Last: $lastThrowLabel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: lastThrowLabel!.contains('✓')
                        ? Colors.green
                        : Colors.white,
                  )),
            ),

          // Player scoreboard
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
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
                final isCurrent =
                    index == currentPlayerIndex && winnerIndex == null;
                final isWinner = index == winnerIndex;
                final target = currentTargets[index];

                final isRemoved = _removedPlayerIndices.contains(index);
                return Opacity(
                  opacity: isRemoved ? 0.4 : 1.0,
                  child: ActivePlayerHighlight(
                    isActive: isCurrent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: isWinner ? Colors.green.withAlpha(25) : null,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: _pendingFinishes.any((f) => f.playerIndex == index)
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 28)
                                : isCurrent
                                    ? Icon(Icons.arrow_right,
                                        color: Theme.of(context).colorScheme.primary, size: 28)
                                    : isWinner
                                        ? Icon(Icons.emoji_events,
                                            color: Theme.of(context).colorScheme.tertiary, size: 28)
                                        : null,
                          ),
                          const SizedBox(width: 10),
                          PlayerAvatar(
                            avatarPath: player.avatarPath,
                            name: player.name,
                            radius: 22,
                            backgroundColor: avatarColor(index),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    )),
                                if (_lastDartsLabel(index).isNotEmpty)
                                  Text(
                                    _lastDartsLabel(index),
                                    style: TextStyle(
                                        fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _isFinished(target)
                                ? 'Done!'
                                : target == 25
                                    ? 'Bull'
                                    : '$target',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isWinner ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
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

  void _openPlayerManagement() {
    showMidGamePlayerSheet(
      context: context,
      players: players,
      isRemoved: (i) => _removedPlayerIndices.contains(i),
      gameOver: _gameFullyOver,
      colorFor: avatarColor,
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  /// Compute new player's starting target from average remaining segments
  /// of active players. Standard rounding (0.5 up).
  int _computeJoinTarget() {
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    if (activeIndices.isEmpty) return _startTarget;
    final avgRemaining = activeIndices
            .map((i) => _segmentsRemaining(currentTargets[i]))
            .reduce((a, b) => a + b) /
        activeIndices.length;
    final remainingRounded = avgRemaining.round();
    // Walk forward from start by (totalSegments - remaining) steps
    int totalSegments = _segmentsRemaining(_startTarget);
    int stepsTaken = totalSegments - remainingRounded;
    if (stepsTaken < 0) stepsTaken = 0;
    int t = _startTarget;
    for (int s = 0; s < stepsTaken; s++) {
      t = _advanceTarget(t);
    }
    return t;
  }

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    final target = _computeJoinTarget();
    setState(() {
      _midGamePlayerChanges = true;
      _joinedMidGameIds.add(sp.id);
      players.add(Player(
        name: sp.name,
        score: target,
        savedPlayerId: sp.id,
        avatarPath: sp.avatarPath,
      ));
      currentTargets.add(target);
    });
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content:
            const Text('Rating will not be updated for this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final removed = players[playerIndex];
              setState(() {
                _midGamePlayerChanges = true;
                _removedPlayerIndices.add(playerIndex);
                if (removed.savedPlayerId != null) {
                  _leftMidGameIds.add(removed.savedPlayerId!);
                }
                if (!finishedPlayers.contains(playerIndex)) {
                  finishedPlayers.add(playerIndex);
                }
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

class _PendingFinish {
  final int playerIndex;
  final int dartsUsedInTurn;
  final int segmentsRemainingAtRoundStart;

  _PendingFinish({
    required this.playerIndex,
    required this.dartsUsedInTurn,
    required this.segmentsRemainingAtRoundStart,
  });
}
