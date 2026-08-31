import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/dossedart_one_up_active_card.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/one_up_life_pips.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';

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

  List<OneUpStanding> four({bool lastLife = false, bool survivorOut = false}) => [
        OneUpStanding(name: 'Jonas', accent: dossedartAccent(0), lives: 3, maxLives: 3),
        OneUpStanding(
            name: 'Kari',
            accent: dossedartAccent(1),
            lives: lastLife ? 1 : 2,
            maxLives: 3,
            isActive: true),
        OneUpStanding(
            name: 'Per',
            accent: dossedartAccent(2),
            lives: 3,
            maxLives: 3,
            outOfRound: survivorOut),
        OneUpStanding(
            name: 'Mia', accent: dossedartAccent(3), lives: 0, maxLives: 3, eliminated: true),
      ];

  Widget host(Widget card) => MaterialApp(home: Scaffold(body: Column(children: [card])));

  DossedartOneUpActiveCard card({
    int? target = 118,
    int turnTotal = 71,
    int darts = 2,
    OneUpCardMode mode = OneUpCardMode.normal,
    bool survivor = false,
    String? targetBy = 'Per',
    String? hit = 'T16 +',
    List<OneUpStanding>? standings,
    String name = 'Kari',
    int lives = 2,
  }) =>
      DossedartOneUpActiveCard(
        playerName: name,
        avatarPath: null,
        accentColor: dossedartAccent(1),
        lives: lives,
        maxLives: 3,
        target: target,
        turnTotal: turnTotal,
        currentDartIndex: darts,
        cardMode: mode,
        survivor: survivor,
        roundNumber: 4,
        targetBy: targetBy,
        standings: standings ?? four(),
        hitSuggestion: hit,
      );

  testWidgets('272px zone in every stress state', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final states = <String, DossedartOneUpActiveCard>{
      'need + hit': card(),
      'free throw': card(
          target: null, mode: OneUpCardMode.free, targetBy: null, hit: null, darts: 0, turnTotal: 0),
      'safe survivor': card(mode: OneUpCardMode.safe, survivor: true),
      "can't beat": card(mode: OneUpCardMode.cantBeat, hit: null),
      'last life + long name': card(
          name: 'Alexander the boss bitch', lives: 1, standings: four(lastLife: true)),
      'six players': card(standings: [
        ...four(survivorOut: true),
        OneUpStanding(name: 'Tor', accent: dossedartAccent(4), lives: 3, maxLives: 3),
        OneUpStanding(name: 'Andreas', accent: dossedartAccent(5), lives: 2, maxLives: 3),
      ]),
    };
    for (final e in states.entries) {
      await tester.pumpWidget(host(e.value));
      expect(tester.getSize(find.byType(DossedartOneUpActiveCard)).height, 272.0,
          reason: 'zone height in "${e.key}"');
    }
  });

  testWidgets(
      'lays out without overflow at 393dp (pixel_5, CI integration-test '
      'width) with 6 players, life pips and a long name', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(card(
      name: 'Alexander the boss bitch',
      lives: 1,
      standings: [
        ...four(lastLife: true, survivorOut: true),
        OneUpStanding(name: 'Tor', accent: dossedartAccent(4), lives: 3, maxLives: 3),
        OneUpStanding(name: 'Andreas', accent: dossedartAccent(5), lives: 2, maxLives: 3),
      ],
    )));
    expect(tester.takeException(), isNull,
        reason: 'the card must not overflow at the pixel_5 phone width');
  });

  testWidgets('primary block: BEAT target vs SET THE TARGET', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card()));
    expect(find.text('BEAT'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    await tester.pumpWidget(host(card(
        target: null, mode: OneUpCardMode.free, targetBy: null, hit: null)));
    expect(find.text('SET THE\nTARGET'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // TARGET BY dimmed + THIS TURN "/ —"
  });

  testWidgets('rail rows: hearts (also when out of the round), OUT; TARGET BY bottom',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(standings: four(survivorOut: true))));
    expect(find.text('💀 OUT'), findsOneWidget);
    // Out-of-round rows keep their life pips (dimmed) — no ROUND OUT badge.
    expect(find.text('ROUND OUT'), findsNothing);
    // 3 rail rows with pips (the 4th row is OUT) + the header's own pips.
    expect(find.byType(OneUpLifePips), findsNWidgets(4));
    expect(find.text('BY PER'), findsOneWidget);
    // No sorting: throw order preserved (Jonas row 1, i.e. rank text '1'
    // appears left of JONAS — sufficient to assert both exist unsorted).
    expect(find.text('JONAS'), findsOneWidget);
  });

  testWidgets('survivor rule line label', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(survivor: true)));
    expect(find.text('SURVIVOR · RND 4'), findsOneWidget);
    await tester.pumpWidget(host(card()));
    expect(find.text('SURVIVOR · RND 4'), findsNothing);
  });

  testWidgets('last life shows the LAST LIFE tag (carried over from the old card)',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(lives: 1)));
    expect(find.text('LAST LIFE'), findsOneWidget);
    await tester.pumpWidget(host(card(lives: 2)));
    expect(find.text('LAST LIFE'), findsNothing);
  });

  testWidgets(
      'rail: eliminated wins over outOfRound when both flags are set '
      '(engine sets both on every survivor elimination)', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(standings: [
      OneUpStanding(
          name: 'Per',
          accent: dossedartAccent(2),
          lives: 0,
          maxLives: 3,
          eliminated: true,
          outOfRound: true),
    ])));
    expect(find.text('💀 OUT'), findsOneWidget);
    expect(find.text('ROUND OUT'), findsNothing);
  });
}
