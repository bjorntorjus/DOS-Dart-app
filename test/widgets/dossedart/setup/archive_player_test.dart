import 'dart:convert';

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

Map<String, dynamic> _playerJson(String id, String name,
        {bool archived = false}) =>
    {
      'id': id,
      'name': name,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'archived': archived,
    };

void _seedPlayers(List<Map<String, dynamic>> players) {
  SharedPreferences.setMockInitialValues({
    'saved_players': jsonEncode(players),
  });
}

/// Let the async player load resolve. pumpAndSettle can't be used anywhere
/// here: the loading CircularProgressIndicator is a perpetual animation.
Future<void> _pumpLoaded(WidgetTester tester) async {
  await tester.pumpWidget(_harness());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Drive a dialog open/close transition without pumpAndSettle.
Future<void> _settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
      'archive via profile dialog: confirm hides tile and shows ARCHIVE row',
      (tester) async {
    _seedPlayers([
      _playerJson('a1', 'Alice'),
      _playerJson('b1', 'Bob'),
    ]);
    await _pumpLoaded(tester);

    expect(find.text('ALICE'), findsOneWidget);
    expect(find.text('BOB'), findsOneWidget);
    expect(find.textContaining('ARCHIVE (', findRichText: true), findsNothing);

    // Select Alice so we can verify archiving also deselects her.
    await tester.tap(find.text('ALICE'));
    await tester.pump();
    expect(find.text('1 READY'), findsOneWidget);

    // Long-press opens the profile dialog with the archive action.
    await tester.longPress(find.text('ALICE'));
    await _settleDialog(tester);
    expect(find.text('ARCHIVE PLAYER'), findsOneWidget);

    // Tap archive -> confirmation dialog.
    await tester.tap(find.text('ARCHIVE PLAYER'));
    await _settleDialog(tester);
    expect(find.text('ARCHIVE PLAYER?'), findsOneWidget);

    // Confirm -> both dialogs close, tile gone, ARCHIVE row visible.
    await tester.tap(find.text('ARCHIVE'));
    await _settleDialog(tester);
    await _settleDialog(tester);

    expect(find.text('ALICE'), findsNothing);
    expect(find.text('BOB'), findsOneWidget);
    expect(find.text('ARCHIVE (1)'), findsOneWidget);
    // Archived player no longer counts as selected.
    expect(find.text('0 READY · MIN 1'), findsOneWidget);

    // Persistence: the FULL list is saved, never a filtered one.
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('saved_players')!) as List<dynamic>;
    expect(stored, hasLength(2));
    final alice = stored
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['id'] == 'a1');
    expect(alice['archived'], isTrue);
  });

  testWidgets(
      'restore via ARCHIVE row: archived player returns to picker, row hides',
      (tester) async {
    _seedPlayers([
      _playerJson('a1', 'Alice', archived: true),
      _playerJson('b1', 'Bob'),
    ]);
    await _pumpLoaded(tester);

    // Archived player hidden from the picker; ARCHIVE row shown.
    expect(find.text('ALICE'), findsNothing);
    expect(find.text('ARCHIVE (1)'), findsOneWidget);

    // Expand the archive row -> archived player listed.
    await tester.ensureVisible(find.text('ARCHIVE (1)'));
    await tester.pump();
    await tester.tap(find.text('ARCHIVE (1)'));
    await tester.pump();
    expect(find.text('ALICE'), findsOneWidget);

    // Open the archived player's profile -> RESTORE instead of archive.
    await tester.ensureVisible(find.text('ALICE'));
    await tester.pump();
    await tester.tap(find.text('ALICE'));
    await _settleDialog(tester);
    expect(find.text('RESTORE'), findsOneWidget);
    expect(find.text('ARCHIVE PLAYER'), findsNothing);

    // Restore -> player back in the main picker, archive row gone.
    await tester.tap(find.text('RESTORE'));
    await _settleDialog(tester);
    await _settleDialog(tester);

    expect(find.text('ALICE'), findsOneWidget);
    expect(find.text('ARCHIVE (1)'), findsNothing);
    expect(find.text('RESTORE'), findsNothing);

    // Persistence: full list saved with archived flag cleared.
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('saved_players')!) as List<dynamic>;
    expect(stored, hasLength(2));
    final alice = stored
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['id'] == 'a1');
    expect(alice['archived'], isFalse);
  });
}
