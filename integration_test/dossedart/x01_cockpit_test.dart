import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/x01/dossedart_player_overview_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'DOSSEDART X01 cockpit renders + MENU opens Player Overview',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['MIA', 'JON'],
    );
    final players = buildPlayers(names: ['MIA', 'JON'], startingScore: 501);
    await pumpScreen(
      tester,
      GameScreen(
        players: players,
        startingScore: 501,
        useDossedartDesign: true,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Cockpit renders: name + remaining + dartboard + menu button visible.
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('501'), findsWidgets);
    expect(find.byType(DossedartX01Dartboard), findsOneWidget);
    expect(find.text('⋯ MENU'), findsOneWidget);

    // Open MENU → see "PLAYER OVERVIEW" entry.
    await tester.tap(find.text('⋯ MENU'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);

    // Tap PLAYER OVERVIEW → Overview screen appears with both players.
    await tester.tap(find.text('PLAYER OVERVIEW'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.byType(DossedartPlayerOverviewScreen), findsOneWidget);
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('JON'), findsOneWidget);
  });
}
