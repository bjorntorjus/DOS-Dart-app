import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_active_strip.dart';

void main() {
  testWidgets('renders name, dart counter, LAST row and trailing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartActiveStrip(
          playerName: 'Bjørn',
          avatarPath: null,
          accentColor: Colors.cyan,
          dartsInTurn: 1,
          lastThrowLabel: 'T20',
          trailing: Text('ON 7'),
        ),
      ),
    ));
    expect(find.textContaining('BJØRN'), findsOneWidget);
    expect(find.text('DART 2 / 3'), findsOneWidget);
    expect(find.text('LAST · '), findsOneWidget);
    expect(find.text('T20'), findsOneWidget);
    expect(find.text('ON 7'), findsOneWidget);
  });

  testWidgets('shows em-dash placeholder when no throw yet', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartActiveStrip(
          playerName: 'A',
          avatarPath: null,
          accentColor: Colors.cyan,
          dartsInTurn: 0,
        ),
      ),
    ));
    // LAST row is always present (Shanghai omitting it was drift); the value
    // falls back to an em dash before the first throw.
    expect(find.text('LAST · '), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('DART 1 / 3'), findsOneWidget);
  });
}
