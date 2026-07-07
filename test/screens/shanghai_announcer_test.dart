import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F16 (audit 2026-07-06): Shanghai bypassed GameAnnouncer — no next-player
/// announcement and per-category TTS settings had no effect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') {
        spoken.add(call.arguments as String);
        // TtsService's internal queue only advances to the next speak()
        // once flutter_tts's real "speak.onComplete" callback fires. There
        // is no real platform in a widget test, so simulate it — otherwise
        // only the very first queued announcement would ever reach this
        // mock and every later one (like the next-player announcement
        // tested below) would sit stuck in the queue forever.
        scheduleMicrotask(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
            'flutter_tts',
            const StandardMethodCodec()
                .encodeMethodCall(const MethodCall('speak.onComplete')),
            (data) {},
          );
        });
      }
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
      if (call.method == 'getBatteryLevel') return 100;
      if (call.method == 'getBatteryState') return 'full';
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    TtsService.instance.resetForTesting();
  });

  Future<dynamic> pumpShanghai(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [Player(name: 'P1', score: 0), Player(name: 'P2', score: 0)],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return tester.state<State<ShanghaiGameScreen>>(
        find.byType(ShanghaiGameScreen));
  }

  testWidgets('turn end announces the next player', (tester) async {
    SharedPreferences.setMockInitialValues({'tts_enabled': true});
    final dynamic s = await pumpShanghai(tester);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss); // 3rd dart ends P1's turn
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('P2'),
        reason: 'Shanghai must announce the next player like every other mode');
  });

  testWidgets('next-player category off silences the announcement',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tts_enabled': true, 'tts_announce_next_player': false});
    final dynamic s = await pumpShanghai(tester);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, isNot(contains('P2')));
  });
}
