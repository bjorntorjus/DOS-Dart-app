import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/setup_prefill.dart';
import 'package:dart_scoring/screens/player_setup_screen.dart';
import 'package:dart_scoring/services/player_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('prefill preselects players and skips the auto-open sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Anna', createdAt: DateTime(2026)),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: PlayerSetupScreen(
        gameMode: GameMode.x01,
        startingScore: 301,
        prefill: const SetupPrefill(
            playerIds: ['a', 'b'], masterOut: 'double', noBust: true),
      ),
    ));
    await tester.pumpAndSettle();

    // Both players preselected, and no bottom sheet auto-opened over them.
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
