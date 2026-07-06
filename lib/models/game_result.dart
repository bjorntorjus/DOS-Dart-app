class PlayerResult {
  final String name;
  final String? avatarPath;
  final int placement;
  final Map<String, dynamic> stats;
  final double? ratingBefore;
  final double? ratingAfter;

  PlayerResult({
    required this.name,
    this.avatarPath,
    required this.placement,
    this.stats = const {},
    this.ratingBefore,
    this.ratingAfter,
  });

  double? get ratingChange =>
      ratingBefore != null && ratingAfter != null
          ? ratingAfter! - ratingBefore!
          : null;
}

class GameResult {
  final String gameMode;
  final List<PlayerResult> results;
  final bool canContinue;
  final bool statsSkipped;

  /// Whether the result screen may offer "↶ Back" (undo). False after a
  /// sudden-death tiebreak: rewinding a live tiebreak is meaningless and used
  /// to leave half-rewound state behind (audit 2026-07-06, F4).
  final bool canUndo;

  GameResult({
    required this.gameMode,
    required this.results,
    this.canContinue = false,
    this.statsSkipped = false,
    this.canUndo = true,
  });
}
