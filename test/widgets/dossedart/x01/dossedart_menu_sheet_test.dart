import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_menu_sheet.dart';

void main() {
  bool? lastSound;
  bool? lastVideo;
  bool? lastMemes;
  bool? lastTts;
  int? lastFrequency;
  bool? lastOffensive;
  bool? lastShotClock;
  int playerOverviewTaps = 0;
  int exitTaps = 0;

  setUp(() {
    lastSound = null;
    lastVideo = null;
    lastMemes = null;
    lastTts = null;
    lastFrequency = null;
    lastOffensive = null;
    lastShotClock = null;
    playerOverviewTaps = 0;
    exitTaps = 0;
  });

  Widget harness({
    bool sound = true,
    bool video = true,
    bool memes = false,
    bool tts = false,
    int memeFrequency = 3,
    bool offensive = false,
    bool shotClock = false,
    int shotClockSeconds = 60,
    int? activePlayerCount = 3,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DossedartMenuSheet(
            initialSound: sound,
            initialVideo: video,
            initialMemes: memes,
            initialTts: tts,
            initialMemeFrequency: memeFrequency,
            initialOffensive: offensive,
            initialShotClock: shotClock,
            shotClockSeconds: shotClockSeconds,
            activePlayerCount: activePlayerCount,
            onSoundChanged: (v) => lastSound = v,
            onVideoChanged: (v) => lastVideo = v,
            onMemesChanged: (v) => lastMemes = v,
            onTtsChanged: (v) => lastTts = v,
            onMemeFrequencyChanged: (v) => lastFrequency = v,
            onOffensiveChanged: (v) => lastOffensive = v,
            onShotClockChanged: (v) => lastShotClock = v,
            onPlayerOverview: () => playerOverviewTaps++,
            onExit: () => exitTaps++,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'design A: PLAYERS card on top with active count, AUDIO & FX section, '
      'SHOT CLOCK row — the old PLAYER OVERVIEW label is gone', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('PLAYERS · ADD / REMOVE'), findsOneWidget);
    expect(find.text('3 ACTIVE'), findsOneWidget);
    expect(find.text('AUDIO & FX'), findsOneWidget);
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('VOICE (TTS)'), findsOneWidget);
    expect(find.text('VIDEO EVENTS'), findsOneWidget);
    expect(find.text('MEMES'), findsOneWidget);
    expect(find.text('SHOT CLOCK'), findsOneWidget);
    expect(find.text('60S'), findsOneWidget);
    expect(find.text('EXIT MATCH'), findsOneWidget);
    expect(find.text('PLAYER OVERVIEW'), findsNothing);
  });

  testWidgets('meme sub-settings hidden while MEMES is off, shown when on',
      (tester) async {
    await tester.pumpWidget(harness(memes: false));
    expect(find.text('FREQUENCY'), findsNothing);
    expect(find.text('OFFENSIVE'), findsNothing);

    await tester.tap(find.text('MEMES'));
    await tester.pump();
    expect(lastMemes, isTrue);
    expect(find.text('FREQUENCY'), findsOneWidget);
    expect(find.text('OFFENSIVE'), findsOneWidget);
    for (final label in ['RARE', 'LOW', 'NORMAL', 'OFTEN', 'ALWAYS']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets(
      'frequency chips map to the classic 1-10 scale: stored 3 selects LOW, '
      'tapping ALWAYS fires 10', (tester) async {
    await tester.pumpWidget(harness(memes: true, memeFrequency: 3));

    await tester.tap(find.text('ALWAYS'));
    await tester.pump();
    expect(lastFrequency, 10);

    await tester.tap(find.text('RARE'));
    await tester.pump();
    expect(lastFrequency, 1);

    await tester.tap(find.text('OFTEN'));
    await tester.pump();
    expect(lastFrequency, 8);

    await tester.tap(find.text('NORMAL'));
    await tester.pump();
    expect(lastFrequency, 5);
  });

  testWidgets('OFFENSIVE toggle fires onOffensiveChanged', (tester) async {
    await tester.pumpWidget(harness(memes: true, offensive: false));
    await tester.tap(find.text('OFFENSIVE'));
    await tester.pump();
    expect(lastOffensive, isTrue);
  });

  testWidgets('SHOT CLOCK toggle fires onShotClockChanged', (tester) async {
    await tester.pumpWidget(harness(shotClock: false));
    await tester.tap(find.text('SHOT CLOCK'));
    await tester.pump();
    expect(lastShotClock, isTrue);
  });

  testWidgets('tapping SOUND fires onSoundChanged with toggled value',
      (tester) async {
    await tester.pumpWidget(harness(sound: true));
    await tester.tap(find.text('SOUND'));
    await tester.pump();
    expect(lastSound, isFalse);
  });

  testWidgets('tapping VIDEO EVENTS fires onVideoChanged with toggled value',
      (tester) async {
    await tester.pumpWidget(harness(video: true));
    await tester.tap(find.text('VIDEO EVENTS'));
    await tester.pump();
    expect(lastVideo, isFalse);
  });

  testWidgets('tapping VOICE (TTS) fires onTtsChanged with toggled value',
      (tester) async {
    await tester.pumpWidget(harness(tts: false));
    await tester.tap(find.text('VOICE (TTS)'));
    await tester.pump();
    expect(lastTts, isTrue);
  });

  testWidgets('PLAYERS card fires onPlayerOverview', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('PLAYERS · ADD / REMOVE'));
    await tester.pump();
    expect(playerOverviewTaps, 1);
  });

  testWidgets('no active count renders the card without the counter',
      (tester) async {
    await tester.pumpWidget(harness(activePlayerCount: null));
    expect(find.text('PLAYERS · ADD / REMOVE'), findsOneWidget);
    expect(find.textContaining('ACTIVE'), findsNothing);
  });

  testWidgets('EXIT MATCH fires onExit', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('EXIT MATCH'));
    await tester.pump();
    expect(exitTaps, 1);
  });
}
