import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_splitscore_setup_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Splitscore setup: defaults + 2 players → Start opens HalveItGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartSplitscoreSetupScreen());
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(HalveItGameScreen), findsOneWidget);
    expect(find.byType(DossedartSplitscoreSetupScreen), findsNothing);
  });
}
