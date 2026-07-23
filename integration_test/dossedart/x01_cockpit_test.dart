import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/widgets/dossedart/dossedart_player_sheet.dart';
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
    // MIA's name now appears twice: once in the header, once as her own
    // row in the standings rail.
    expect(find.text('MIA'), findsNWidgets(2));
    expect(find.text('501'), findsWidgets);
    expect(find.byType(DossedartX01Dartboard), findsOneWidget);
    expect(find.text('⋯ MENU'), findsOneWidget);

    // Open MENU → see "PLAYER OVERVIEW" entry.
    await tester.tap(find.text('⋯ MENU'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);

    // Tap PLAYER OVERVIEW → unified player sheet opens over the dimmed
    // cockpit, listing both players (names also remain in the cockpit behind).
    await tester.tap(find.text('PLAYER OVERVIEW'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.byType(DossedartPlayerSheet), findsOneWidget);
    expect(find.text('MIA'), findsWidgets);
    expect(find.text('JON'), findsWidgets);
  });
}
