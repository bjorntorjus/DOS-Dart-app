import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/meme_service.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_cockpit_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The SOUND toggle goes through SoundService, which lazily constructs an
  // audioplayers AudioPlayer on first access. Stub the audioplayers method
  // and event channels so that construction succeeds in tests.
  const playersChannel = MethodChannel('xyz.luan/audioplayers');
  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const globalEventsChannel = 'xyz.luan/audioplayers.global/events';

  Future<ByteData?> okEnvelope(ByteData? message) async =>
      const StandardMethodCodec().encodeSuccessEnvelope(null);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Event channels only need 'listen' to be acknowledged; no events follow.
    messenger.setMockMessageHandler(globalEventsChannel, okEnvelope);
    messenger.setMockMethodCallHandler(globalChannel, (call) async => null);
    messenger.setMockMethodCallHandler(playersChannel, (call) async {
      if (call.method == 'create') {
        // Register the per-player event channel before the plugin subscribes.
        final playerId = (call.arguments as Map)['playerId'] as String;
        messenger.setMockMessageHandler(
            'xyz.luan/audioplayers/events/$playerId', okEnvelope);
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(playersChannel, null);
    messenger.setMockMethodCallHandler(globalChannel, null);
    messenger.setMockMessageHandler(globalEventsChannel, null);
  });

  Widget harness({ValueChanged<bool>? onSoundChanged}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDossedartCockpitMenu(
                context,
                meme: MemeService(),
                activePlayerCount: 3,
                onSoundChanged: onSoundChanged,
                onPlayerOverview: () {},
                onExit: () {},
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens the design-A sheet with all rows', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYERS · ADD / REMOVE'), findsOneWidget);
    expect(find.text('3 ACTIVE'), findsOneWidget);
    expect(find.text('AUDIO & FX'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('VIDEO EVENTS'), findsOneWidget);
    expect(find.text('MEMES'), findsOneWidget);
    expect(find.text('VOICE (TTS)'), findsOneWidget);
    expect(find.text('SHOT CLOCK'), findsOneWidget);
    expect(find.text('EXIT MATCH'), findsOneWidget);
    expect(find.text('PLAYER OVERVIEW'), findsNothing);
  });

  testWidgets('toggling SHOT CLOCK persists to AppSettings', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SHOT CLOCK'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('shot_clock_enabled'), isTrue);
  });

  testWidgets('tapping a frequency chip persists to AppSettings',
      (tester) async {
    SharedPreferences.setMockInitialValues({'meme_enabled': true});
    await tester.pumpWidget(harness());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ALWAYS'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('meme_frequency'), 10);
  });

  testWidgets('toggling SOUND forwards the new value to onSoundChanged',
      (tester) async {
    bool? lastSound;
    await tester.pumpWidget(harness(onSoundChanged: (v) => lastSound = v));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOUND'));
    await tester.pump();

    // Sound effects default to enabled, so the first tap turns them off.
    expect(lastSound, isFalse);
  });

  testWidgets('toggling SOUND persists the new value to AppSettings',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOUND'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_effects_enabled'), isFalse);
  });
}
