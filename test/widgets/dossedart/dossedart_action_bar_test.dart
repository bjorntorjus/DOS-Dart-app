import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_action_bar.dart';

void main() {
  testWidgets('renders all three labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartActionBar(
          onUndo: () {},
          onMiss: () {},
          onMenu: () {},
        ),
      ),
    ));
    expect(find.text('↶ UNDO'), findsOneWidget);
    expect(find.text('✗ MISS'), findsOneWidget);
    expect(find.text('⋯ MENU'), findsOneWidget);
  });

  testWidgets('callbacks fire on tap', (tester) async {
    var u = false, m = false, x = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartActionBar(
          onUndo: () => u = true,
          onMiss: () => m = true,
          onMenu: () => x = true,
        ),
      ),
    ));
    await tester.tap(find.text('↶ UNDO'));
    await tester.tap(find.text('✗ MISS'));
    await tester.tap(find.text('⋯ MENU'));
    expect(u, isTrue);
    expect(m, isTrue);
    expect(x, isTrue);
  });
}
