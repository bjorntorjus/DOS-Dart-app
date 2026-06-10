import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/widgets/dossedart/setup/dossedart_setup_scaffold.dart';

Widget _harness() => MaterialApp(
      home: DossedartSetupScaffold(
        title: 'TEST',
        minPlayers: 1,
        rulesSection: (randomOrder, onChanged) => const SizedBox.shrink(),
        summaryBuilder: (count) => '',
        onStart: (players, randomize) {},
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'adding a player does not use the name controller after dispose',
      (tester) async {
    await tester.pumpWidget(_harness());
    // Let the async player load resolve. pumpAndSettle can't be used anywhere
    // here: the loading CircularProgressIndicator and the dialog's autofocused
    // blinking cursor are both perpetual animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open the "NEW FIGHTER" dialog via the ADD PLAYER tile.
    await tester.tap(find.text('ADD PLAYER'));
    await tester.pump(); // start the dialog open transition
    await tester.pump(const Duration(milliseconds: 400)); // finish it

    await tester.enterText(find.byType(TextField), 'Bjorn');
    await tester.tap(find.text('Create'));
    await tester.pump(); // start the dialog reverse (exit) transition
    // Drive the exit transition — the frame where the disposed-controller
    // crash used to surface.
    await tester.pump(const Duration(milliseconds: 400));

    // The regression: a "TextEditingController used after being disposed"
    // assertion thrown during the exit animation.
    expect(tester.takeException(), isNull);
  });
}
