import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'game_announcer.dart';
import 'game_logger.dart';
import 'sound_service.dart';

/// The bar a turn must cross to be COUNTED as slow.
///
/// Fixed on purpose. The Settings value moves only when the *nudge* sounds, so
/// two players' counts always mean the same thing — a stat whose threshold
/// varied per device would be worthless the moment anyone wanted to look good.
const int kSlowTurnSeconds = 60;

/// Measures the gap between a turn starting and that player's first dart,
/// nudges when it runs long, and tallies how often it happens.
///
/// See `docs/superpowers/specs/2026-08-12-shot-clock-design.md`.
class ShotClock {
  ShotClock._();
  static final ShotClock instance = ShotClock._();

  /// Prevents a real Timer from outliving a widget test — the same guard
  /// BatterySampler, SoundService and VideoService carry.
  @visibleForTesting
  static bool disableForTest = false;

  /// Elapsed since the current turn began. Overridable so tests can place a
  /// dart at 59 s or 61 s without waiting a minute.
  @visibleForTesting
  static Duration Function()? elapsedOverride;

  final GameLogger _log = GameLogger.instance;
  final Map<String, int> _slowTurns = {};
  final Stopwatch _watch = Stopwatch();
  Timer? _nudge;
  Timer? _sting;
  String? _currentPlayer;

  Map<String, int> get slowTurnsByName => Map.unmodifiable(_slowTurns);

  int slowTurnsFor(String playerName) => _slowTurns[playerName] ?? 0;

  Duration get _elapsed => elapsedOverride?.call() ?? _watch.elapsed;

  /// A new turn began.
  ///
  /// Any turn still open is closed UNMEASURED: a turn counts only when a dart
  /// explicitly ends it. That makes the failure direction safe — a mode whose
  /// dart hook was missed records nothing at all, rather than flagging every
  /// turn in that mode as slow.
  ///
  /// **There is no first-turn grace, and there must not be one.** An earlier
  /// version skipped the first call of each game, meaning to spare the opening
  /// turn while people find their darts. That was wrong: no mode announces a
  /// player at game start — every `announceNextPlayer` call site sits in an
  /// advance/turn-end method — so the opening turn never reaches this class at
  /// all, and the first call it sees is the SECOND player's first real turn.
  /// The grace silently swallowed exactly the turn the feature exists to
  /// measure (found in a live log, 2026-08-12).
  void startTurn(String playerName) {
    _cancelTimers();
    _currentPlayer = playerName;
    _watch
      ..reset()
      ..start();
    _log.log('SHOTCLOCK start $playerName');
    _scheduleNudges(playerName);
  }

  /// The current player threw. Only the first dart of a turn measures it —
  /// three darts in one turn is still one slow turn.
  void registerDart() {
    final player = _currentPlayer;
    if (player == null) return;
    final seconds = _elapsed.inSeconds;
    if (seconds > kSlowTurnSeconds) {
      _slowTurns[player] = (_slowTurns[player] ?? 0) + 1;
      _log.log('SHOTCLOCK slow $player ${seconds}s '
          '(total=${_slowTurns[player]})');
    } else {
      _log.log('SHOTCLOCK dart $player ${seconds}s');
    }
    stop();
  }

  /// Ends the turn without measuring it — game end, undo, dispose.
  void stop() {
    _cancelTimers();
    _watch.stop();
    _currentPlayer = null;
  }

  /// A new game: clears the tally.
  void resetGame() {
    stop();
    _slowTurns.clear();
  }

  void _cancelTimers() {
    _nudge?.cancel();
    _nudge = null;
    _sting?.cancel();
    _sting = null;
  }

  /// Name first, joke second: a voice saying your name reads as a reminder,
  /// while leading with a comedy sound reads as mockery.
  ///
  /// Every callback re-checks [_currentPlayer] because the settings reads are
  /// async — the turn can have moved on before they resolve.
  void _scheduleNudges(String playerName) {
    if (disableForTest) return;
    AppSettings.getShotClockEnabled().then((enabled) {
      if (!enabled) {
        _log.log('SHOTCLOCK nudge off (counter still runs)');
        return;
      }
      if (_currentPlayer != playerName) return;
      AppSettings.getShotClockSeconds().then((seconds) {
        if (_currentPlayer != playerName) return;
        _log.log('SHOTCLOCK armed $playerName ${seconds}s');
        _nudge = Timer(Duration(seconds: seconds), () {
          if (_currentPlayer != playerName) return;
          _log.log('SHOTCLOCK nudge $playerName');
          // NOT announceNextPlayer: that is the hook which STARTS this clock,
          // so calling it here would restart the turn forever.
          GameAnnouncer().announceShotClock(playerName);
        });
        _sting = Timer(Duration(seconds: seconds + 30), () {
          if (_currentPlayer != playerName) return;
          _log.log('SHOTCLOCK sting $playerName');
          // An empty assets/sounds/slow/ folder degrades to silence, so the
          // feature ships working before anybody records a sound.
          SoundService.instance.playRandom(['slow']);
        });
      });
    });
  }
}
