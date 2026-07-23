/// 1UP hit suggestion (approved PROPOSAL, fasit 2026-07-22): the lowest
/// single-dart score that reaches [need] (tie = success, so >= is enough),
/// with a trailing ' +' when it overshoots. Null when nothing is needed or
/// no single dart can do it (need > 60) — the status plate then falls back
/// to its darts-left line. Label preference at equal score: single, 25,
/// double, triple, BULL — simplest throw first.
String? oneUpHitSuggestion(int need) {
  if (need <= 0 || need > 60) return null;

  String? labelFor(int score) {
    if (score >= 1 && score <= 20) return '$score';
    if (score == 25) return '25';
    if (score % 2 == 0 && score ~/ 2 >= 1 && score ~/ 2 <= 20) {
      return 'D${score ~/ 2}';
    }
    if (score % 3 == 0 && score ~/ 3 >= 1 && score ~/ 3 <= 20) {
      return 'T${score ~/ 3}';
    }
    if (score == 50) return 'BULL';
    return null;
  }

  for (var score = need; score <= 60; score++) {
    final label = labelFor(score);
    if (label != null) {
      return score == need ? label : '$label +';
    }
  }
  return null;
}
