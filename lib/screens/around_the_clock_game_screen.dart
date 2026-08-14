import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/saved_player.dart';
import '../widgets/active_player_highlight.dart';
import '../widgets/mid_game_player_sheet.dart';
import '../widgets/dossedart/dossedart_player_sheet.dart';
import '../models/game_mode.dart';
import '../utils/join_seed.dart';
import '../utils/earned_feats_builder.dart';
import '../services/achievement_service.dart';
import '../services/player_storage.dart';
import '../services/elo_service.dart';
import '../utils/player_colors.dart';
import '../services/app_settings.dart';
import '../services/game_announcer.dart';
import '../services/meme_service.dart';
import '../services/shot_clock.dart';
import '../services/sound_service.dart';
import '../services/stats_recorder.dart';
import '../services/game_logger.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../models/game_result.dart';
import 'post_game_screen.dart';
import '../widgets/player_avatar.dart';
import '../services/battery_sampler.dart';
import '../theme/dossedart_tokens.dart';
import '../app_version.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/dossedart_top_bar.dart';
import '../widgets/dossedart/dossedart_action_bar.dart';
import '../widgets/dossedart/dossedart_active_strip.dart';
import '../widgets/dossedart/dossedart_cockpit_menu.dart';
import '../utils/dossedart_player_accents.dart';

