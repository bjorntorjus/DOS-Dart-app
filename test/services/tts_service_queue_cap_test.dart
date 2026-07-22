import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/tts_service.dart';

/// Round-3 WILDCARD QA (2026-07-09): a live game log showed the TTS pending
/// queue growing to 73 entries under rapid scoring — spoken announcements
/// ended up minutes behind the actual game. [TtsService.speak] now caps the
/// PENDING queue at 3, dropping the oldest backlog entry (never the
/// currently-speaking utterance) so audio stays close to real time.
///
/// Test approach: `flutter_tts`'s completion/cancel/error handlers are wired
/// via `MethodChannel('flutter_tts').setMethodCallHandler`, i.e. calls
/// FROM the platform side INTO Dart — the opposite direction from the mock
/// handler in tts_service_init_test.dart (which stubs Dart→platform calls).
/// To simulate the native "speak finished" event we hand-encode a
/// `MethodCall('speak.onComplete')` with the standard method codec and feed
/// it straight into `TestDefaultBinaryMessengerBinding` via
/// `handlePlatformMessage`, exactly as the plugin's own native side would.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const codec = StandardMethodCodec();
  final List<String> nativeSpeakCalls = [];

  Future<void> simulateNativeSpeakComplete() async {
    final data = codec.encodeMethodCall(const MethodCall('speak.onComplete'));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(ttsChannel.name, data, (ByteData? _) {});
  }

  setUp(() {
    nativeSpeakCalls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') {
        // flutter_tts sends {"text": ..., "focus": ...} on Android, or the
        // bare String on other platforms (which is what `flutter test`
        // exercises here, since it runs as a desktop/host process).
        final args = call.arguments;
        nativeSpeakCalls.add(args is Map ? args['text'] as String : args as String);
      }
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

  test(
      'enqueueing 6 while the first speaks keeps only the newest 3 pending, in order',
      () async {
    final svc = TtsService.instance;
    await svc.setEnabled(true);

    // u1 starts speaking immediately (queue was empty); u2..u6 pile up
    // behind it. speak() has no internal await before the cap check, so
    // these run synchronously in call order.
    svc.speak('u1');
    svc.speak('u2');
    svc.speak('u3');
    svc.speak('u4');
    svc.speak('u5');
    svc.speak('u6');

    expect(svc.pendingQueueForTesting, ['u4', 'u5', 'u6'],
        reason: 'oldest pending (u2, u3) must be dropped; newest 3 kept in order');

    // The active utterance (u1) must be untouched — only one native speak()
    // call so far, for u1.
    expect(nativeSpeakCalls, ['u1']);
  });

  test('callWhenIdle still fires once the capped queue fully drains', () async {
    final svc = TtsService.instance;
    await svc.setEnabled(true);

    svc.speak('u1');
    svc.speak('u2');
    svc.speak('u3');
    svc.speak('u4');
    svc.speak('u5');
    svc.speak('u6');
    expect(svc.pendingQueueForTesting, ['u4', 'u5', 'u6']);

    var idleFired = false;
    svc.callWhenIdle(() => idleFired = true);
    expect(idleFired, isFalse, reason: 'still speaking u1, queue non-empty');

    // Drain: u1 completes → u4 starts; u4 completes → u5 starts; u5
    // completes → u6 starts; u6 completes → queue empty, idle fires.
    await simulateNativeSpeakComplete();
    expect(svc.pendingQueueForTesting, ['u5', 'u6']);
    expect(idleFired, isFalse);

    await simulateNativeSpeakComplete();
    expect(svc.pendingQueueForTesting, ['u6']);
    expect(idleFired, isFalse);

    await simulateNativeSpeakComplete();
    expect(svc.pendingQueueForTesting, isEmpty);
    expect(idleFired, isFalse, reason: 'u6 is now the active utterance');

    await simulateNativeSpeakComplete();
    expect(idleFired, isTrue,
        reason: 'queue drained and nothing left speaking — idle callback must fire');

    expect(nativeSpeakCalls, ['u1', 'u4', 'u5', 'u6'],
        reason: 'u2 and u3 were dropped from the pending queue and never spoken');
  });

  test('queue below the cap is unaffected (no drops under normal load)',
      () async {
    final svc = TtsService.instance;
    await svc.setEnabled(true);

    svc.speak('u1');
    svc.speak('u2');
    svc.speak('u3');

    expect(svc.pendingQueueForTesting, ['u2', 'u3']);
    expect(nativeSpeakCalls, ['u1']);
  });
}
