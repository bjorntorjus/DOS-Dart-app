import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_menu_sheet.dart';

void main() {
  bool? lastSound;
  bool? lastVideo;
  bool? lastMemes;
  bool? lastTts;
  int playerOverviewTaps = 0;
  int exitTaps = 0;

  setUp(() {
    lastSound = null;
    lastVideo = null;
    lastMemes = null;
    lastTts = null;
    playerOverviewTaps = 0;
    exitTaps = 0;
  });

  Widget harness({
    bool sound = true,
    bool video = true,
    bool memes = false,
    bool tts = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DossedartMenuSheet(
          initialSound: sound,
          initialVideo: video,
          initialMemes: memes,
          initialTts: tts,
          onSoundChanged: (v) => lastSound = v,
          onVideoChanged: (v) => lastVideo = v,
          onMemesChanged: (v) => lastMemes = v,
          onTtsChanged: (v) => lastTts = v,
          onPlayerOverview: () => playerOverviewTaps++,
          onExit: () => exitTaps++,
        ),
      ),
    );
  }

  testWidgets('renders four toggles plus PLAYER OVERVIEW and EXIT MATCH',
      (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('SOUND'), findsOneWidget);
    expect(find.text('VIDEO EVENTS'), findsOneWidget);
    expect(find.text('MEMES'), findsOneWidget);
    expect(find.text('VOICE (TTS)'), findsOneWidget);
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);
    expect(find.text('EXIT MATCH'), findsOneWidget);
  });

  testWidgets('tapping SOUND fires onSoundChanged with toggled value',
      (tester) async {
    await tester.pumpWidget(harness(sound: true));
    await tester.tap(find.text('SOUND'));
    await tester.pump();
    expect(lastSound, isFalse);
  });

  testWidgets('tapping MEMES off fires onMemesChanged(true) when initially off',
      (tester) async {
    await tester.pumpWidget(harness(memes: false));
    await tester.tap(find.text('MEMES'));
    await tester.pump();
    expect(lastMemes, isTrue);
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

  testWidgets('PLAYER OVERVIEW fires onPlayerOverview', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('PLAYER OVERVIEW'));
    await tester.pump();
    expect(playerOverviewTaps, 1);
  });

  testWidgets('EXIT MATCH fires onExit', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('EXIT MATCH'));
    await tester.pump();
    expect(exitTaps, 1);
  });
}
