import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_cricket_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Cricket setup: defaults + 2 players → Start opens CricketGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartCricketSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(CricketGameScreen), findsOneWidget);
    expect(find.byType(DossedartCricketSetupScreen), findsNothing);
  });
}
