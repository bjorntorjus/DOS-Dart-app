import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_topbar.dart';

void main() {
  testWidgets('renders exit + title + leg/round', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01TopBar(
          title: 'X01 · 501 · D-OUT',
          legIndex: 1,
          legCount: 3,
          roundNumber: 7,
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('◀ EXIT'), findsOneWidget);
    expect(find.text('X01 · 501 · D-OUT'), findsOneWidget);
    expect(find.text('L 1/3 · RND 7'), findsOneWidget);
  });

  testWidgets('onExit callback fires when EXIT tapped', (tester) async {
    var exited = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01TopBar(
          title: 'X01',
          legIndex: 1,
          legCount: 1,
          roundNumber: 1,
          onExit: () => exited = true,
        ),
      ),
    ));
    await tester.tap(find.text('◀ EXIT'));
    expect(exited, isTrue);
  });
}
