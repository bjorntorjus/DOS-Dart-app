import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_gotcha_setup_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gotcha setup seeds rules from initialConfig', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: DossedartGotchaSetupScreen(
        initialConfig: GotchaConfig(targetScore: 501, hardcore: true),
        initialPlayerIds: [],
      ),
    ));
    await tester.pumpAndSettle();
    // Summary line reflects the seeded rules.
    expect(find.textContaining('RACE TO 501'), findsOneWidget);
    expect(find.textContaining('HARDCORE'), findsWidgets);
  });

  testWidgets('x01 setup seeds discrete options', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: DossedartX01SetupScreen(
        startingScore: 301,
        initialOutRule: 'double',
        initialNoBust: true,
        initialPlayerIds: [],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('DOUBLE OUT'), findsWidgets);
    expect(find.textContaining('NO-BUST'), findsWidgets);
  });
}
