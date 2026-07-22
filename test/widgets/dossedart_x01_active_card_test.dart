import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_active_card.dart';
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

  List<X01Standing> six({bool tied = false}) => [
        for (final (i, (name, rem)) in [
          ('Jonas', 60),
          ('Tor', 89),
          ('Live', 141),
          ('Mia', 218),
          ('Andreas', 264),
          ('Per', 301),
        ].indexed)
          X01Standing(
              name: name,
              accent: dossedartAccent(i),
              remaining: tied ? 501 : rem,
              isActive: i == 2),
      ];

  Widget host(DossedartX01ActiveCard card) => MaterialApp(
      home: Scaffold(body: Column(children: [card])));

  DossedartX01ActiveCard card({
    String name = 'Live',
    String? last = 'T20 · 20 · —',
    int? lastSum = 80,
    double? avg = 58.4,
    int? hit = 61,
    String? tip = 'T20 T19 D12',
    List<X01Standing>? standings,
  }) =>
      DossedartX01ActiveCard(
        playerName: name,
        avatarPath: null,
        accentColor: dossedartAccent(2),
        remaining: 141,
        currentDartIndex: 2,
        lastTurnLabel: last,
        lastTurnSum: lastSum,
        checkoutTip: tip,
        avg: avg,
        hitPercent: hit,
        standings: standings ?? six(),
      );

  testWidgets('272px zone in every stress state — the regression pin',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final states = <String, DossedartX01ActiveCard>{
      'max (6 players + checkout)': card(),
      'no checkout': card(tip: null),
      'first dart (all placeholders)': card(
          last: null, lastSum: null, avg: null, hit: null, tip: null,
          standings: six(tied: true)),
      'long name': card(name: 'Alexander the boss bitch'),
    };
    for (final entry in states.entries) {
      await tester.pumpWidget(host(entry.value));
      final h = tester.getSize(find.byType(DossedartX01ActiveCard)).height;
      expect(h, 272.0, reason: 'zone height in state "${entry.key}"');
    }
  });

  testWidgets('TO WIN delta vs leader; YOU LEAD when lowest; TIED at start',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(card())); // active Live 141, leader 60
    expect(find.text('▲ 81'), findsOneWidget);
    expect(find.text('👑'), findsOneWidget); // unique leader Jonas

    final leading = [
      X01Standing(name: 'Live', accent: dossedartAccent(0), remaining: 40, isActive: true),
      X01Standing(name: 'Tor', accent: dossedartAccent(1), remaining: 89),
    ];
    await tester.pumpWidget(host(card(standings: leading)));
    expect(find.text('YOU LEAD'), findsOneWidget);

    await tester.pumpWidget(host(card(standings: six(tied: true))));
    expect(find.text('TIED'), findsOneWidget);
    expect(find.text('👑'), findsNothing); // no crown on a shared lead
  });

  testWidgets('empty checkout renders a dimmed placeholder, never collapses',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(tip: null)));
    expect(find.text('— — —'), findsOneWidget);
  });
}