/// Progress arc for the DOSSEDART clock-ring centre: a faint full track with a
/// green arc covering the fraction of targets the active player has completed.
class _AtcArcPainter extends CustomPainter {
  final double fraction;
  _AtcArcPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,
        2 * pi * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = DossedartTokens.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_AtcArcPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class AroundTheClockGameScreen extends StatefulWidget {
  final List<Player> players;
  final AroundTheClockConfig config;
  final bool useDossedartDesign;

  const AroundTheClockGameScreen({
    super.key,
    required this.players,
    required this.config,
    this.useDossedartDesign = false,
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
  bool _soundEnabled = true;
  bool _memeEnabled = false;
  bool _offensiveEnabled = false;
  bool _ttsEnabled = false;
  bool _missSoundPlayed = false;
  int _turnIdCounter = 0;

  // Round tracking for same-round finish
  int _roundNumber = 0;
  Set<int> _playersCompletedThisRound = {};
  List<int> _finishedBeforeRound = [];
  final List<_PendingFinish> _pendingFinishes = [];
  List<int> _suddenDeathPlayers = [];
  bool _inSuddenDeath = false;
  bool _hadSuddenDeath = false;

  /// throwHistory length when the (first) sudden death began. Throws from
  /// that index on are tiebreak throws: they decide placement but must never
  /// feed stats — targets were reset, so SD darts would skew hit rates and
  /// finish dart-counts (audit 2026-07-06, F4).
  int? _suddenDeathThrowStart;

  /// The throws that count toward stats: everything before sudden death.
  List<DartThrow> get _statThrows => _suddenDeathThrowStart == null
      ? throwHistory
      : throwHistory.sublist(0, _suddenDeathThrowStart!);
  int _consecutiveMisses = 0;
  String? _pendingVideoEvent;

  Map<String, double> _ratingsBefore = {};
  Map<String, double> _ratingsAfter = {};

  bool _midGamePlayerChanges = false;
  final DateTime _gameStart = DateTime.now();
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final Set<int> _removedPlayerIndices = {};

  /// First player in [finishedPlayers] who has not been removed mid-game.
  /// Used for winner picking — a removed player must never be declared winner
  /// even if their index happens to appear first in [finishedPlayers].
  int? _winnerIndexExcludingRemoved() {
    for (final i in finishedPlayers) {
      if (!_removedPlayerIndices.contains(i)) return i;
    }
    return null;
  }

  @visibleForTesting
  List<int> get finishedPlayersForTest => finishedPlayers;

  @visibleForTesting
  Set<int> get removedPlayerIndicesForTest => _removedPlayerIndices;

  @visibleForTesting
  int? get winnerIndexForTest => winnerIndex;

  @visibleForTesting
  int? computeWinnerForTest() => _winnerIndexExcludingRemoved();

  @visibleForTesting
  Future<void> onDartHitForTest(int segment, int multiplier) =>
      _onDartHit(segment, multiplier);

  @visibleForTesting
  void undoForTest() => _undo();

  @visibleForTesting
  GameResult buildGameResultForTest() => _buildGameResult();

  @visibleForTesting
  void removePlayerForTest(int playerIndex) => _performRemovePlayer(playerIndex);

  @visibleForTesting
  bool isRoundCompleteForTest() => _isRoundComplete();

  @visibleForTesting
  int get roundNumberForTest => _roundNumber;

  @visibleForTesting
  int get currentPlayerIndexForTest => currentPlayerIndex;

  bool get _isReverse => widget.config.reverse;
  int get _maxTarget => widget.config.includeBull ? 25 : 20;
  int get _startTarget => _isReverse ? (_maxTarget == 25 ? 25 : 20) : 1;

  @override
  void initState() {
    super.initState();
    players = widget.players;
    final start = _startTarget;
    // growable: _addSavedPlayerMidGame appends a seat. List.filled defaults to
    // fixed-length, so every mid-game add threw "Cannot add to a fixed-length
    // list" — the path was unreachable in tests until the 2026-08-10 join-seed
    // work covered it.
    currentTargets = List.filled(players.length, start, growable: true);
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
      build: kAppVersion,
    );
    BatterySampler.instance.start('AroundTheClock');
    AppSettings.getSoundEffectsEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
    });
    AppSettings.getMemeEnabled().then((v) => setState(() => _memeEnabled = v));
    AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));
    TtsService.instance.init().then((_) {
      if (mounted) setState(() => _ttsEnabled = TtsService.instance.enabled);
    });
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

    // Video gating lives entirely in VideoService.shouldPlay (video-damping
    // 2026-07-22). The old meme-frequency pre-roll here meant the meme slider
    // silently changed how often videos played (audit 2026-08-10, F2).
    final videoRoll = VideoService.instance.shouldPlay();

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
      ShotClock.instance.registerDart();

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
      await VideoService.instance.showRandomFromFolder(context, _pendingVideoEvent!,
          alreadyDecided: true);
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
    // Gated so TURN/STANDINGS never logs a "next" turn on a path where the
    // game is already over (e.g. undo restoring onto a removed player after
    // game end). Log-only gate — gameplay flow is untouched.
    if (!_gameFullyOver) {
      // ATC has no running "score" — currentTargets holds the next target
      // number (1-20, or 25 for Bull) each player must hit, not points. The
      // numbers logged here (and in the STANDINGS line below) are targets.
      _log.logTurnStart(
        roundNumber: _roundNumber,
        playerIndex: currentPlayerIndex,
        playerName: players[currentPlayerIndex].name,
        score: currentTargets[currentPlayerIndex],
      );
      _log.logStandings(
        roundNumber: _roundNumber,
        names: players.map((p) => p.name).toList(),
        scores: currentTargets,
      );
    }
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
  }

  bool _isRoundComplete() {
    if (_inSuddenDeath) {
      return _suddenDeathPlayers.every((i) => _playersCompletedThisRound.contains(i));
    }
    for (int i = 0; i < players.length; i++) {
      if (_finishedBeforeRound.contains(i)) continue;
      // Removed mid-game (or finished this round) — they will never throw
      // again, so they can't hold the round open (audit 2026-07-06, F5).
      if (finishedPlayers.contains(i)) continue;
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
          winnerIndex = _winnerIndexExcludingRemoved();
        });
        _prepareRatingPreview().then((_) => _showPostGame());
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
      winnerIndex = _winnerIndexExcludingRemoved() ?? finishedPlayers.first;
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
      _prepareRatingPreview().then((_) => _showPostGame());
    } else {
      _showPostGame();
    }
  }

  void _startSuddenDeath(List<int> tiedPlayers) {
    setState(() {
      _inSuddenDeath = true;
      _hadSuddenDeath = true;
      _suddenDeathThrowStart ??= throwHistory.length;
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
      ..sort(withSeatTiebreak(
          (a, b) => (progress[a] ?? 999).compareTo(progress[b] ?? 999)));

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

      winnerIndex = _winnerIndexExcludingRemoved() ?? finishedPlayers.first;
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
      _prepareRatingPreview().then((_) => _showPostGame());
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
    final cs = Theme.of(context).colorScheme;
    final progressTotal = widget.config.includeBull ? 21 : 20;
    final progressDone = isBull ? progressTotal - 1 : (target - 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'NEXT TARGET',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${progressDone + 1} OF $progressTotal',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontSize: 11,
                letterSpacing: 2),
          ),
          const SizedBox(height: 18),
          // Outline-wrap with three plain labels separated by vlines
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: 100,
              child: Row(
                children: isBull
                    ? [
                        _atcHitLabel('Bull', 25, 1, isActive),
                        _atcVline(cs),
                        _atcHitLabel('DBull', 25, 2, isActive),
                      ]
                    : [
                        _atcHitLabel('$target', target, 1, isActive),
                        _atcVline(cs),
                        _atcHitLabel('D$target', target, 2, isActive),
                        _atcVline(cs),
                        _atcHitLabel('T$target', target, 3, isActive),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Bottom row: Back + Miss side-by-side
          Row(
            children: [
              if (throwHistory.isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _undo,
                      icon: const Icon(Icons.undo, size: 20),
                      label: const Text('Back',
                          style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.outline),
                        foregroundColor:
                            cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              if (throwHistory.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isActive ? _onMiss : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Miss',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _atcHitLabel(String label, int seg, int mult, bool isActive) {
    return Expanded(
      child: InkWell(
        onTap: isActive ? () => _onDartHit(seg, mult) : null,
        borderRadius: BorderRadius.circular(11),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _atcVline(ColorScheme cs) {
    return Container(
      width: 2,
      height: 60,
      color: cs.outline,
    );
  }

  void _onMiss() {
    _missSoundPlayed = _meme.tryMissSound();
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
    // Sudden death cannot be rewound: targets were reset when it started, so
    // undoing into it leaves half-rewound state (audit 2026-07-06, F4).
    if (_inSuddenDeath) return;
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

      // A removed player's membership in finishedPlayers encodes the removal,
      // not a finish — undoing their old throw must not resurrect them into
      // the rotation (audit 2026-07-06, F9).
      if (finishedPlayers.contains(last.playerIndex) &&
          !_removedPlayerIndices.contains(last.playerIndex)) {
        finishedPlayers.remove(last.playerIndex);
        _pendingFinishes.removeWhere((f) => f.playerIndex == last.playerIndex);
        _gameFullyOver = false;
        _inSuddenDeath = false;
        _suddenDeathPlayers.clear();
      }

      winnerIndex = _winnerIndexExcludingRemoved();
      currentPlayerIndex = last.playerIndex;
      currentTargets[currentPlayerIndex] = last.scoreBefore;
      players[currentPlayerIndex].score = last.scoreBefore;
      dartsInTurn = last.turnNumber;
      _turnIdCounter = last.turnId;
      _roundNumber = last.roundNumber;
      lastThrowLabel = null;

      _rebuildRoundState();

      if (_removedPlayerIndices.contains(currentPlayerIndex)) {
        _advancePlayer();
      }
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
      final sp = savedPlayers.where((s) => s.id == p.savedPlayerId).firstOrNull;
      if (sp != null) _ratingsBefore[p.savedPlayerId!] = sp.rating;
    }

    EloService.updateRatings(
      gameMode: 'aroundTheClock',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      placements: _buildPlacements(),
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

  /// Placements from finishedPlayers order; unfinished players share last.
  List<int> _buildPlacements() {
    return List.generate(players.length, (i) {
      final idx = finishedPlayers.indexOf(i);
      if (idx >= 0) return idx + 1;
      return finishedPlayers.length + 1;
    });
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
      if (_winnerIndexExcludingRemoved() == pi) sp.gamesWon++;
    }

    // Build placements from finishedPlayers order, then rank remaining by progress
    final placements = _buildPlacements();
    // Compute per-player Clock stats
    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      final playerDarts = _statThrows.where((t) => t.playerIndex == pi).toList();
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
        // Best finish = FEWEST darts, so this is a min counter. (Was max:,
        // which recorded the worst finish — audit 2026-07-06, F11. Existing
        // inflated values self-heal on the next better finish.)
        if (finishedPlayers.contains(pi))
          'min:bestDartCount': playerDarts.length,
        'finished': finishedPlayers.contains(pi) ? 1 : 0,
        'reached': currentTargets[pi],
      };
    }

    EloService.updateRatings(
      gameMode: 'aroundTheClock',
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

    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.aroundTheClock,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
    );

    StatsRecorder.recordGame(
      gameMode: 'aroundTheClock',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      ratingsBefore: _ratingsBefore,
      ratingsAfter: _ratingsAfter,
      gameConfig: 'Around the Clock',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(_statThrows),
      earnedFeatsByIndex:
          buildEarnedFeats(eventsByIndex: const {}, unlocksByIndex: unlocks),
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  GameResult _buildGameResult() {
    // Players removed mid-game must not appear on the result screen at all —
    // and never as the winner. Placement is computed from the finish order
    // with removed players filtered out, so a removed player who happened to
    // sit at the front of [finishedPlayers] can't bump the real winner.
    final rankedFinished =
        finishedPlayers.where((i) => !_removedPlayerIndices.contains(i)).toList();

    final results = <PlayerResult>[];
    for (int i = 0; i < players.length; i++) {
      if (_removedPlayerIndices.contains(i)) continue;
      final playerThrows = _statThrows.where((t) => t.playerIndex == i).toList();

      final finishIdx = rankedFinished.indexOf(i);
      final placement =
          finishIdx >= 0 ? finishIdx + 1 : rankedFinished.length + 1;

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

    return GameResult(
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      gameMode: 'aroundTheClock',
      results: results,
      canUndo: !_hadSuddenDeath,
      // Chart lines index by seat; a changed roster misaligns them —
      // suppress instead of mislabeling.
      throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(_statThrows),
      progressionMode: _midGamePlayerChanges ? null : 'aroundTheClock',
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
      // Leaving the game — record stats now. Recording is deferred to this
      // point (not done when the game ended) so a post-game Undo never
      // strands persisted stats; see _prepareRatingPreview.
      if (!_gameFullyOver) _gameFullyOver = true;
      await _updateStats();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
    return _buildClassicScaffold(context);
  }

  // ---------------------------------------------------------------------------
  // DOSSEDART arcade cockpit — hero is the clock ring 1→20 (the journey at a
  // glance). Done segments green, current target cyan, future dim; centre shows
  // the big target + a progress arc. Input cells feed the same _onDartHit.
  // ---------------------------------------------------------------------------

  /// Target sequence in play order (matches the engine's advance direction).
  List<int> _atcSequence() {
    final nums = _isReverse
        ? [for (int i = 20; i >= 1; i--) i]
        : [for (int i = 1; i <= 20; i++) i];
    if (widget.config.includeBull) {
      return _isReverse ? [25, ...nums] : [...nums, 25];
    }
    return nums;
  }

  /// 'BULL' for 25, plain number otherwise.
  String _atcTargetLabel(int target) => target == 25 ? 'BULL' : '$target';

  /// Up to the next 3 targets after the active player's current one, joined
  /// with ' › '; 'THEN —' once the sequence is exhausted.
  String _atcThenLine() {
    final seq = _atcSequence();
    final activeIdx = seq.indexOf(currentTargets[currentPlayerIndex]);
    if (activeIdx < 0) return 'THEN —';
    final upcoming = seq.sublist(
        min(activeIdx + 1, seq.length), min(activeIdx + 4, seq.length));
    if (upcoming.isEmpty) return 'THEN —';
    return 'THEN ${upcoming.map(_atcTargetLabel).join(' › ')}';
  }

  /// How many targets [playerIndex] has already cleared (matches the clock
  /// ring's doneCount).
  int _atcHitCount(int playerIndex) {
    final seq = _atcSequence();
    final idx = seq.indexOf(currentTargets[playerIndex]);
    return idx < 0 ? seq.length : idx;
  }

  int _atcTotalTargets() => _atcSequence().length;

  Widget _buildDossedartCockpit(BuildContext context) {
    final dir = _isReverse ? '20→1' : '1→20';
    final title = 'CLOCK · $dir${widget.config.includeBull ? ' · +BULL' : ''}';
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: title,
                onExit: _confirmExit,
                trailing: 'RND ${_roundNumber + 1}',
              ),
              DossedartActiveStrip(
                playerName: players[currentPlayerIndex].name,
                avatarPath: players[currentPlayerIndex].avatarPath,
                accentColor: dossedartAccent(currentPlayerIndex),
                dartsInTurn: dartsInTurn,
                modeSlot: DossedartStripSlot(
                  label: 'TARGET',
                  value: _atcTargetLabel(currentTargets[currentPlayerIndex]),
                  subLine: _atcThenLine(),
                ),
                scoreLabel: 'PROGRESS',
                scoreValue: '${_atcHitCount(currentPlayerIndex)}/${_atcTotalTargets()}',
                smallScore: true,
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: _atcClockRing(),
              )),
              _atcInputCells(),
              DossedartActionBar(
                onUndo: _undo,
                onMiss: _onMiss,
                onMenu: () => showDossedartCockpitMenu(
                  context,
                  meme: _meme,
                  onTtsChanged: (v) => setState(() => _ttsEnabled = v),
                  onPlayerOverview: _openDossedartPlayerSheet,
                  onExit: _confirmExit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _atcClockRing() {
    final seq = _atcSequence();
    final activeTarget = currentTargets[currentPlayerIndex];
    final activeIdx = seq.indexOf(activeTarget);
    final doneCount = activeIdx < 0 ? seq.length : activeIdx;
    return LayoutBuilder(
      builder: (ctx, c) {
        final size = min(c.maxWidth, c.maxHeight);
        final radius = size / 2;
        final numRadius = radius * 0.84;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size * 0.58,
                height: size * 0.58,
                child: CustomPaint(
                  painter: _AtcArcPainter(
                    fraction: seq.isEmpty ? 0 : doneCount / seq.length,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('TARGET',
                      style: TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 16,
                          color: Colors.white54,
                          letterSpacing: 3)),
                  Text(
                    activeTarget == 25 ? 'BULL' : '$activeTarget',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 60,
                      color: DossedartTokens.cyan,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '$doneCount OF ${seq.length}',
                    style: const TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 16,
                      color: DossedartTokens.green,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              for (int i = 0; i < seq.length; i++)
                _atcRingNumber(seq[i], i, seq.length, radius, numRadius,
                    activeTarget, activeIdx),
            ],
          ),
        );
      },
    );
  }

  Widget _atcRingNumber(int n, int i, int len, double radius, double numRadius,
      int activeTarget, int activeIdx) {
    final angle = -pi / 2 + 2 * pi * i / len;
    final x = radius + numRadius * cos(angle);
    final y = radius + numRadius * sin(angle);
    final isCurrent = n == activeTarget;
    final isDone = activeIdx < 0 || i < activeIdx;
    final boxSize = isCurrent ? 40.0 : 30.0;
    final col = isCurrent
        ? DossedartTokens.cyan
        : isDone
            ? DossedartTokens.green
            : DossedartTokens.phosphor.withValues(alpha: 0.4);
    return Positioned(
      left: x - boxSize / 2,
      top: y - boxSize / 2,
      child: Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isCurrent ? DossedartTokens.cyan.withValues(alpha: 0.12) : null,
          border: isCurrent
              ? Border.all(color: DossedartTokens.cyan, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          n == 25 ? 'B' : '$n',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isCurrent ? 13 : 10,
            color: col,
            height: 1.0, // tight line-box so the glyph centres in the circle
          ),
        ),
      ),
    );
  }

  Widget _atcInputCells() {
    final tgt = currentTargets[currentPlayerIndex];
    if (tgt < 1 || tgt > 25) return const SizedBox.shrink();
    const c = DossedartTokens.cyan;
    final isBull = tgt == 25;
    final countMult = widget.config.countMultiples;
    final List<(String, int)> subs = isBull
        ? const [('BULL', 1), ('D-BULL', 2)]
        : [('$tgt', 1), ('D$tgt', 2), ('T$tgt', 3)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
      child: Row(
        children: [
          for (final (label, m) in subs)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _onDartHit(tgt, m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.07),
                      border: Border.all(color: c, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 16,
                            color: c,
                          ),
                        ),
                        if (countMult) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+$m STEP${m > 1 ? 'S' : ''}',
                            style: const TextStyle(
                              fontFamily: 'VT323',
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassicScaffold(BuildContext context) {
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
                case 'sound':
                  setState(() => _soundEnabled = !_soundEnabled);
                  SoundService.instance.setEnabled(_soundEnabled);
                  AppSettings.setSoundEffectsEnabled(_soundEnabled);
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
                value: 'sound',
                child: Row(
                  children: [
                    Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
                    const SizedBox(width: 12),
                    Text(_soundEnabled ? 'Sound on' : 'Sound off'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'tts',
                child: Row(
                  children: [
                    Icon(_ttsEnabled ? Icons.mic : Icons.mic_off),
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
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text('SUDDEN DEATH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          // Pending finish banner
          if (_pendingFinishes.isNotEmpty && !_inSuddenDeath)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Theme.of(context).colorScheme.primary.withAlpha(40),
              child: Text(
                _pendingFinishes.length == 1
                    ? '${players[_pendingFinishes.first.playerIndex].name} finished! Round continues...'
                    : '${_pendingFinishes.length} players finished! Round continues...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          // Slim current-player info bar
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Text(currentPlayer.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                ...List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < dartsInTurn
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }),
                const Spacer(),
                if (lastThrowLabel != null)
                  Text('Last: $lastThrowLabel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: lastThrowLabel!.contains('✓')
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.85),
                      )),
              ],
            ),
          ),

          // Hit buttons (focal area: target embedded in button labels)
          Expanded(
            child: Center(
              child: _buildHitButtons(currentTarget),
            ),
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
                      color: isWinner ? Theme.of(context).colorScheme.primary.withAlpha(25) : null,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: _pendingFinishes.any((f) => f.playerIndex == index)
                                ? Icon(Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary, size: 28)
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
                                // Always reserve space for last-darts label so
                                // the row height doesn't jump when the first
                                // dart of a turn is registered.
                                Text(
                                  _lastDartsLabel(index).isEmpty
                                      ? ' '
                                      : _lastDartsLabel(index),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55)),
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
                              color: isWinner ? Theme.of(context).colorScheme.primary : null,
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
        primary: finishedPlayers.contains(i) ? 'DONE' : '${currentTargets[i]}',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: _gameFullyOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
          'A new player starts level with whoever is in last place. '
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
      gameOver: _gameFullyOver,
      colorFor: avatarColor,
      addInfoText:
          'A new player starts level with whoever is in last place. '
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  @visibleForTesting
  List<int> get currentTargetsForTest => currentTargets;

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  void _addSavedPlayerMidGame(SavedPlayer sp) {
    // Seeded from the LAST-PLACED active player, not the table average
    // (tester feedback 2026-08-10). More segments remaining is worse, and the
    // last-placed player's target IS the position — no conversion needed,
    // which is why the old average-remaining walk is gone.
    final activeIndices = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .toList();
    final worst = worstSeatBy(
      activeIndices,
      (a, b) => _segmentsRemaining(currentTargets[a])
          .compareTo(_segmentsRemaining(currentTargets[b])),
    );
    final target = worst == null ? _startTarget : currentTargets[worst];
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
    // currentTargets holds target numbers (1-20/25), not points.
    _log.logRoster(
      action: 'ADD',
      playerIndex: players.length - 1,
      playerName: sp.name,
      names: players.map((p) => p.name).toList(),
      scores: currentTargets,
    );
  }

  /// Production removal logic, shared by the confirm dialog and tests.
  void _performRemovePlayer(int playerIndex) {
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
      // Logged here (post-mutation, pre-advance) rather than after setState:
      // removing the current player calls _advancePlayer() below, which logs
      // its own TURN/STANDINGS pair immediately — logging ROSTER first keeps
      // the log file in causal order (removal, then the resulting advance).
      // currentTargets holds target numbers, not points.
      _log.logRoster(
        action: 'REMOVE',
        playerIndex: playerIndex,
        playerName: removed.name,
        names: players.map((p) => p.name).toList(),
        scores: currentTargets,
      );
      if (playerIndex == currentPlayerIndex) {
        dartsInTurn = 0;
        _advancePlayer();
      }
      // If only 1 (or 0) active players remain, end the game
      // (audit 2026-07-06, F7 — mirrors X01).
      final remaining = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .toList();
      if (remaining.length <= 1) {
        if (remaining.length == 1) {
          finishedPlayers.add(remaining.first);
        }
        winnerIndex = _winnerIndexExcludingRemoved();
        _gameFullyOver = true;
      }
    });
    if (_gameFullyOver) {
      _prepareRatingPreview().then((_) => _showPostGame());
    }
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content:
            const Text('Statistics will not be recorded for this game.'),
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
              _performRemovePlayer(playerIndex);
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
