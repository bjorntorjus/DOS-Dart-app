import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../models/wildcard_engine.dart';
import '../models/wildcard_events.dart';
import '../services/achievement_service.dart';
import '../services/app_settings.dart';
import '../services/battery_sampler.dart';
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
import '../widgets/dossedart/wildcard/dossedart_chaos_meter.dart';
import '../widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart';
import '../widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';
import 'post_game_screen.dart';

/// Overlay moments the WILDCARD cockpit can show, one at a time, layered on
/// top of the Stack. Only [bull] blocks undo (the pending choice must
/// resolve first) — every other kind is dismissed by a tap or by undo.
enum WcOverlayKind { announce, bull, joker, event, cut, rewind }

/// The DOSSEDART WILDCARD cockpit: assembles [WildcardEngine], the chaos
/// meter, the scorecard, the dimmed dartboard and the moment dialogs into a
/// playable screen with an overlay state machine. [_onGameEnd] logs, freezes
/// input (via `engine.gameOver`), fires the generic winner celebration
/// (video + TTS) then goes straight to the post-game screen (no winner
/// overlay/tap gate — QA round 3); undoing from the post-game screen routes
/// into the same deferred-stats protocol the other DOSSEDART cockpits use
/// (Shanghai/Gotcha parity). No Elo: WILDCARD placements never touch
/// EloService (spec §9).
class WildcardGameScreen extends StatefulWidget {
  final List<Player> players;
  final WildcardConfig config;

  const WildcardGameScreen({
    super.key,
    required this.players,
    required this.config,
  });

  @override
  State<WildcardGameScreen> createState() => _WildcardGameScreenState();
}

class _WildcardGameScreenState extends State<WildcardGameScreen> {
  late List<Player> players;
  late WildcardEngine engine;

  @visibleForTesting
  WildcardEngine get engineForTest => engine;

  @visibleForTesting
  void onDartHitForTest(int segment, int multiplier) =>
      _onDartHit(segment, multiplier);

  @visibleForTesting
  void onUndoForTest() => _onUndo();

  @visibleForTesting
  void removePlayerForTest(int playerIndex) {
    final wasCurrent = engine.currentPlayerIndex == playerIndex;
    setState(() {
      _midGamePlayerChanges = true;
      final removedId = players[playerIndex].savedPlayerId;
      if (removedId != null) _leftMidGameIds.add(removedId);
      engine.removePlayer(playerIndex);
      if (wasCurrent && !engine.gameOver) {
        // The engine re-rolls a fresh modifier for the seat inheritor —
        // announce it, mirrors Cricket's announce-on-current-removal (R5
        // b44c6b3).
        _announcedTurnId = -1;
        _maybeShowAnnounce();
      }
    });
  }

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  @visibleForTesting
  Future<void> updateStatsForTest() => _updateStats(engine.ranking());

  @visibleForTesting
  bool get midGamePlayerChangesForTest => _midGamePlayerChanges;

  @visibleForTesting
  WcOverlayKind? get overlayKindForTest => _overlay;

  @visibleForTesting
  void dismissOverlayForTest() => _dismissOverlay();

  @visibleForTesting
  void resolveBullForTest(int signedDelta) => _onBullChoice(signedDelta);

  @visibleForTesting
  Future<void> onGameEndForTest() => _onGameEnd();

  @visibleForTesting
  List<DartThrow> get throwHistoryForTest => throwHistory;

  /// Forces [_maybeShowAnnounce] to re-run — pairs with
  /// [resetAnnounceForTest] to deterministically drive the first-turn
  /// announce fix from a widget test (the engine's own first roll happens
  /// in its constructor, before any test hook can intervene).
  @visibleForTesting
  void maybeAnnounceForTest() => setState(_maybeShowAnnounce);

  /// Clears the announce bookkeeping so a subsequent [maybeAnnounceForTest]
  /// (or the post-frame path it mirrors) re-evaluates the current turn's
  /// modifier instead of hitting the "already handled" guard.
  @visibleForTesting
  void resetAnnounceForTest() => _announcedTurnId = -1;

  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final GameAnnouncer _announcer = GameAnnouncer();

