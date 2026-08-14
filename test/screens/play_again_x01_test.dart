import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/player_setup_screen.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/video_service.dart';

/// PLAY AGAIN (task 9, continue-dialog-play-again): the classic-track X01
/// result screen's rematch button must record stats exactly once (same
/// protocol as FINISH GAME) and then land on the setup screen prefilled
/// with the previous rules and roster — never fall through to the home
/// path silently.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Winner videos would push a modal overlay that never settles in tests.
    VideoService.instance.setEnabled(false);
  });

  testWidgets(
      'X01: PLAY AGAIN records exactly once and reopens setup with the '
      'same players preselected', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1)),
      SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2026, 1, 1)),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501, savedPlayerId: 'a'),
          Player(name: 'B', score: 501, savedPlayerId: 'b'),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();

    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    // Bounded pumps throughout: the live game screen can keep animating, so
    // pumpAndSettle is unsafe once navigation bounces between screens.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // P0 checks out for real (D20 from 40); P1 finishes the round with
    // three singles so the round resolves → result screen.
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2);
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(20, 1);
    }
    await settle();
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    // PLAY AGAIN: records exactly once and lands on the setup screen with
    // the same players preselected and the same rules.
    await tester.tap(find.text('↻ PLAY AGAIN'));
    await settle();
    await settle();

    final saved = await PlayerStorage.loadPlayers();
    expect(saved.firstWhere((p) => p.id == 'a').gamesPlayed, 1,
        reason: 'again must record exactly once, like Finish');
    expect(find.byType(PlayerSetupScreen), findsOneWidget,
        reason: 'classic-track x01 rematch goes to the classic setup');
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
