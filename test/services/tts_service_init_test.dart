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
}
