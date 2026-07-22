import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_top_bar.dart';

void main() {
  testWidgets('renders exit + title + trailing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartTopBar(
          title: 'CRICKET · STANDARD',
          trailing: 'RND 7',
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('◀ EXIT'), findsOneWidget);
    expect(find.text('CRICKET · STANDARD'), findsOneWidget);
    expect(find.text('RND 7'), findsOneWidget);
  });

  testWidgets('omits trailing when null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartTopBar(title: 'X01', onExit: () {}),
      ),
    ));
    expect(find.text('◀ EXIT'), findsOneWidget);
    expect(find.text('X01'), findsOneWidget);
  });

  testWidgets('onExit callback fires when EXIT tapped', (tester) async {
    var exited = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartTopBar(
          title: 'X01',
          onExit: () => exited = true,
        ),
      ),
    ));
    await tester.tap(find.text('◀ EXIT'));
    expect(exited, isTrue);
  });
}
