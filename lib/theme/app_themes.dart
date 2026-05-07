import 'package:flutter/material.dart';

/// Built-in M3 four-role theme (Claude Code design baseline).
ThemeData buildClassicTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF43A047),
      brightness: Brightness.dark,
      primary: const Color(0xFF43A047),
      secondary: const Color(0xFFFFA726),
      tertiary: const Color(0xFFFFD54F),
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
  );
}

/// Indigo + amber redesign theme (Claude Design handoff).
/// See docs/design/indigo-redesign/README.md for token specs.
ThemeData buildIndigoTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F5DC4),
    brightness: Brightness.dark,
  );
  final colorScheme = base.copyWith(
    primary: const Color(0xFF4F5DC4),
    onPrimary: const Color(0xFFDFE0FF),
    tertiary: const Color(0xFFFFB300),
    onTertiary: const Color(0xFF000000),
    error: const Color(0xFFFF6B35),
    onError: const Color(0xFFFFFFFF),
    surface: const Color(0xFF1C1C24),
    onSurface: const Color(0xFFE5E1E9),
    onSurfaceVariant: const Color(0xFFC7C5D0),
    surfaceContainerHigh: const Color(0xFF21222B),
    surfaceContainerHighest: const Color(0xFF272834),
  );

  // System fallbacks: 'serif' → Noto Serif on Android; 'monospace' → Droid Sans Mono.
  const displayFont = 'serif';
  const monoFont = 'monospace';

  final textTheme = TextTheme(
    displayLarge: const TextStyle(
        fontFamily: displayFont, fontSize: 56, fontWeight: FontWeight.w400),
    displayMedium: const TextStyle(
        fontFamily: displayFont, fontSize: 38, fontWeight: FontWeight.w400),
    displaySmall: const TextStyle(
        fontFamily: displayFont, fontSize: 30, fontWeight: FontWeight.w400),
    headlineMedium: const TextStyle(
        fontFamily: displayFont, fontSize: 24, fontWeight: FontWeight.w400),
    bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelSmall: const TextStyle(
        fontFamily: monoFont,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF14141A),
    dividerColor: const Color(0xFF44464F),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    ),
  );
}
