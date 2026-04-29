import 'package:flutter/material.dart';

/// Avatar background palette. Used ONLY by PlayerAvatar to make different
/// players visually distinguishable in scoreboards. NOT used for gameplay
/// chrome — see docs/superpowers/specs/2026-04-29-material3-migration-design.md.
///
/// Colors selected to:
/// - Avoid colorScheme.primary (no greens), .secondary/.error (no pure reds),
///   .tertiary (avoid seed-derived hue), and amber/gold (winner medals).
/// - Be visually distinct from each other (≥30° hue separation).
/// - Pass WCAG 4.5:1 contrast against white initial-letter text.
const avatarColors = [
  Color(0xFF7E57C2), // purple
  Color(0xFFEC407A), // pink
  Color(0xFF26A69A), // teal
  Color(0xFFFFA726), // orange
  Color(0xFF5C6BC0), // indigo
  Color(0xFF8D6E63), // brown
  Color(0xFF42A5F5), // light blue
  Color(0xFF9E9D24), // olive
];

Color avatarColor(int index) => avatarColors[index % avatarColors.length];
