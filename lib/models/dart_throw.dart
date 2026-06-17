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

  /// True when this dart busted the turn (standard X01 rules). No-bust mode
  /// never sets this — overshoot there is a legal turn end, not a bust.
  final bool isBust;

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
    this.isBust = false,
  });

  Map<String, dynamic> toJson() => {
        'pi': playerIndex,
        'seg': segment,
        'mul': multiplier,
        'pts': points,
        'sb': scoreBefore,
        'tn': turnNumber,
        'sst': scoreAtStartOfTurn,
        'tid': turnId,
        'rnd': roundNumber,
        if (isBust) 'bust': true,
      };

  factory DartThrow.fromJson(Map<String, dynamic> j) => DartThrow(
        playerIndex: j['pi'] as int,
        segment: j['seg'] as int,
        multiplier: j['mul'] as int,
        points: j['pts'] as int,
        scoreBefore: j['sb'] as int,
        turnNumber: j['tn'] as int,
        scoreAtStartOfTurn: j['sst'] as int,
        turnId: (j['tid'] as int?) ?? 0,
        roundNumber: (j['rnd'] as int?) ?? 0,
        isBust: (j['bust'] as bool?) ?? false,
      );

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

/// Shared turn-grouping for the DOSSEDART last-turn displays: the most
/// recent turnId for a player — in-progress turns count — formatted as
/// 'T20 · S19 · MISS'. Bull renders as Bull/D-Bull like [DartThrow.shortLabel]
/// (singles get an explicit 'S' prefix, misses are upper-case — both differ
/// from shortLabel, hence the dedicated formatter).
extension RecentTurn on List<DartThrow> {
  /// Joined label of [playerIndex]'s most recent turn, or null when the
  /// player has no throws yet.
  String? recentTurnLabel(int playerIndex) {
    final turn = _recentTurn(playerIndex);
    if (turn.isEmpty) return null;
    return turn.map(_stripDartLabel).join(' · ');
  }

  /// Points sum of [playerIndex]'s most recent turn (0 when no throws).
  int recentTurnSum(int playerIndex) => _recentTurn(playerIndex)
      .fold(0, (acc, t) => acc + t.segment * t.multiplier);

  List<DartThrow> _recentTurn(int playerIndex) {
    final all = where((t) => t.playerIndex == playerIndex).toList();
    if (all.isEmpty) return const [];
    final lastTurnId = all.last.turnId;
    return all.where((t) => t.turnId == lastTurnId).toList();
  }

  static String _stripDartLabel(DartThrow t) {
    if (t.segment == 0) return 'MISS';
    if (t.segment == 25) return t.shortLabel; // 'Bull' / 'D-Bull'
    final prefix = t.multiplier == 3
        ? 'T'
        : t.multiplier == 2
            ? 'D'
            : 'S';
    return '$prefix${t.segment}';
  }
}
