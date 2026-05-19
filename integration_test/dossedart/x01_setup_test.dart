import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART X01 setup: defaults + 2 players → Start opens GameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(
      tester,
      const DossedartX01SetupScreen(startingScore: 501),
    );
    await tester.pumpAndSettle();

    // Select both seeded players.
    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    // Tap the Start button (exact label from scaffold).
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget,
        reason: 'X01 setup Start should push GameScreen via Navigator.pushReplacement');
    expect(find.byType(DossedartX01SetupScreen), findsNothing,
        reason: 'pushReplacement should remove the setup screen');
  });
}
