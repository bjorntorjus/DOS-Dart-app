import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F18 canary: pumpAndSettle on a live game screen must terminate.
/// Before the global test config this hung 1-in-N runs (RNG video roll).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TtsService.instance.resetForTesting();
  });
  tearDown(() => TtsService.instance.resetForTesting());

  testWidgets('pumpAndSettle terminates after throws on X01', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501), Player(name: 'P1', score: 501)],
        startingScore: 501,
        masterOut: 'double',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final dynamic state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    for (var i = 0; i < 6; i++) {
      await state.onDartHitForTest(20, 1);
      await tester.pump();
    }
    await tester.pumpAndSettle(); // must terminate — that IS the assertion
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
