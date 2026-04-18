class DartThrow {
  final int playerIndex;
  final int segment; // 1-20, 25 for bull, 0 for miss
  final int multiplier; // 1=single, 2=double, 3=triple, 0=miss
  final int points;
  final int scoreBefore;
  final int turnNumber; // 0, 1, or 2 (which dart in the turn)
  final int scoreAtStartOfTurn;
  final int turnId; // monotonically increasing ID per turn, unique even if score unchanged
  final int roundNumber; // which round (full cycle of all players) this throw belongs to

  DartThrow({
    required this.playerIndex,
    required this.segment,
    required this.multiplier,
    required this.points,
    required this.scoreBefore,
    required this.turnNumber,
    required this.scoreAtStartOfTurn,
    this.turnId = 0,
    this.roundNumber = 0,
  });

  String get label {
    if (segment == 0) return 'Miss';
    if (segment == 25) {
      return multiplier == 2 ? 'D-Bull (50)' : 'Bull (25)';
    }
    final prefix = multiplier == 3
        ? 'T'
        : multiplier == 2
            ? 'D'
            : 'S';
    return '$prefix$segment ($points)';
  }

  /// Compact label without points — e.g. "T20", "D-Bull", "Miss"
  String get shortLabel {
    if (segment == 0) return 'Miss';
    if (segment == 25) return multiplier == 2 ? 'D-Bull' : 'Bull';
    final prefix = multiplier == 3
        ? 'T'
        : multiplier == 2
            ? 'D'
            : '';
    return '$prefix$segment';
  }

  String get spokenLabel {
    if (segment == 0) return 'Miss';
    if (segment == 25) return multiplier == 2 ? 'Double Bull' : 'Bull';
    if (multiplier == 3) return 'Triple $segment';
    if (multiplier == 2) return 'Double $segment';
    return '$segment';
  }
}
