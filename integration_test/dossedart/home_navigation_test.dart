import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_home_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART home → tap 501 X01 card → X01 setup screen opens',
      (tester) async {
    await setupTestEnvironment(useDossedartDesign: true);
    await pumpScreen(tester, const DossedartHomeScreen());
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Tap the 501 X01 card.
    await tester.tap(find.text('501'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(DossedartX01SetupScreen), findsOneWidget);
  });
}
