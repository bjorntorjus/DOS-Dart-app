import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/elo_service.dart';
import 'services/game_logger.dart';
import 'theme/app_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameLogger.instance.init();
  await EloService.loadSettings();
  final useNewDesign = await AppSettings.getUseNewDesign();

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

  runApp(DartScoringApp(useNewDesign: useNewDesign));
}

class DartScoringApp extends StatelessWidget {
  final bool useNewDesign;
  const DartScoringApp({super.key, required this.useNewDesign});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Scorer',
      debugShowCheckedModeBanner: false,
      theme: useNewDesign ? buildIndigoTheme() : buildClassicTheme(),
      home: const HomeScreen(),
    );
  }
}
