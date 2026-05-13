import 'package:flutter/material.dart';

/// Color and spacing tokens for the DOSSEDART arcade redesign.
/// Source of truth: docs/design/dossedart-handoff/README.md
class DossedartTokens {
  DossedartTokens._();

  // Surfaces
  static const Color bg = Color(0xFF0A0014);
  static const Color surface = Color(0xFF1A0030);

  // Accents
  static const Color magenta = Color(0xFFFF00AA);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color yellow = Color(0xFFFFD200);
  static const Color green = Color(0xFF3DFF8E);
  static const Color red = Color(0xFFFF3050);
  static const Color purple = Color(0xFF7B3FFF);
  static const Color orange = Color(0xFFFF7A00);

  // Disabled state (used by primitives that can become unavailable)
  static const Color disabledFill = Color(0x1FFFFFFF);   // Colors.white12
  static const Color disabledBorder = Color(0x3DFFFFFF); // Colors.white24
  static const Color disabledFg = Color(0x61FFFFFF);     // Colors.white38

  // Border widths
  static const double borderThin = 1;
  static const double border = 2;
  static const double borderActive = 3;
  static const double borderTakeover = 5;
}
