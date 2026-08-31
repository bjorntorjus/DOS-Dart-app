import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/mid_game_player_sheet.dart';

/// Mid-game "Create & add": a newcomer at a party can join without leaving
/// the game screen. The new player is persisted via PlayerStorage and handed
/// to onAdd exactly like an existing saved player would be.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)),
    ]);
  });

  Future<List<SavedPlayer>> openSheet(WidgetTester tester,
      {bool gameOver = false}) async {
    final added = <SavedPlayer>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showMidGamePlayerSheet(
              context: ctx,
              players: [
                Player(name: 'Ada', score: 501, savedPlayerId: 'a'),
                Player(name: 'Guest', score: 501),
              ],
              isRemoved: (_) => false,
              gameOver: gameOver,
              colorFor: (_) => Colors.green,
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

    final create = find.widgetWithText(FilledButton, 'Create & add');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Bo ');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);

    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(added.single.name, 'Bo');
    final saved = await PlayerStorage.loadPlayers();
    expect(saved.map((p) => p.name), containsAll(['Ada', 'Bo']));
    expect(saved.singleWhere((p) => p.name == 'Bo').id, added.single.id);
    // Sheet closed.
    expect(find.text('Manage players'), findsNothing);
  });

  testWidgets('a duplicate name (case-insensitive) is refused', (tester) async {
    final added = await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'ada');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create & add'));
    await tester.pumpAndSettle();

    expect(find.text('Name already exists'), findsOneWidget);
    expect(added, isEmpty);
    expect((await PlayerStorage.loadPlayers()).length, 1);
    expect(find.text('Manage players'), findsOneWidget);
  });

  testWidgets('disabled once the game is over', (tester) async {
    await openSheet(tester, gameOver: true);
    await tester.enterText(find.byType(TextField), 'Bo');
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create & add');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
  });
}
