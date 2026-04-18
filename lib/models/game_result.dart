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

  GameResult({
    required this.gameMode,
    required this.results,
    this.canContinue = false,
    this.statsSkipped = false,
  });
}
