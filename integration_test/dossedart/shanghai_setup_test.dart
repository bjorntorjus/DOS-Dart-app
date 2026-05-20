import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_shanghai_setup_screen.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Shanghai setup: defaults + 2 players → Start opens ShanghaiGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartShanghaiSetupScreen());
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(ShanghaiGameScreen), findsOneWidget);
    expect(find.byType(DossedartShanghaiSetupScreen), findsNothing);
  });
}
