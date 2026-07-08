import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dart_throw.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/saved_player.dart';
import '../models/wildcard_engine.dart';
import '../models/wildcard_events.dart';
import '../services/app_settings.dart';
import '../services/battery_sampler.dart';
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
import '../widgets/dossedart/wildcard/dossedart_chaos_meter.dart';
import '../widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart';
import '../widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';

/// Overlay moments the WILDCARD cockpit can show, one at a time, layered on
/// top of the Stack. Only [bull] blocks undo (the pending choice must
/// resolve first) — every other kind is dismissed by a tap or by undo.
enum WcOverlayKind { announce, bull, joker, event, cut, rewind, winner }

/// The DOSSEDART WILDCARD cockpit: assembles [WildcardEngine], the chaos
/// meter, the scorecard, the dimmed dartboard and the moment dialogs into a
/// playable screen with an overlay state machine. Game-END flow (stats,
/// post-game navigation) is Task 11 — [_onGameEnd] here only logs, freezes
/// input (via `engine.gameOver`) and shows the winner overlay; tapping it
/// does nothing yet.
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
    setState(() {
      _midGamePlayerChanges = true;
      final removedId = players[playerIndex].savedPlayerId;
      if (removedId != null) _leftMidGameIds.add(removedId);
      engine.removePlayer(playerIndex);
    });
  }

  @visibleForTesting
  void addPlayerForTest(SavedPlayer sp) => _addSavedPlayerMidGame(sp);

  @visibleForTesting
  Future<void> updateStatsForTest() => _updateStats();

  @visibleForTesting
  bool get midGamePlayerChangesForTest => _midGamePlayerChanges;

  @visibleForTesting
  WcOverlayKind? get overlayKindForTest => _overlay;

  @visibleForTesting
  void dismissOverlayForTest() => _dismissOverlay();

  @visibleForTesting
  void resolveBullForTest(int signedDelta) => _onBullChoice(signedDelta);

  final GameLogger _log = GameLogger.instance;
  final MemeService _meme = MemeService();
  final GameAnnouncer _announcer = GameAnnouncer();

  // Per-dart history feeding stats (Task 11) — same turnId-grouped pattern
  // as the other DOSSEDART cockpits.
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
    _maybeShowAnnounce();
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
      roundNumber: engine.round,
      isBust: false,
    ));

    _log.logThrow(
      roundNumber: engine.round,
      playerIndex: playerIdx,
      label: label,
      points: result.points,
      scoreBefore: before,
      scoreAfter: engine.totals[playerIdx],
      dartNumber: dartNo,
    );

    final memeTriggered = _meme.onThrow(throwHistory.last);
    if (!memeTriggered) {
      _announcer.announceThrow(segment == 0 ? 'miss' : '${segment * multiplier}');
    }

    // THE WINDOW: a simple heuristic (spec-approved) rather than a dedicated
    // engine signal — a window turn that just banked exactly its +100 prize.
    if (result.turnEnded &&
        windowActive &&
        (engine.totals[playerIdx] - _turnStartScore) == 100) {
      _announcer.announceGameEvent('Window prize! 100 points');
    }

    if (result.turnEnded) _meme.onTurnEnd();

    _routeDartResult(result);
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
      _announcer.announceChaos('Joker! Hidden number ${result.jokerHit} detonates');
      return;
    }
    _finishTurn(result.turnEnded);
  }

  void _onBullChoice(int signedDelta) {
    setState(() {
      engine.resolveBullChoice(signedDelta);
      _overlay = null;
    });
    final turnEnded = engine.dartsInTurn == 0;
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
  /// currently showing (test hook + MENU-driven dismiss are the same path).
  /// [WcOverlayKind.bull] has no entry — it resolves only via
  /// [_onBullChoice]. [WcOverlayKind.winner] has no entry either — tapping
  /// it does nothing until Task 11.
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
      case WcOverlayKind.winner:
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

  void _announceEvent(WcInstantEventDef event) {
    final detail = _mapEventDetail(engine.lastEventResolution?.detail ?? '');
    _announcer.announceChaos('${event.name}. $detail');
  }

  /// Turn-end bookkeeping shared by every routing path (normal 3rd dart,
  /// resolved bull, dismissed joker/event chain): advances the turn/round
  /// counters, ends the game, or checks whether the next thrower's modifier
  /// still needs announcing.
  void _finishTurn(bool turnEnded) {
    if (turnEnded && !engine.gameOver) {
      _turnIdCounter++;
      _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
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
    final mod = engine.activeModifier;
    if (mod == null) return;
    _announcedTurnId = _turnIdCounter;
    _overlay = WcOverlayKind.announce;
    _announcer.announceChaos(
        '${mod.name}. ${mod.desc}. ${players[engine.currentPlayerIndex].name} only.');
  }

  String _mapEventDetail(String detail) {
    return detail.replaceAllMapped(RegExp(r'P(\d+)'), (m) {
      final idx = int.tryParse(m.group(1)!) ?? -1;
      if (idx < 0 || idx >= players.length) return m.group(0)!;
      return players[idx].name.toUpperCase();
    });
  }

  void _onUndo() {
    if (engine.gameOver) return;
    // Bull overlay blocks undo — the pending choice must resolve first
    // (resolveBullChoice reuses the dart's own undo entry, so undoing while
    // a choice is pending would remove the dart from under the dialog).
    if (_overlay == WcOverlayKind.bull) return;
    if (!engine.canUndo) return;
    setState(() {
      _overlay = null;
      _pendingResult = null;
      engine.undo();
      if (throwHistory.isNotEmpty) {
        final last = throwHistory.removeLast();
        _turnIdCounter = last.turnId;
        _turnStartScore = last.scoreAtStartOfTurn;
      }
      // Re-sync: undo may have rewound past a turn boundary, so recompute
      // whether the (possibly different) current turn's modifier needs
      // announcing again.
      _maybeShowAnnounce();
    });
    _log.logUndo(
      playerIndex: engine.currentPlayerIndex,
      playerName: players[engine.currentPlayerIndex].name,
      throwLabel: 'undo',
      scoreRestored: engine.totals[engine.currentPlayerIndex],
      roundNumber: engine.round,
    );
  }

  // ─── Game end (stub — Task 11 wires stats + post-game navigation) ──

  Future<void> _onGameEnd() async {
    final ranking = engine.ranking();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();
    setState(() => _overlay = WcOverlayKind.winner);
  }

  Future<void> _updateStats() async {
    // Stub: full stats/rating recording lands with the post-game flow
    // (Task 11), mirroring the other cockpits' _updateStats.
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
              setState(() {
                _midGamePlayerChanges = true;
                if (removedId != null) _leftMidGameIds.add(removedId);
                engine.removePlayer(playerIndex);
                if (engine.gameOver) {
                  _onGameEnd();
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
      case WcOverlayKind.winner:
        return _winnerDialog();
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

  Widget _winnerDialog() {
    final ranked = engine.ranking();
    final winnerIdx = engine.winnerIndex ?? (ranked.isNotEmpty ? ranked.first : 0);
    final name = players[winnerIdx].name.toUpperCase();
    final total = engine.totals[winnerIdx];
    return WildcardDialog(
      accent: DossedartTokens.yellow,
      icon: '★ ★ ★',
      title: 'WILDCARD WINNER',
      titleSize: 44,
      children: [
        const SizedBox(height: 14),
        Text(
          '$name · $total PTS',
          style: const TextStyle(
              fontFamily: 'PressStart2P', fontSize: 19, color: Colors.white),
        ),
        const SizedBox(height: 10),
        const Text(
          'SURVIVED THE CHAOS',
          style: TextStyle(fontFamily: 'VT323', fontSize: 22, color: DossedartTokens.cyan),
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
                    trailing: 'ROUND ${engine.round}/${engine.rounds}',
                  ),
                  DossedartChaosMeter(level: engine.chaos),
                  DossedartWildcardScorecard(
                    playerName: players[cur].name,
                    handle: _handleFor(players[cur].name),
                    accent: dossedartAccent(cur),
                    round: engine.round,
                    rounds: engine.rounds,
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
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _onMiss,
                          ),
                        ),
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
