import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/tts_service.dart';

/// Regression: in v1.6.0 Shanghai shipped with the new AppBar TTS toggle but
/// never initialized [TtsService]. Toggling TTS on flipped `_enabled = true`
/// without ever registering completion / cancel / error handlers, so the very
/// first speak played but `_speaking` stayed stuck on true (no completion
/// callback) and the queue grew forever.
///
/// The invariant we now lock in: after [setEnabled] returns, the service is
/// initialized — handlers are registered — regardless of whether anyone called
/// [init] beforehand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub the flutter_tts platform channel so calls in init() succeed.
  const ttsChannel = MethodChannel('flutter_tts');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      // Most calls (setLanguage, setSpeechRate, setVolume, setPitch, speak,
      // stop) just return 1 / null in the real plugin — null is safe here.
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TtsService.instance.resetForTesting();
  });

  test('setEnabled(true) initializes the service when not yet initialized', () async {
    final svc = TtsService.instance;
    expect(svc.isInitialized, isFalse,
        reason: 'precondition: starts uninitialized after reset');

    await svc.setEnabled(true);

    expect(svc.isInitialized, isTrue,
        reason: 'setEnabled must trigger init so completion / cancel / error '
            'handlers get registered. Otherwise the first speak() will hang '
            'with _speaking=true forever and the queue grows unbounded.');
    expect(svc.enabled, isTrue);
  });

  test('setEnabled(false) also initializes (handlers must be wired even when off)', () async {
    final svc = TtsService.instance;
    expect(svc.isInitialized, isFalse);

    await svc.setEnabled(false);

    expect(svc.isInitialized, isTrue);
    expect(svc.enabled, isFalse);
  });

  test('init is idempotent — second setEnabled does not re-init', () async {
    final svc = TtsService.instance;
    await svc.setEnabled(true);
    expect(svc.isInitialized, isTrue);

    // Second call should be a cheap no-op for init; just toggles enabled.
    await svc.setEnabled(false);
    expect(svc.isInitialized, isTrue);
    expect(svc.enabled, isFalse);
  });

  // F16b (audit 2026-07-06 round 4): every game screen calls GameAnnouncer's
  // init() (which awaits TtsService.init() internally) AND, separately, its
  // own race-free `TtsService.instance.init().then(...)` read in the same
  // initState. Both calls land while the very first one is still awaiting
  // AppSettings.getTtsEnabled(). The old guard (`if (_initialized) return;`
  // set synchronously) let the second, concurrent caller's Future resolve
  // before `_enabled` was actually populated, so the screen's `.then()`
  // callback captured the stale pre-init value instead of the real one.
  test('concurrent init() callers all observe the loaded value, not a stale one',
      () async {
    SharedPreferences.setMockInitialValues({'tts_enabled': true});
    final svc = TtsService.instance;

    bool? observedByFirst;
    bool? observedBySecond;
    // Mirrors a screen's initState: GameAnnouncer.init() awaiting
    // TtsService.init() internally, immediately followed by a second,
    // independent init() call from the screen's own TTS-enabled read.
    svc.init().then((_) => observedByFirst = svc.enabled);
    svc.init().then((_) => observedBySecond = svc.enabled);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(observedByFirst, isTrue);
    expect(observedBySecond, isTrue,
        reason: 'a second concurrent init() caller must await the same '
            'in-flight initialization, not resolve early with a stale value');
  });
}
