import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';
import 'game_logger.dart';

/// Plays short sound effect files from assets/sounds/.
/// Sounds are queued so they never overlap each other.
/// Falls back silently if a file doesn't exist or playback fails.
///
/// A 2026-07-15 field log showed a sound starting at 11:29:27 with NO
/// completion or error ever arriving from the native player: [_isPlaying]
/// stayed true forever, the queue grew monotonically 0→15 over 9 minutes,
/// and nothing (including the winner sound) played for the rest of the
/// game. Three defenses were added as a result:
///  1. A watchdog timer per in-flight sound — if neither completion nor
///     error arrives within [watchdogDuration], the stall is logged and the
///     queue is force-advanced. A monotonically increasing "generation"
///     token — captured per sound by the watchdog, the play() error path
///     AND the (per-sound re-armed) completion subscription — guards
///     against any of them double-advancing the queue once it has already
///     moved on. Because completion events carry no per-sound attribution,
///     the completion path is additionally gated on [_playResolved]: a
///     delayed completion from a watchdog-abandoned sound arriving while
///     the next sound is still mid-play() is detected as stale and ignored
///     instead of skipping the sound that just started.
///  2. Completion/error logging, so a future game log shows the queue
///     actually draining instead of only ever showing enqueues.
///  3. A cap (4) on the PENDING queue — mirrors [TtsService]'s cap-3 fix
///     from the 2026-07-09 WILDCARD QA round. The currently-playing sound
///     is never in the pending queue, so it's never touched by the cap.
class SoundService {
  SoundService._({AudioPlayer? player})
      : _player = player ?? AudioPlayer(playerId: 'sound_service');

  static final SoundService instance = SoundService._();

  /// Creates a standalone (non-singleton) instance wrapping [player], so
  /// tests can exercise the queue/watchdog/cap logic against a player whose
  /// method- and event-channels they control, without touching the real
  /// [instance] used by the running app.
  @visibleForTesting
  factory SoundService.forTesting(AudioPlayer player) =>
      SoundService._(player: player);

  final AudioPlayer _player;
  final Queue<String> _queue = Queue<String>();
  final Random _random = Random();
  bool _enabled = true;
  bool _isPlaying = false;

  // Cap on PENDING (not-yet-playing) sounds. The currently-playing sound has
  // already been removed from [_queue] by [_playNextQueued], so this can
  // never cancel in-flight audio — only stale backlog. Mirrors
  // TtsService._maxPendingQueue (cap 3 there; sound effects are shorter and
  // more frequent, so a slightly larger cap avoids over-trimming bursts).
  static const int _maxPendingQueue = 4;

  // How long to wait for onPlayerComplete/catchError before assuming the
  // native player has stalled and forcing the queue to advance. Production
  // default is comfortably longer than any effect in assets/sounds/.
  // Overridable for tests only.
  @visibleForTesting
  static Duration watchdogDuration = const Duration(seconds: 20);

  /// F18-style hard off-switch for tests (mirrors VideoService/ArcadeFrame/
  /// BatterySampler's `disableForTest`, wired in test/flutter_test_config.dart).
  /// Without it, the watchdog Timer introduced by the 2026-07-15 fix is a
  /// real (or FakeAsync) Timer that many existing widget/screen tests never
  /// elapse or explicitly cancel, tripping flutter_test's "no pending
  /// timers" invariant even though those tests don't care about sound at
  /// all. Checked at play()-time, before anything else.
  @visibleForTesting
  static bool disableForTest = false;

  Timer? _watchdogTimer;

  // Per-sound completion subscription, re-armed in [_playNextQueued] with
  // that sound's captured generation token — so the completion path carries
  // a captured (not live) generation, exactly like the watchdog and
  // catchError paths. Re-subscribing also drops any completion event that
  // was still queued for delivery to the PREVIOUS sound's subscription.
  StreamSubscription<void>? _completeSub;

  // True once the current sound's play() call has fully resolved (i.e. the
  // native resume returned). A genuine completion for the current sound can
  // only ever arrive after that — audio cannot finish before it has started
  // — so a completion observed while this is still false is necessarily a
  // stray from a PREVIOUS sound (e.g. one the watchdog already abandoned)
  // and must not advance the queue. This is the second half of the
  // late-completion guard: the generation token alone cannot catch this
  // case, because the completion event stream carries no per-sound
  // attribution — any event delivered while sound N+1 is current
  // necessarily arrives with N+1's (current) generation.
  bool _playResolved = false;

  // Bumped every time a new sound starts playing. The watchdog callback and
  // the completion/error handlers only act if the generation they were
  // armed/invoked for is still the current one — this prevents a late
  // completion (or the watchdog firing after a completion already advanced
  // the queue) from advancing the queue a second time.
  int _generation = 0;
  String? _currentName;

  @visibleForTesting
  List<String> get pendingQueueForTesting => List<String>.unmodifiable(_queue);

  @visibleForTesting
  bool get isPlayingForTesting => _isPlaying;

