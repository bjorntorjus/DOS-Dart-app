import 'package:flutter/material.dart';

/// The current shipping M3 theme. Four-role palette locked per CLAUDE.md.
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
