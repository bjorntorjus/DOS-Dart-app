import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/elo_service.dart';
import 'services/game_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameLogger.instance.init();
  await EloService.loadSettings();

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

  runApp(const DartScoringApp());
}

class DartScoringApp extends StatelessWidget {
  const DartScoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Scorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
          brightness: Brightness.dark,
          primary: const Color(0xFF43A047),
          secondary: const Color(0xFFE53935),
          error: const Color(0xFFE53935),
        ),
        appBarTheme: const AppBarTheme(elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