  @visibleForTesting
  void resetForTesting() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _completeSub?.cancel();
    _completeSub = null;
    _generation++; // invalidate any still-in-flight watchdog/completion
    _queue.clear();
    _isPlaying = false;
    _playResolved = false;
    _enabled = true;
    _currentName = null;
  }

  Future<void> init() async {
    _enabled = await AppSettings.getSoundEffectsEnabled();
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  /// Play [name].mp3 from assets/sounds/. Queued — will not overlap other sounds.
  Future<void> play(String name) async {
    if (disableForTest) return;
    if (!_enabled) return;
    GameLogger.instance.logSound(source: 'SoundService', event: 'play($name)', outcome: 'queued (queueLen=${_queue.length}, playing=$_isPlaying)');
    _queue.add(name);
    _enforcePendingCap();
    if (!_isPlaying) _playNextQueued();
  }

  /// Drop the OLDEST pending sound(s) once [_maxPendingQueue] is exceeded.
  /// The currently-playing sound is never in [_queue], so this never
  /// interrupts in-flight audio — only stale backlog.
  void _enforcePendingCap() {
    while (_queue.length > _maxPendingQueue) {
      final dropped = _queue.removeFirst();
      GameLogger.instance.logSound(
        source: 'SoundService',
        event: 'play($dropped)',
        outcome: 'queue cap ($_maxPendingQueue) hit — dropping oldest pending',
      );
    }
  }

  void _playNextQueued() {
    if (_queue.isEmpty) {
      _isPlaying = false;
      return;
    }
    final name = _queue.removeFirst();
    _isPlaying = true;
    _currentName = name;
    _playResolved = false;
    final generation = ++_generation;

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(watchdogDuration, () => _onWatchdogFired(generation));

    _completeSub?.cancel();
    _completeSub =
        _player.onPlayerComplete.listen((_) => _onCompletion(generation));

    _player.play(AssetSource('sounds/$name.mp3')).then((_) {
      // Only mark resolved if this sound is still the current one — the
      // watchdog may have force-advanced past it while play() was in
      // flight, in which case this resolution belongs to an abandoned
      // sound and must not unlock the NEXT sound's completion gate.
      if (generation == _generation) _playResolved = true;
    }).catchError((_) {
      _settle(generation, outcome: 'failed');
    });
  }

  void _onCompletion(int generation) {
    if (generation != _generation) return; // stale subscription — ignore
    if (!_playResolved) {
      // See [_playResolved]: a completion can't belong to the current sound
      // if the current sound's play() hasn't even resolved yet. This is a
      // delayed completion from a previous (watchdog-abandoned) sound;
      // swallowing it prevents a double-advance that would skip the sound
      // that just started. The current sound still advances normally via
      // its own completion, error, or watchdog.
      GameLogger.instance.logSound(
        source: 'SoundService',
        event: 'play($_currentName)',
        outcome: 'stale completion from a previous sound — ignored',
      );
      return;
    }
    _settle(generation, outcome: 'done');
  }

  void _onWatchdogFired(int generation) {
    if (generation != _generation) return; // stale — already advanced past this
    final seconds = watchdogDuration.inMilliseconds / 1000;
    GameLogger.instance.logSound(
      source: 'SoundService',
      event: 'play($_currentName)',
      outcome: 'watchdog: no completion in ${seconds}s — forcing queue advance',
    );
    _settle(generation, outcome: null);
  }

  /// Common exit path for a playback that just finished settling — via a
  /// real completion, a playback error, or the watchdog giving up. Only the
  /// FIRST of these to arrive for a given [generation] has any effect; the
  /// others are stale no-ops (see class doc).
  void _settle(int generation, {required String? outcome}) {
    if (generation != _generation) return;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    if (outcome != null) {
      GameLogger.instance.logSound(source: 'SoundService', event: 'play($_currentName)', outcome: outcome);
    }
    _isPlaying = false;
    _playNextQueued();
  }

  /// Like [playRandom], but only plays with a 1-in-[chance] probability.
  /// Default chance is 3 (≈33%). Useful for avoiding sound fatigue on frequent events.
  /// Returns true if the sound was selected to play, false if skipped by chance.
  bool playRandomMaybe(List<String> folders, {int chance = 3}) {
    if (_random.nextInt(chance) != 0) {
      GameLogger.instance.logSound(source: 'SoundService', event: 'playRandomMaybe($folders)', outcome: 'skipped by chance (1/$chance)');
      return false;
    }
    GameLogger.instance.logSound(source: 'SoundService', event: 'playRandomMaybe($folders)', outcome: 'playing (1/$chance hit)');
    playRandom(folders);
    return true;
  }

  /// Play a random .mp3 from one or more asset folders (paths relative to assets/sounds/).
  /// Files from all listed folders are merged into one pool before picking.
  Future<void> playRandom(List<String> folders, {String? fallback}) async {
    if (!_enabled) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final files = <String>[];
      for (final folder in folders) {
        final prefix = 'assets/sounds/$folder/';
        files.addAll(manifest
            .listAssets()
            .where((key) => key.startsWith(prefix) && key.endsWith('.mp3')));
      }
      if (files.isEmpty) {
        if (fallback != null) play(fallback);
        return;
      }
      final picked = files[_random.nextInt(files.length)];
      final name = picked
          .replaceFirst('assets/sounds/', '')
          .replaceAll(RegExp(r'\.mp3$'), '');
      play(name);
    } catch (_) {
      // Silently ignore manifest or playback errors
    }
  }
}
