import 'dart:ui';
import 'package:flutter/material.dart';
import 'data/achievement_catalog.dart';
import 'screens/dossedart/dossedart_home_screen.dart';
import 'screens/home_screen.dart';
import 'services/achievement_service.dart';
import 'services/app_settings.dart';
import 'services/elo_service.dart';
import 'services/game_logger.dart';
import 'services/player_storage.dart';
import 'theme/classic_theme.dart';
import 'theme/dossedart_theme.dart';
import 'widgets/dossedart/achievement_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameLogger.instance.init();
  await EloService.loadSettings();
  final useDossedartDesign = await AppSettings.getUseDossedartDesign();

  // Achievements: register the catalog and silently retro-grant everything the
  // existing stats already prove (no banners for past play — spec decision #3).
  AchievementService.instance.registerCatalog(achievementCatalog);
  final savedPlayers = await PlayerStorage.loadPlayers();
  var retroChanged = false;
  for (final p in savedPlayers) {
    if (!p.achievementsRetroGranted) {
      AchievementService.instance.retroGrantSilently(p);
      retroChanged = true;
    }
  }
  if (retroChanged) await PlayerStorage.savePlayers(savedPlayers);

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
      builder: (context, child) =>
          AchievementOverlayHost(child: child ?? const SizedBox.shrink()),
      home: useDossedartDesign
          ? const DossedartHomeScreen()
          : const HomeScreen(),
    );
  }
}
