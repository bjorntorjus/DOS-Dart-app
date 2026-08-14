import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/dossedart/setup/dossedart_setup_scaffold.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Let the async player load resolve. pumpAndSettle can't be used here:
  /// ArcadeFrame runs a continuous AnimationController.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('initialSelectedIds preselects existing, skips unknown/archived',
      (tester) async {
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Anna', createdAt: DateTime(2026)),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026)),
      SavedPlayer(
          id: 'x', name: 'Xena', createdAt: DateTime(2026), archived: true),
    ]);

    var started = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: DossedartSetupScaffold(
        title: 'TEST',
        minPlayers: 1,
        initialSelectedIds: const ['b', 'a', 'x', 'gone'],
        // Exposes a toggle so the test can turn RANDOM ORDER off (default
        // ON) and read back the prefill order via onStart.
        rulesSection: (randomOrder, onChanged) => TextButton(
          onPressed: () => onChanged(false),
          child: Text('RANDOM $randomOrder'),
        ),
        summaryBuilder: (n) => '$n',
        onStart: (players, _) =>
            started = players.map((p) => p.savedPlayerId!).toList(),
      ),
    ));
    await settle(tester);

    // Only Anna and Bo were preselected: 'x' is archived, 'gone' is unknown.
    expect(find.text('2 READY'), findsOneWidget);

    // Random order defaults ON; switch it off so onStart order proves the
    // prefill order ('b' before 'a'), not a shuffle.
    await tester.tap(find.text('RANDOM true'));
    await tester.pump();

    await tester.ensureVisible(find.text('▶ START MATCH ◀'));
    await tester.pump();
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pump();

    expect(started, ['b', 'a']);
  });
}
