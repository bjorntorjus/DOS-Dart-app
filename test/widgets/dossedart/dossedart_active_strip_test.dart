import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_active_strip.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

Future<void> _loadRealFonts() async {
  for (final (family, path) in [
    ('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf'),
    ('VT323', 'assets/fonts/VT323-Regular.ttf'),
  ]) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRealFonts);

  Widget host(Widget strip) =>
      MaterialApp(home: Scaffold(body: Column(children: [strip])));

  DossedartActiveStrip strip({
    String name = 'Kari',
    Widget? slot,
    String scoreLabel = 'POINTS',
    String scoreValue = '58',
    bool smallScore = false,
  }) =>
      DossedartActiveStrip(
        playerName: name,
        avatarPath: null,
        accentColor: DossedartTokens.magenta,
        dartsInTurn: 1,
        modeSlot: slot ??
            const DossedartStripSlot(
                label: 'LAST TURN',
                value: 'T18 · 18 · ✗',
                subLine: '= 4 MARKS'),
        scoreLabel: scoreLabel,
        scoreValue: scoreValue,
        smallScore: smallScore,
      );

  testWidgets('132px family zone in every state (fasit pin)', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final states = <String, DossedartActiveStrip>{
      'cricket last-turn': strip(),
      'first dart (dimmed placeholder)': strip(
          slot: const DossedartStripSlot(
              label: 'LAST TURN',
              value: '— · — · —',
              subLine: 'NO DARTS YET',
              dim: true)),
      'long name': strip(name: 'Alexander the boss bitch'),
      'small score (splitscore label)': strip(
          slot: const DossedartStripSlot(
              label: 'TARGET', value: 'D19', subLine: 'MISS HALVES 240 › 120'),
          scoreLabel: 'POINTS',
          scoreValue: '240',
          smallScore: true),
    };
    for (final e in states.entries) {
      await tester.pumpWidget(host(e.value));
      expect(tester.getSize(find.byType(DossedartActiveStrip)).height, 132.0,
          reason: 'strip zone in "${e.key}"');
    }
  });

  testWidgets('renders header, slot content and score block', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(strip()));
    expect(find.text('Kari'), findsOneWidget);
    expect(find.text('DART 2/3'), findsOneWidget); // 1 thrown → on dart 2
    expect(find.text('LAST TURN'), findsOneWidget);
    expect(find.text('T18 · 18 · ✗'), findsOneWidget);
    expect(find.text('= 4 MARKS'), findsOneWidget);
    expect(find.text('POINTS'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
  });

  testWidgets(
      'lays out without overflow at 412px (old safe boundary) with a '
      '3-digit score', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(strip(
      scoreValue: '168',
      slot: const DossedartStripSlot(
          label: 'LAST TURN', value: 'T18 · 18 · ✗', subLine: '= 4 MARKS'),
    )));
    expect(tester.takeException(), isNull,
        reason: 'the strip must not overflow at the 412px old safe boundary');
  });

  testWidgets('dimmed slot renders at 0.34 opacity', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(strip(
        slot: const DossedartStripSlot(
            label: 'LAST TURN',
            value: '— · — · —',
            subLine: 'NO DARTS YET',
            dim: true))));
    final opacity = tester.widget<Opacity>(find.ancestor(
        of: find.text('NO DARTS YET'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 0.34);
  });
}
