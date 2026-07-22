import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Small shared helpers for the DOSSEDART Golf cockpit widgets (hero,
/// leaderboard, input console, scorecard strip). Split out of the retired
/// `DossedartGolfActiveCard` (cockpit v2) so none of the v2 widgets need to
/// depend on each other just to share a colour/label formatter.

/// 'E' for even, otherwise '+n' / '-n'.
String vsParLabel(int vsPar) =>
    vsPar == 0 ? 'E' : (vsPar > 0 ? '+$vsPar' : '$vsPar');

/// Scorecard/term colour for a hole score (1-6 strokes).
Color golfTermColor(int strokes) => switch (strokes) {
      1 => DossedartTokens.cyan,
      2 => DossedartTokens.green,
      3 => DossedartTokens.phosphor,
      4 => DossedartTokens.orange,
      _ => DossedartTokens.red,
    };

/// Colour for a vs-par delta: under par reads as an advantage (green),
/// over par as a warning (orange), even as neutral phosphor.
Color vsParColor(int vsPar) {
  if (vsPar < 0) return DossedartTokens.green;
  if (vsPar > 0) return DossedartTokens.orange;
  return DossedartTokens.phosphor;
}
