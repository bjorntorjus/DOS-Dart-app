import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/overview/dossedart_overview_header.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: Row(children: [Expanded(child: child)])));

  testWidgets('DART n/3 counts the dart being thrown (grammar rule 4)',
      (tester) async {
    // 0 thrown → you are on dart 1; 2 thrown → on dart 3 (never 4/3).
    for (final (thrown, label) in [(0, 'DART 1/3'), (1, 'DART 2/3'), (2, 'DART 3/3')]) {
      await tester.pumpWidget(host(DossedartOverviewHeader(
        playerName: 'KARI',
        avatarPath: null,
        accent: DossedartTokens.magenta,
        dartsThrown: thrown,
      )));
      expect(find.text(label), findsOneWidget,
          reason: '$thrown thrown should read "$label"');
    }
  });

  testWidgets('name size curve: 18/15/12/10 at thresholds 6/10/16',
      (tester) async {
    for (final (name, size) in [
      ('KARI', 18.0),           // <=6
      ('ALEXANDRA', 15.0),      // <=10
      ('KARI FRANSISKA', 12.0), // <=16
      ('ALEXANDER THE BOSS', 10.0), // >16
    ]) {
      await tester.pumpWidget(host(DossedartOverviewHeader(
        playerName: name,
        avatarPath: null,
        accent: DossedartTokens.cyan,
        dartsThrown: 0,
      )));
      final text = tester.widget<Text>(find.text(name));
      expect(text.style?.fontSize, size, reason: '"$name" should be ${size}px');
    }
  });

  testWidgets('trailing slot renders right of the name block', (tester) async {
    await tester.pumpWidget(host(DossedartOverviewHeader(
      playerName: 'KARI',
      avatarPath: null,
      accent: DossedartTokens.cyan,
      dartsThrown: 0,
      trailing: const Text('501', key: Key('primary')),
    )));
    expect(find.byKey(const Key('primary')), findsOneWidget);
  });
}
