import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'game_announcer.dart';
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

  final Map<String, int> _slowTurns = {};
  final Stopwatch _watch = Stopwatch();
  Timer? _nudge;
  Timer? _sting;
  String? _currentPlayer;

  /// True until the first turn of a game has started. People are finding darts
  /// and agreeing who goes first — nagging then is unfair, and counting it
  /// would pollute every single game with setup time.
  bool _isFirstTurn = true;

  Map<String, int> get slowTurnsByName => Map.unmodifiable(_slowTurns);

  int slowTurnsFor(String playerName) => _slowTurns[playerName] ?? 0;

  Duration get _elapsed => elapsedOverride?.call() ?? _watch.elapsed;

  /// A new turn began.
  ///
  /// Any turn still open is closed UNMEASURED: a turn counts only when a dart
  /// explicitly ends it. That makes the failure direction safe — a mode whose
  /// dart hook was missed records nothing at all, rather than flagging every
  /// turn in that mode as slow.
  void startTurn(String playerName) {
    _cancelTimers();
    final wasFirst = _isFirstTurn;
    _isFirstTurn = false;
    if (wasFirst) {
      _currentPlayer = null;
      return;
    }
    _currentPlayer = playerName;
    _watch
      ..reset()
      ..start();
    _scheduleNudges(playerName);
  }

  /// The current player threw. Only the first dart of a turn measures it —
  /// three darts in one turn is still one slow turn.
  void registerDart() {
    final player = _currentPlayer;
    if (player == null) return;
    if (_elapsed.inSeconds > kSlowTurnSeconds) {
      _slowTurns[player] = (_slowTurns[player] ?? 0) + 1;
    }
    stop();
  }

  /// Ends the turn without measuring it — game end, undo, dispose.
  void stop() {
    _cancelTimers();
    _watch.stop();
    _currentPlayer = null;
  }

  /// A new game: clears the tally and restores the first-turn grace.
  void resetGame() {
    stop();
    _slowTurns.clear();
    _isFirstTurn = true;
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
      if (!enabled || _currentPlayer != playerName) return;
      AppSettings.getShotClockSeconds().then((seconds) {
        if (_currentPlayer != playerName) return;
        _nudge = Timer(Duration(seconds: seconds), () {
          if (_currentPlayer != playerName) return;
          // NOT announceNextPlayer: that is the hook which STARTS this clock,
          // so calling it here would restart the turn forever.
          GameAnnouncer().announceShotClock(playerName);
        });
        _sting = Timer(Duration(seconds: seconds + 30), () {
          if (_currentPlayer != playerName) return;
          // An empty assets/sounds/slow/ folder degrades to silence, so the
          // feature ships working before anybody records a sound.
          SoundService.instance.playRandom(['slow']);
        });
      });
    });
  }
}
