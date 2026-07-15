import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/sound_service.dart';

/// 2026-07-15 field log: a sound started at 11:29:27 and NO completion or
/// error event ever arrived from the native player. [SoundService]'s only
/// advance mechanism was `_player.onPlayerComplete` / the `catchError` on
/// `_player.play(...)`, so `_isPlaying` stayed true forever, the pending
/// queue grew monotonically 0→15 over 9 minutes, and nothing (including the
/// queued winner sound, #15) ever played again for the rest of the game.
///
/// This test file exercises three fixes, all inside [SoundService]:
///  1. A watchdog timer that force-advances the queue if neither completion
///     nor error arrives in time, guarded by a generation token so a late
///     completion (or the watchdog itself) can't double-advance.
///  2. Completion/error logging (so a future field log actually shows the
///     queue draining, not just growing).
///  3. A cap of 4 on the PENDING queue (mirrors TtsService's cap-3 fix from
///     the 2026-07-09 WILDCARD QA round) — the currently-playing sound is
///     never touched, only stale backlog.
///
/// Test approach — `audioplayers` 6.6.0 (see pubspec.lock):
///   - Per-player calls (create/setSourceUrl/resume/...) all go through ONE
///     shared `MethodChannel('xyz.luan/audioplayers')`, keyed by a
///     `playerId` field in the call arguments (see
///     audioplayers_platform_interface's `MethodChannelAudioplayersPlatform`).
///   - Each player has its OWN `EventChannel('xyz.luan/audioplayers/events/
///     $playerId')`, which is where `audio.onComplete` /
///     `audio.onPrepared` events arrive (`EventChannelAudioplayersPlatform`).
///     Because a broadcast EventChannel only sends its native 'listen' call
///     once (on first subscription), and `AudioPlayer` subscribes exactly
///     once in its constructor, every test here uses a *fresh* `AudioPlayer`
///     with a *unique* `playerId` (SoundService now accepts one via
///     `AudioPlayer(playerId: ...)` in production, and exposes
///     `SoundService.forTesting(player)` so tests never touch the real
///     singleton).
///   - `AudioPlayer.play(AssetSource(...))` — the Source type SoundService
///     actually uses — additionally routes through `AudioCache`, which
///     reads the real asset via `rootBundle.load` and writes it to a temp
///     file via `path_provider` BEFORE the native `setSourceUrl` call is
///     even made. `flutter test` serves real project assets through
///     `rootBundle`, so real (existing) files under assets/sounds/ are used
///     as sound names below; `path_provider`'s `PathProviderPlatform.instance`
///     is swapped for a fake pointing at a real temp directory (its own
///     documented test seam) so this resolves without a platform channel.
///   - There's also a process-wide `GlobalAudioScope` (`AudioPlayer.global`,
///     lazily created by the first-ever `AudioPlayer`) with its own method/
///     event channels (`xyz.luan/audioplayers.global` +
///     `.../global/events`) — mocked once in `setUpAll`, before any player
///     exists.
///   - `AudioPlayer.play()` also awaits an `audio.onPrepared` event before
///     resolving (`_completePrepared`), timing out after 30s otherwise. The
///     mocked method channel fires `audio.onPrepared` right after
///     `setSourceUrl` so `play()` settles quickly instead of hanging.
///
/// Timing note: these tests use REAL `Timer`s (not `fake_async`) because the
/// asset-load pipeline above involves genuine file I/O that fake_async
/// cannot fast-forward. State is awaited by *polling* with a generous
/// timeout rather than a fixed `pumpEventQueue()`/delay count, since actual
/// wall-clock overhead per event-loop turn varies by host (observed to be
/// too slow, on this Windows host, for a fixed low pump count to reliably
/// settle a real asset-load + platform round-trip within a short watchdog
/// window). Only the two tests that exercise the watchdog itself override
/// [SoundService.watchdogDuration] to a short value, and they do so with
/// margins wide enough to absorb that jitter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioMethodChannel = MethodChannel('xyz.luan/audioplayers');
  const globalMethodChannel = MethodChannel('xyz.luan/audioplayers.global');
  const globalEventChannel = EventChannel('xyz.luan/audioplayers.global/events');

  late Directory tempDir;
  var playerCounter = 0;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sound_service_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    // The global audio scope is a process-wide singleton lazily created by
    // the first-ever AudioPlayer. Its channels must be mocked before any
    // player is constructed, since its one-shot event-channel 'listen' call
    // would otherwise race an unmocked channel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalMethodChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      globalEventChannel,
      MockStreamHandler.inline(onListen: (args, events) {}),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // This file tests play()/the watchdog directly, so — like
    // battery_sampler_test.dart does for BatterySampler — it must opt out
    // of the F18 global test-config flag (test/flutter_test_config.dart),
    // which disables SoundService.play() everywhere else to prevent its
    // watchdog Timer from tripping "no pending timers" in unrelated tests.
    SoundService.disableForTest = false;
  });

  tearDown(() {
    // Restore the production default so no test can leak a short watchdog
    // into another test file run in the same process.
    SoundService.watchdogDuration = const Duration(seconds: 20);
    SoundService.disableForTest = true;
  });

  /// Polls [condition] until it's true, up to [timeout]. Used instead of a
  /// fixed `pumpEventQueue()`/delay count because the real asset-load +
  /// mocked-platform round trip's wall-clock cost isn't constant.
  Future<void> waitUntil(bool Function() condition,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final stopwatch = Stopwatch()..start();
    while (!condition()) {
      if (stopwatch.elapsed > timeout) {
        fail('waitUntil timed out after $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Extracts the logical sound name (e.g. 'win/win') back out of the
  /// cached temp-file path `setSourceUrl` is called with. AudioCache writes
  /// to `<tempDir>/<cacheId>/sounds/<name>.mp3`, always joined with '/'
  /// regardless of host OS.
  String soundNameFromUrl(String url) {
    final normalized = url.replaceAll('\\', '/');
    final match = RegExp(r'sounds/(.+)\.mp3$').firstMatch(normalized);
    return match?.group(1) ?? url;
  }

  /// Builds a fresh SoundService + AudioPlayer pair with fully mocked
  /// method/event channels, and returns the recorded native calls plus a
  /// way to reach the captured event sink (for injecting onComplete, etc).
  ({SoundService service, List<String> nativeCalls, MockStreamHandlerEventSink? Function() sink})
      setUpPlayer() {
    final playerId = 'sound-test-${playerCounter++}';
    final nativeCalls = <String>[];
    MockStreamHandlerEventSink? sink;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      EventChannel('xyz.luan/audioplayers/events/$playerId'),
      MockStreamHandler.inline(onListen: (args, events) => sink = events),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioMethodChannel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      if (args['playerId'] != playerId) return null;
      switch (call.method) {
        case 'setSourceUrl':
          final url = args['url'] as String;
          nativeCalls.add('setSourceUrl:${soundNameFromUrl(url)}');
          // Real native side reports "prepared" once the source is set;
          // AudioPlayer.play() awaits this event (with a 30s timeout)
          // before resolving.
          scheduleMicrotask(() {
            sink?.success({'event': 'audio.onPrepared', 'value': true});
          });
          return null;
        case 'resume':
          nativeCalls.add('resume');
          return null;
        case 'getCurrentPosition':
        case 'getDuration':
          return 0;
        default:
          return null;
      }
    });
    // Deliberately NOT un-registering these handlers in an addTearDown: each
    // test uses a unique playerId, and the shared audioMethodChannel handler
    // above already no-ops (returns null) for any playerId that isn't its
    // own. A stray call from a PREVIOUS test's player (e.g. its position
    // updater polling getCurrentPosition on a leftover frame callback, well
    // after that test finished) is harmless as long as *some* handler is
    // installed — nulling it out here would instead turn that stray call
    // into a MissingPluginException blamed on whichever later test happens
    // to be running when it fires.

    final player = AudioPlayer(playerId: playerId);
    final service = SoundService.forTesting(player);
    return (service: service, nativeCalls: nativeCalls, sink: () => sink);
  }

  test('stall: no completion ever arrives, watchdog forces queue advance',
      () async {
    SoundService.watchdogDuration = const Duration(milliseconds: 300);
    final h = setUpPlayer();
    await h.service.init();

    h.service.play('win/win');
    h.service.play('triple/triple');

    // Let the first sound's play() pipeline (asset load + setSourceUrl +
    // resume) actually settle — comfortably inside the 300ms watchdog
    // window.
    await waitUntil(() => h.nativeCalls.where((c) => c == 'resume').length == 1);
    expect(h.service.pendingQueueForTesting, ['triple/triple']);

    // No audio.onComplete is ever sent — simulate a genuinely stuck native
    // player, exactly like the 2026-07-15 field log. The watchdog must
    // force the queue to advance to sound #2.
    await waitUntil(() => h.nativeCalls.where((c) => c == 'resume').length == 2);
    expect(h.service.pendingQueueForTesting, isEmpty);
  });

  test(
      'normal completion advances and disarms its own watchdog (no double-advance)',
      () async {
    const watchdog = Duration(milliseconds: 300);
    SoundService.watchdogDuration = watchdog;
    final h = setUpPlayer();
    await h.service.init();

    final sinceSound1Started = Stopwatch()..start();
    h.service.play('win/win');
    h.service.play('triple/triple');
    h.service.play('miss/bruhhh');
    await waitUntil(() => h.nativeCalls.where((c) => c == 'resume').length == 1);

    // Wait a fixed, deliberate gap (well inside sound #1's 300ms watchdog
    // window) before completing it for real. This pins down roughly *when*
    // sound #2 starts relative to sound #1, so the deadline math below has
    // a known, comfortable margin regardless of how fast the mocked
    // asset-load/platform round trip happens to run on this host.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    h.sink()!.success({'event': 'audio.onComplete'});
    await waitUntil(() => h.nativeCalls.where((c) => c == 'resume').length == 2);
    expect(h.service.pendingQueueForTesting, ['miss/bruhhh']);

    // Wait until just PAST sound #1's ORIGINAL watchdog deadline (armed
    // when sound #1 started, at sinceSound1Started + 300ms), but well
    // BEFORE sound #2's own fresh watchdog deadline (armed only once sound
    // #2 actually started, ~100ms after sound #1 — so its deadline is
    // ~sinceSound1Started + 400ms). If sound #1's watchdog wasn't
    // cancelled/guarded by the generation token, it would fire here and
    // force an illegitimate second advance straight to #3.
    final remaining = watchdog - sinceSound1Started.elapsed + const Duration(milliseconds: 30);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    expect(h.nativeCalls.where((c) => c == 'resume').length, 2,
        reason: "sound #1's stale watchdog must not fire a second advance");
    expect(h.service.pendingQueueForTesting, ['miss/bruhhh']);

    // Drain the rest so no timers are left pending when the test ends.
    h.sink()!.success({'event': 'audio.onComplete'});
    await waitUntil(() => h.nativeCalls.where((c) => c == 'resume').length == 3);
    h.sink()!.success({'event': 'audio.onComplete'});
    await waitUntil(() => h.service.pendingQueueForTesting.isEmpty);
  });

  test(
      'pending queue is capped at 4 (newest kept, oldest dropped), drains in order',
      () async {
    final h = setUpPlayer();
    await h.service.init();

    const names = [
      'win/win', // starts playing immediately
      'triple/triple', // dropped (oldest pending)
      'triple/dj-khaled-another-one', // dropped (oldest pending)
      'miss/bruhhh',
      'miss/faaah',
      'miss/fail-sound-effect',
      'killer/hit/mgs-alert',
    ];
    for (final n in names) {
      h.service.play(n);
    }

    expect(h.service.pendingQueueForTesting, names.sublist(3),
        reason: 'oldest pending (indices 1,2) dropped; newest 4 kept in order');

    await waitUntil(() => h.nativeCalls.contains('setSourceUrl:${names[0]}'));
    expect(h.nativeCalls.where((c) => c.startsWith('setSourceUrl:')),
        ['setSourceUrl:${names[0]}']);

    // Drain: each completion should start the next pending sound, in order.
    for (var i = 0; i < 4; i++) {
      h.sink()!.success({'event': 'audio.onComplete'});
      await waitUntil(() => h.nativeCalls
          .where((c) => c.startsWith('setSourceUrl:'))
          .length == i + 2);
    }

    expect(h.service.pendingQueueForTesting, isEmpty);
    expect(
      h.nativeCalls.where((c) => c.startsWith('setSourceUrl:')).toList(),
      [
        'setSourceUrl:${names[0]}',
        for (final n in names.sublist(3)) 'setSourceUrl:$n',
      ],
    );
  });

  test('queue below the cap is unaffected (no drops under normal load)',
      () async {
    final h = setUpPlayer();
    await h.service.init();

    h.service.play('win/win');
    h.service.play('triple/triple');
    h.service.play('miss/bruhhh');

    expect(h.service.pendingQueueForTesting, ['triple/triple', 'miss/bruhhh']);

    // Let sound #1's play() pipeline settle before the test ends — otherwise
    // its still-in-flight asset-load microtasks can try to push an event
    // into this test's mocked stream after flutter_test has already closed
    // it during teardown.
    await waitUntil(() => h.nativeCalls.contains('resume'));
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}
