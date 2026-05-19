import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_atc_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART ATC setup: defaults + 2 players → Start opens AroundTheClockGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartAtcSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(AroundTheClockGameScreen), findsOneWidget);
    expect(find.byType(DossedartAtcSetupScreen), findsNothing);
  });
}
