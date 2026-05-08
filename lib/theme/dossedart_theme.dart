import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dossedart_tokens.dart';

/// Builds the arcade ThemeData for the DOSSEDART redesign.
///
/// Square corners, neon accent borders, dark CRT-style surfaces.
/// Display type uses Press Start 2P; caption/body uses VT323.
ThemeData buildDossedartTheme() {
  final colorScheme = const ColorScheme.dark(
    brightness: Brightness.dark,
    primary: DossedartTokens.magenta,
    onPrimary: Colors.white,
    secondary: DossedartTokens.cyan,
    onSecondary: DossedartTokens.bg,
    tertiary: DossedartTokens.yellow,
    onTertiary: DossedartTokens.bg,
    error: DossedartTokens.red,
    onError: Colors.white,
    surface: DossedartTokens.surface,
    onSurface: Colors.white,
    surfaceContainerHighest: DossedartTokens.surface,
    outline: DossedartTokens.magenta,
    outlineVariant: DossedartTokens.cyan,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: DossedartTokens.bg,
    canvasColor: DossedartTokens.bg,
  );

  final display = GoogleFonts.pressStart2pTextTheme(base.textTheme);
  final caption = GoogleFonts.vt323TextTheme(base.textTheme);

  // Display roles use Press Start 2P; body/label roles use VT323.
  final textTheme = base.textTheme.copyWith(
    displayLarge: display.displayLarge?.copyWith(color: DossedartTokens.yellow, letterSpacing: 4),
    displayMedium: display.displayMedium?.copyWith(color: DossedartTokens.yellow, letterSpacing: 3),
    displaySmall: display.displaySmall?.copyWith(color: Colors.white, letterSpacing: 2),
    headlineLarge: display.headlineLarge?.copyWith(color: Colors.white, letterSpacing: 2),
    headlineMedium: display.headlineMedium?.copyWith(color: Colors.white, letterSpacing: 2),
    headlineSmall: display.headlineSmall?.copyWith(color: Colors.white, letterSpacing: 1.5),
    titleLarge: display.titleLarge?.copyWith(color: Colors.white, letterSpacing: 1.5),
    titleMedium: display.titleMedium?.copyWith(color: Colors.white, letterSpacing: 1),
    titleSmall: display.titleSmall?.copyWith(color: Colors.white, letterSpacing: 1),
    labelLarge: display.labelLarge?.copyWith(color: Colors.white, letterSpacing: 1),
    labelMedium: display.labelMedium?.copyWith(color: Colors.white, letterSpacing: 1),
    labelSmall: display.labelSmall?.copyWith(color: Colors.white, letterSpacing: 1),
    bodyLarge: caption.bodyLarge?.copyWith(color: Colors.white, fontSize: 18),
    bodyMedium: caption.bodyMedium?.copyWith(color: Colors.white, fontSize: 16),
    bodySmall: caption.bodySmall?.copyWith(color: Colors.white70, fontSize: 14),
  );

  // Square corners everywhere — arcade aesthetic.
  const zeroRadius = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: DossedartTokens.bg,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: DossedartTokens.yellow),
      shape: const Border(
        bottom: BorderSide(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
    ),
    cardTheme: CardThemeData(
      color: DossedartTokens.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DossedartTokens.magenta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: zeroRadius,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DossedartTokens.cyan,
        side: const BorderSide(color: DossedartTokens.cyan, width: DossedartTokens.border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: zeroRadius,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DossedartTokens.cyan,
        shape: zeroRadius,
        textStyle: textTheme.labelLarge,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: DossedartTokens.magenta,
      thickness: DossedartTokens.borderThin,
      space: DossedartTokens.borderThin,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DossedartTokens.surface,
      contentTextStyle: textTheme.bodyMedium,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: DossedartTokens.cyan, width: DossedartTokens.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DossedartTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: DossedartTokens.magenta, width: DossedartTokens.borderActive),
      ),
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DossedartTokens.surface,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: DossedartTokens.cyan, width: DossedartTokens.borderActive),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return DossedartTokens.magenta;
        return Colors.white70;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DossedartTokens.magenta.withValues(alpha: 0.4);
        }
        return DossedartTokens.surface;
      }),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: DossedartTokens.magenta,
      inactiveTrackColor: DossedartTokens.surface,
      thumbColor: DossedartTokens.cyan,
      overlayColor: Color(0x33FF00AA),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DossedartTokens.magenta,
    ),
  );
}
