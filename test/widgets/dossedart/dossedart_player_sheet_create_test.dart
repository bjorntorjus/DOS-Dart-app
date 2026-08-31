import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_player_sheet.dart';

/// "CREATE & ADD" in the arcade player sheet: a newcomer at a party can join
/// without leaving the cockpit. Goes through the same onAdd as a saved player.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)),
      SavedPlayer(id: 'z', name: 'Zed', createdAt: DateTime(2026))
        ..archived = true,
    ]);
  });

  Future<List<SavedPlayer>> openSheet(WidgetTester tester,
      {bool gameOver = false}) async {
    final added = <SavedPlayer>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showDossedartPlayerSheet(
              ctx,
              rows: const [
                DossedartStandingRow(
                    playerIndex: 0,
                    name: 'Ada',
                    avatarPath: null,
                    isActive: true,
                    isRemoved: false,
                    primary: '501'),
                DossedartStandingRow(
                    playerIndex: 1,
                    name: 'Guest',
                    avatarPath: null,
                    isActive: false,
                    isRemoved: false,
                    primary: '501'),
              ],
              gameOver: gameOver,
              excludeSavedIds: {'a'},
              onAdd: added.add,
              onRemove: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return added;
  }

  testWidgets('creates a saved player and hands it to onAdd', (tester) async {
    final added = await openSheet(tester);
    expect(find.text('No more saved players available.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Bo ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE & ADD'));
    await tester.pumpAndSettle();

    expect(added.single.name, 'Bo');
    final saved = await PlayerStorage.loadPlayers();
    expect(saved.map((p) => p.name), containsAll(['Ada', 'Bo']));
    expect(saved.singleWhere((p) => p.name == 'Bo').id, added.single.id);
    expect(find.text('PLAYER OVERVIEW'), findsNothing); // sheet closed
  });

  testWidgets('a duplicate name is refused — archived players count too',
      (tester) async {
    final added = await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'zed');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE & ADD'));
    await tester.pumpAndSettle();

    expect(find.text('NAME ALREADY EXISTS'), findsOneWidget);
    expect(added, isEmpty);
    expect((await PlayerStorage.loadPlayers()).length, 2);
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);
  });

  testWidgets('blank name or game over does nothing', (tester) async {
    final added = await openSheet(tester, gameOver: true);
    await tester.enterText(find.byType(TextField), 'Bo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE & ADD'));
    await tester.pumpAndSettle();
    expect(added, isEmpty);
    expect((await PlayerStorage.loadPlayers()).length, 2);
  });
}
