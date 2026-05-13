import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/dossedart/dossedart_home_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/elo_service.dart';
import 'services/game_logger.dart';
import 'theme/classic_theme.dart';
import 'theme/dossedart_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameLogger.instance.init();
  await EloService.loadSettings();
  final useDossedartDesign = await AppSettings.getUseDossedartDesign();

  // Catch Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    GameLogger.instance.logError(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  // Catch async errors not handled by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    GameLogger.instance.logError('Unhandled error', error, stack);
    return true;
  };

  runApp(DartScoringApp(useDossedartDesign: useDossedartDesign));
}

class DartScoringApp extends StatelessWidget {
  const DartScoringApp({super.key, required this.useDossedartDesign});

  final bool useDossedartDesign;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Scorer',
      debugShowCheckedModeBanner: false,
      theme: useDossedartDesign ? buildDossedartTheme() : buildClassicTheme(),
      home: useDossedartDesign
          ? const DossedartHomeScreen()
          : const HomeScreen(),
    );
  }
}