  // Per-dart history feeding stats — same turnId-grouped pattern as the
  // other DOSSEDART cockpits.
  List<DartThrow> throwHistory = [];
  int _turnIdCounter = 0;

  /// The player's total at the start of the CURRENT turn — tracked
  /// separately from `engine.totals[cur]` because instant events (SCORE
  /// SWAP, ROBIN HOOD) can mutate the thrower's own total mid-turn, before
  /// their turn banks.
  late int _turnStartScore;

  /// The last turnId for which the modifier announcement was shown — guards
  /// against re-showing it on every rebuild of the same turn.
  int _announcedTurnId = -1;

  WcOverlayKind? _overlay;

  /// The dart result awaiting a joker/event dialog dismissal — carries the
  /// `turnEnded` flag needed to resume routing once the chain of dialogs
  /// (joker → instant event) is dismissed. The dialog CONTENT itself always
  /// reads live `engine.lastEventResolution`, not this.
  WildcardDartResult? _pendingResult;

  bool _midGamePlayerChanges = false;
  final Set<String> _joinedMidGameIds = {};
  final Set<String> _leftMidGameIds = {};
  final DateTime _gameStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    players = List<Player>.from(widget.players);
    engine = WildcardEngine(
      playerCount: players.length,
      rounds: widget.config.rounds,
      startingChaos: widget.config.startingChaos,
      rng: math.Random(),
    );
    _turnStartScore = engine.totals[engine.currentPlayerIndex];
    // Bug fix (2026-07-09 game log): a constructor-rolled first-turn
    // modifier (GOLDEN DART) played silently — _maybeShowAnnounce ran here
    // synchronously, before _announcer.init() below had a chance to load
    // TtsService's enabled flag, so its announceChaos() call was dropped.
    // Deferring to a post-frame callback gives that async init a head
    // start; the overlay itself is unaffected either way since _overlay is
    // read on first build regardless of when it's set pre-paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(_maybeShowAnnounce);
    });
    _log.logGameStart(
      gameMode: 'Wildcard',
      playerNames: players.map((p) => p.name).toList(),
      playerScores: List.filled(players.length, 0),
      config: {
        'rounds': widget.config.rounds,
        'startingChaos': widget.config.startingChaos,
      },
    );
    BatterySampler.instance.start('Wildcard');
    _meme.init();
    AppSettings.getSoundEffectsEnabled()
        .then((v) => SoundService.instance.setEnabled(v));
    _announcer.init();
  }

  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }

  // ─── Dart input ─────────────────────────────────────────────

  void _onDartHit(int segment, int multiplier) {
    if (engine.gameOver || _overlay != null) return;
    final playerIdx = engine.currentPlayerIndex;
    final dartNo = engine.dartsInTurn;
    final before = engine.totals[playerIdx];
    if (dartNo == 0) _turnStartScore = before;
    final windowActive = engine.window != null;

    // Captured BEFORE applyDart: a round-closing dart (the last player's 3rd
    // dart) advances engine.round as a side effect, so reading it afterward
    // would misattribute that dart to the NEXT round.
    final roundNo = engine.round;

    late WildcardDartResult result;
    setState(() => result = engine.applyDart(segment, multiplier));

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
      scoreBefore: before,
      turnNumber: dartNo,
      scoreAtStartOfTurn: _turnStartScore,
      turnId: _turnIdCounter,
      roundNumber: roundNo,
      isBust: false,
    ));

    _log.logThrow(
      roundNumber: roundNo,
      playerIndex: playerIdx,
      label: label,
      points: result.points,
      scoreBefore: before,
      scoreAfter: engine.totals[playerIdx],
      dartNumber: dartNo,
    );

    // TTS diet (QA 2026-07-09): per-dart announceThrow removed — the
    // scorecard already shows every dart's label live.
    _meme.onThrow(throwHistory.last);

    _maybeAnnounceWindowPrize(playerIdx, result.turnEnded, windowActive);

    if (result.turnEnded) _meme.onTurnEnd();

    _routeDartResult(result);
  }

  /// THE WINDOW: a simple heuristic (spec-approved) rather than a dedicated
  /// engine signal — a window turn that just banked exactly its +100 prize.
  /// Shared by both paths that can end a turn: the normal 3rd-dart bank in
  /// [_onDartHit], and a bull dart's deferred bank in [_onBullChoice].
  /// [windowWasActive] must be captured by the caller BEFORE the engine call
  /// that may have banked the turn — banking rolls a fresh modifier for the
  /// next thrower, which clears `engine.window`.
  void _maybeAnnounceWindowPrize(
      int playerIdx, bool turnEnded, bool windowWasActive) {
    if (turnEnded &&
        windowWasActive &&
        (engine.totals[playerIdx] - _turnStartScore) == 100) {
      _announcer.announceGameEvent('Window prize! 100 points');
    }
  }

  void _onMiss() {
    if (engine.gameOver || _overlay != null) return;
    SoundService.instance.play('miss/miss');
    _onDartHit(0, 0);
  }

  /// Routes a freshly-applied dart's result to the right overlay, per the
  /// state machine: bull choice blocks first; a joker (never simultaneous
  /// with a bull dart — jokers are 1-20 only) shows its reveal, chaining
  /// into the instant-event dialog when one fired; otherwise the turn's
  /// bookkeeping (next-player announce, game-over, next-thrower's modifier
  /// announcement) runs immediately.
  void _routeDartResult(WildcardDartResult result) {
    if (result.needsBullChoice) {
      setState(() => _overlay = WcOverlayKind.bull);
      return;
    }
    if (result.jokerHit != null) {
      _pendingResult = result;
      setState(() => _overlay = WcOverlayKind.joker);
      // TTS diet (QA 2026-07-09): short sting only — the joker dialog shows
      // the hidden-number detail.
      _announcer.announceChaos('Joker!');
      return;
    }
    _finishTurn(result.turnEnded);
  }

  void _onBullChoice(int signedDelta) {
    // Guards against a double-tap before the overlay-dismissing rebuild
    // lands: in release builds (asserts stripped) engine.resolveBullChoice's
    // own assert wouldn't fire, and the meter would apply twice.
    if (engine.pendingBullChoice == null) return;
    final playerIdx = engine.currentPlayerIndex;
    final windowActive = engine.window != null;
    setState(() {
      engine.resolveBullChoice(signedDelta);
      _overlay = null;
    });
    final turnEnded = engine.dartsInTurn == 0;
    _maybeAnnounceWindowPrize(playerIdx, turnEnded, windowActive);
    if (turnEnded) _meme.onTurnEnd();
    _finishTurn(turnEnded);
  }

  void _onJokerDismiss() {
    final result = _pendingResult;
    if (result == null) {
      setState(() => _overlay = null);
      return;
    }
    final event = result.instantEvent;
    if (event != null) {
      setState(() => _overlay = _overlayKindForEvent(event));
      _announceEvent(event);
      return; // _pendingResult stays set for the event dismiss below.
    }
    _pendingResult = null;
    setState(() => _overlay = null);
    _finishTurn(result.turnEnded);
  }

  void _onEventDismiss() {
    final result = _pendingResult;
    _pendingResult = null;
    setState(() => _overlay = null);
    if (result != null) _finishTurn(result.turnEnded);
  }

  void _dismissAnnounce() => setState(() => _overlay = null);

  /// Dispatches the correct dismiss handler for whichever overlay is
  /// currently showing (test hook + tap-to-dismiss are the same path).
  /// [WcOverlayKind.bull] has no entry — it resolves only via
  /// [_onBullChoice].
  void _dismissOverlay() {
    switch (_overlay) {
      case WcOverlayKind.announce:
        _dismissAnnounce();
      case WcOverlayKind.joker:
        _onJokerDismiss();
      case WcOverlayKind.event:
      case WcOverlayKind.cut:
      case WcOverlayKind.rewind:
        _onEventDismiss();
      case WcOverlayKind.bull:
      case null:
        break;
    }
  }

  WcOverlayKind _overlayKindForEvent(WcInstantEventDef event) {
    switch (event.id) {
      case 'cutEvent':
        return WcOverlayKind.cut;
      case 'rewindEvent':
        return WcOverlayKind.rewind;
      default:
        return WcOverlayKind.event;
    }
  }

  /// TTS diet (QA 2026-07-09): CUT!/REWIND get a one-word sting; every other
  /// instant event is shown on-screen only (the event dialog carries the
  /// full detail) and is not spoken at all.
  void _announceEvent(WcInstantEventDef event) {
    switch (event.id) {
      case 'cutEvent':
        _announcer.announceChaos('Cut!');
      case 'rewindEvent':
        _announcer.announceChaos('Rewind!');
      default:
        break;
    }
  }

  /// Turn-end bookkeeping shared by every routing path (normal 3rd dart,
  /// resolved bull, dismissed joker/event chain): advances the turn/round
  /// counters, ends the game, or checks whether the next thrower's modifier
  /// still needs announcing.
  void _finishTurn(bool turnEnded) {
    if (turnEnded && !engine.gameOver) {
      // TTS diet (QA 2026-07-09): announceNextPlayer removed — the
      // scorecard already shows whose turn it is.
      _turnIdCounter++;
    }
    if (engine.gameOver) {
      _onGameEnd();
      return;
    }
    setState(_maybeShowAnnounce);
  }

  /// Shows the modifier-announcement overlay once per turn, for the player
  /// about to throw. Mutates `_overlay`/`_announcedTurnId` directly —
  /// callers are responsible for wrapping this in `setState` (or, in
  /// `initState`, calling it before the first build needs no `setState` at
  /// all).
  void _maybeShowAnnounce() {
    if (engine.gameOver) return;
    if (_announcedTurnId == _turnIdCounter) return;
    // Mark this turnId as handled unconditionally (even when there's no
    // modifier to show) — undo can rewind _turnIdCounter back past a turn
    // whose modifier was already announced without rewinding
    // _announcedTurnId, and if this assignment stayed behind the `mod ==
    // null` guard, re-throwing into that same no-modifier turn would leave
    // _announcedTurnId stale, silently suppressing the NEXT thrower's
    // modifier announcement (restriction active with no warning shown).
    _announcedTurnId = _turnIdCounter;
    final mod = engine.activeModifier;
    if (mod == null) return;
    _overlay = WcOverlayKind.announce;
    // TTS diet (QA 2026-07-09): name-only sting — the overlay already
    // spells out the description and the "X only" restriction.
    _announcer.announceChaos('${mod.name}!');
  }

  String _mapEventDetail(String detail) {
    return detail.replaceAllMapped(RegExp(r'P(\d+)'), (m) {
      final idx = int.tryParse(m.group(1)!) ?? -1;
      if (idx < 0 || idx >= players.length) return m.group(0)!;
      return players[idx].name.toUpperCase();
    });
  }

  /// Core undo mechanics shared by the live [_onUndo] button and the
  /// post-game "↶ Back" action ([_showPostGame]'s `'undo'` branch): pops the
  /// engine's last undo entry, resyncs the screen-side per-turn tracking
  /// fields, clears any pending overlay/dialog state (undoing FROM the
  /// post-game screen — which shows with no overlay of its own now — must
  /// return to live play), and re-checks whether the (possibly different)
  /// current turn's modifier still needs announcing. Callers wrap this in
  /// `setState` and own their own guards (gameOver, overlay-kind) since the
  /// two call sites need different ones.
  void _applyUndo() {
    _overlay = null;
    _pendingResult = null;
    engine.undo();
    if (throwHistory.isNotEmpty) {
      final last = throwHistory.removeLast();
      _turnIdCounter = last.turnId;
      _turnStartScore = last.scoreAtStartOfTurn;
    }
    _maybeShowAnnounce();
  }

  void _onUndo() {
    if (engine.gameOver) return;
    // Bull overlay blocks undo — the pending choice must resolve first
    // (resolveBullChoice reuses the dart's own undo entry, so undoing while
    // a choice is pending would remove the dart from under the dialog).
    if (_overlay == WcOverlayKind.bull) return;
    if (!engine.canUndo) return;
    setState(_applyUndo);
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.totals[engine.currentPlayerIndex],
      roundNumber: engine.round,
    );
  }

  // ─── Game end ───────────────────────────────────────────────

  Future<void> _onGameEnd() async {
    final ranking = engine.ranking();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();
    await _fireWinnerCelebration(players[ranking.first].name);
    if (!mounted) return;
    // No winner overlay/tap gate (QA round 3) — celebration plays, then
    // straight to the post-game scoreboard.
    _showPostGame(ranking);
  }

  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }

  /// Placements from [ranking]; a placement is shared only when BOTH the
  /// total AND the [WildcardEngine.highestTurn] tiebreak match — mirrors
  /// [WildcardEngine.ranking]'s own tiebreak exactly, so two players who
  /// only look tied on total (but were actually ordered by their best turn)
  /// are NOT reported as sharing a placement.
  List<int> _buildPlacements(List<int> ranking) {
    final placements = List.filled(players.length, 0);
    for (int rank = 0; rank < ranking.length; rank++) {
      final idx = ranking[rank];
      if (rank > 0 &&
          engine.totals[idx] == engine.totals[ranking[rank - 1]] &&
          engine.highestTurn[idx] == engine.highestTurn[ranking[rank - 1]]) {
        placements[idx] = placements[ranking[rank - 1]];
      } else {
        placements[idx] = rank + 1;
      }
    }
    return placements;
  }

  Future<void> _updateStats(List<int> ranking) async {
    if (_midGamePlayerChanges) {
      // Roster changed — record only join/leave counters and write NO game
      // entry, matching the other five DOSSEDART cockpits (audit 2026-07-06,
      // F10): a full game record here would misreport removed players'
      // placement and drop join/leave counters entirely.
      await StatsRecorder.recordMidGameChanges(
        joinedIds: _joinedMidGameIds,
        leftIds: _leftMidGameIds,
      );
      return;
    }
    final savedPlayers = await PlayerStorage.loadPlayers();
    final placements = _buildPlacements(ranking);

    final modeCounters = <String, Map<String, int>>{};
    for (int pi = 0; pi < players.length; pi++) {
      if (engine.isSkipped(pi)) continue;
      final playerId = players[pi].savedPlayerId;
      if (playerId == null) continue;
      modeCounters[playerId] = {
        'jokersHit': engine.jokersHitCount[pi],
        'windowPrizes': engine.windowPrizes[pi],
        'max:chaosPeak': engine.chaosPeak,
        'pointsStolen': engine.pointsStolen[pi],
        'max:highestTurn': engine.highestTurn[pi],
        'totalDarts': throwHistory.where((t) => t.playerIndex == pi).length,
        'totalGames': 1,
      };
    }

    // NO Elo for WILDCARD (spec §9) — ratingsBefore/After are left unset so
    // every PlayerResult reports ratingBefore/After: null and the post-game
    // screen hides rating-delta rows entirely.
    final unlocks = AchievementService.instance.awardGameEnd(
      mode: GameMode.wildcard,
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      savedPlayers: savedPlayers,
      placements: placements,
      ratingsBefore: const {},
      ratingsAfter: const {},
      eventsByIndex: const {},
    );
    final earnedFeats =
        buildEarnedFeats(eventsByIndex: const {}, unlocksByIndex: unlocks);

    StatsRecorder.recordGame(
      gameMode: 'wildcard',
      playerIds: players.map((p) => p.savedPlayerId).toList(),
      playerNames: players.map((p) => p.name).toList(),
      placements: placements,
      savedPlayers: savedPlayers,
      modeCounters: modeCounters,
      gameConfig:
          '${widget.config.rounds} rounds · chaos ${widget.config.startingChaos}',
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
      throwHistory: List<DartThrow>.from(throwHistory),
      earnedFeatsByIndex: earnedFeats,
    );

    await PlayerStorage.savePlayers(savedPlayers);
  }

  void _showPostGame(List<int> ranking) {
    // Built in ORIGINAL player-index order (skipped/removed players
    // excluded), not ranking order — PostGameScreen re-sorts by `placement`
    // for display, so this is invisible there, but it keeps `results`
    // index-aligned with each DartThrow's `playerIndex` for the progression
    // chart below. A mid-game removal shifts that alignment for players
    // after the removed seat — the same accepted limitation as the other
    // DOSSEDART progression charts' documented gaps.
    final placements = _buildPlacements(ranking);
    final results = <PlayerResult>[
      for (int i = 0; i < players.length; i++)
        if (!engine.isSkipped(i))
          PlayerResult(
            name: players[i].name,
            avatarPath: players[i].avatarPath,
            placement: placements[i],
            stats: {
              'score': engine.totals[i],
              'jokersHit': engine.jokersHitCount[i],
              'windowPrizes': engine.windowPrizes[i],
              'pointsStolen': engine.pointsStolen[i],
              'highestTurn': engine.highestTurn[i],
              'darts': throwHistory.where((t) => t.playerIndex == i).length,
            },
            // No Elo — deltas are auto-hidden by PostGameScreen when both are
            // null (spec §9).
            ratingBefore: null,
            ratingAfter: null,
          ),
    ];

    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PostGameScreen(
          result: GameResult(
            gameMode: 'wildcard',
            results: results,
            // Chart lines index by seat; a changed roster misaligns them —
            // suppress instead of mislabeling.
            throwHistory: _midGamePlayerChanges ? null : List<DartThrow>.from(throwHistory),
            progressionMode: _midGamePlayerChanges ? null : 'wildcard',
          ),
        ),
      ),
    ).then((action) async {
      if (!mounted) return;
      if (action == 'undo') {
        // User wants to keep playing — undo the game-end and return to
        // live play. Same guard as _onUndo: a stack emptied by add/remove
        // player must not rewind the screen-side history the engine cannot
        // match.
        if (!engine.canUndo) return;
        setState(_applyUndo);
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

  // ─── Mid-game roster changes ────────────────────────────────

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
        primary: '${engine.totals[i]}',
      ));
    }
    showDossedartPlayerSheet(
      context,
      rows: rows,
      gameOver: engine.gameOver,
      excludeSavedIds:
          players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
      addInfoText:
          'Rating is skipped for this game once you add or remove a player.',
      onAdd: _addSavedPlayerMidGame,
      onRemove: _removePlayerMidGame,
    );
  }

  /// WILDCARD joiners always start at 0 — spec §7.2, deliberately NOT the
  /// table-average other cockpits (Shanghai/Cricket/Gotcha) use.
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
  }

  void _removePlayerMidGame(int playerIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${players[playerIndex].name}?'),
        content: const Text('Statistics will not be recorded for this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            onPressed: () {
              Navigator.pop(ctx);
              final removedId = players[playerIndex].savedPlayerId;
              final wasCurrent = engine.currentPlayerIndex == playerIndex;
              setState(() {
                _midGamePlayerChanges = true;
                if (removedId != null) _leftMidGameIds.add(removedId);
                engine.removePlayer(playerIndex);
                if (engine.gameOver) {
                  _onGameEnd();
                } else if (wasCurrent) {
                  // The engine re-rolls a fresh modifier for the seat
                  // inheritor — announce it, mirrors Cricket's
                  // announce-on-current-removal (R5 b44c6b3).
                  _announcedTurnId = -1;
                  _maybeShowAnnounce();
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

  // ─── Scorecard data builders ────────────────────────────────

  String _handleFor(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length >= 3) return cleaned.substring(0, 3);
    return cleaned.padRight(3, 'X');
  }

  List<String?> _dartLabels() {
    final labels = engine.turnDartLabels;
    final thrown = engine.dartsInTurn;
    return [for (int i = 0; i < 3; i++) i < thrown ? labels[i] : null];
  }

  WcDirective _buildDirective(int cur) {
    final window = engine.window;
    if (window != null) {
      return WcDirective(
        icon: '🎯',
        color: DossedartTokens.purple,
        head: 'LAND TOTAL ${window.lo}–${window.hi}',
        sub: 'ALL 3 DARTS MUST SCORE · INSIDE → +100 PRIZE',
      );
    }
    final mod = engine.activeModifier;
    if (mod != null) {
      return WcDirective(
        icon: mod.icon,
        color: DossedartTokens.purple,
        head: mod.name,
        sub: mod.desc,
      );
    }
    return WcDirective(
      icon: '▶',
      color: dossedartAccent(cur),
      head: 'OPEN THROW · SCORE MAX',
      sub: 'No restriction this turn — pile on points',
    );
  }

  List<WcStandingEntry> _buildStandings(int cur) {
    final ranked = engine.ranking();
    final flags = {
      for (final f in engine.lastEventResolution?.flags ?? const [])
        f.playerIndex: f
    };
    return [
      for (final idx in ranked)
        WcStandingEntry(
          name: players[idx].name,
          accent: dossedartAccent(idx),
          total: engine.totals[idx],
          isActive: idx == cur,
          flagText: flags[idx]?.flagText,
          flagGood: flags[idx]?.good ?? false,
        ),
    ];
  }

  // ─── Overlay dialogs ────────────────────────────────────────

  Widget _buildOverlay() {
    switch (_overlay!) {
      case WcOverlayKind.announce:
        return _announceDialog();
      case WcOverlayKind.bull:
        return _bullDialog();
      case WcOverlayKind.joker:
        return _jokerDialog();
      case WcOverlayKind.event:
        return _eventDialog();
      case WcOverlayKind.cut:
        return _cutDialog();
      case WcOverlayKind.rewind:
        return _rewindDialog();
    }
  }

  Widget _announceDialog() {
    final mod = engine.activeModifier!;
    final name = players[engine.currentPlayerIndex].name.toUpperCase();
    return WildcardDialog(
      accent: DossedartTokens.purple,
      icon: mod.icon,
      title: mod.name,
      titleSize: 34,
      onTap: _dismissAnnounce,
      children: [
        const SizedBox(height: 10),
        const Text(
          '▓ CHAOS STRIKES ▓',
          style: TextStyle(fontFamily: 'VT323', fontSize: 15, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Text(
          mod.desc,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'VT323', fontSize: 21, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          "$name'S TURN ONLY",
          style: const TextStyle(
              fontFamily: 'PressStart2P', fontSize: 11, color: DossedartTokens.yellow),
        ),
      ],
    );
  }

  Widget _bullDialog() {
    final magnitude = engine.pendingBullChoice ?? 1;
    return BullChoiceDialog(
      magnitude: magnitude,
      onIgnite: () => _onBullChoice(magnitude),
      onCalm: () => _onBullChoice(-magnitude),
    );
  }

  Widget _jokerDialog() {
    final n = _pendingResult?.jokerHit ?? 0;
    return WildcardDialog(
      accent: DossedartTokens.green,
      icon: '\u{1F0CF}',
      title: 'JOKER!',
      titleSize: 48,
      onTap: _onJokerDismiss,
      children: [
        const SizedBox(height: 10),
        Text(
          'HIDDEN NUMBER $n DETONATES',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'VT323', fontSize: 20, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('METER +2', DossedartTokens.cyan),
            const SizedBox(width: 10),
            _chip('INSTANT EVENT ▶', DossedartTokens.orange),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
        child: Text(
          text,
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: color),
        ),
      );

  Widget _eventDialog() {
    final res = engine.lastEventResolution;
    final event = res?.event ?? _pendingResult?.instantEvent;
    final detail = res != null ? _mapEventDetail(res.detail) : '';
    return WildcardDialog(
      accent: DossedartTokens.orange,
      icon: event?.icon ?? '⚡',
      title: event?.name ?? 'EVENT',
      titleSize: 36,
      onTap: _onEventDismiss,
      children: [
        const SizedBox(height: 12),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'VT323', fontSize: 20, color: Colors.white),
        ),
      ],
    );
  }

  Widget _cutDialog() {
    return WildcardDialog(
      accent: DossedartTokens.red,
      icon: '✂️',
      title: 'CUT!',
      titleSize: 56,
      onTap: _onEventDismiss,
      children: const [
        SizedBox(height: 12),
        Text(
          'ROUND ENDS NOW · PLAYERS YET TO THROW LOSE THEIR TURN',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'VT323', fontSize: 20, color: Colors.white),
        ),
      ],
    );
  }

  Widget _rewindDialog() {
    return WildcardDialog(
      accent: DossedartTokens.cyan,
      icon: '⟲',
      title: 'REWIND',
      titleSize: 48,
      spin: true,
      onTap: _onEventDismiss,
      children: [
        const SizedBox(height: 12),
        Text(
          'ROUND ${engine.round} SCORES WIPED · RESTART FROM FIRST PLAYER',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'VT323', fontSize: 20, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = engine.currentPlayerIndex;
    final danger = engine.chaos >= 9;
    final glowColor =
        (danger ? DossedartTokens.red : DossedartTokens.magenta).withValues(alpha: 0.23);

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
                    title: '\u{1F0CF} WILDCARD',
                    onExit: _confirmExit,
                  ),
                  DossedartChaosMeter(
                    level: engine.chaos,
                    round: engine.round,
                    rounds: engine.rounds,
                  ),
                  DossedartWildcardScorecard(
                    playerName: players[cur].name,
                    handle: _handleFor(players[cur].name),
                    accent: dossedartAccent(cur),
                    dartLabels: _dartLabels(),
                    turnPoints: engine.turnPoints,
                    gameTotal: engine.totals[cur],
                    rank: engine.ranking().indexOf(cur) + 1,
                    toLead: engine.totals[engine.ranking().first] - engine.totals[cur],
                    directive: _buildDirective(cur),
                    standings: _buildStandings(cur),
                    modifierActive: engine.activeModifier != null,
                  ),
                  Expanded(
                    // QA 2026-07-09 — 16:10 tablets are shorter than the
                    // 820x1300 design frame the width-driven Positioned+
                    // AspectRatio sizing was tuned to; on those screens the
                    // board's width-derived height overlapped the
                    // scorecard. LayoutBuilder picks whichever dimension is
                    // tighter so the board shrinks instead of overlapping.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Defend against negative dimensions in extreme layouts
                        // (split-screen, huge text scaling).
                        final side = math.max(0.0, math.min(
                            constraints.maxWidth - 28, constraints.maxHeight - 32));
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _onMiss,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: SizedBox.square(
                                  dimension: side,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: glowColor, blurRadius: 70),
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
                                      isDim: engine.dimPredicate,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
              if (danger)
                const Positioned.fill(
                  child: IgnorePointer(child: _DangerVignette()),
                ),
              if (_overlay != null) _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen danger pulse shown while `engine.chaos >= 9` — a red inset
/// glow breathing on a 1.4s full cycle (700ms per direction), matching the
/// chaos meter's own max-level pulse lifecycle: `disableAnimations`-aware,
/// disposable `AnimationController`.
class _DangerVignette extends StatefulWidget {
  const _DangerVignette();

  @override
  State<_DangerVignette> createState() => _DangerVignetteState();
}

class _DangerVignetteState extends State<_DangerVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  void _sync() {
    if (!_reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: DossedartTokens.red.withValues(alpha: 0.5 + t * 0.3), width: 3),
            boxShadow: [
              BoxShadow(
                color: DossedartTokens.red.withValues(alpha: 0.25 + t * 0.25),
                blurRadius: 40 + t * 30,
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
        );
      },
    );
  }
}
