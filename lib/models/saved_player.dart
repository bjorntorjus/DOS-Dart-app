class ModeStats {
  int played;
  int won;
  int bestScore;
  /// Flexible per-mode counters. Each game mode stores its own keys.
  /// X01: totalDarts, totalTurnScore, totalTurns, highestTurn, turnsOver100,
  ///      doublesHit, doublesThrown, triplesHit, triplesThrown,
  ///      bullsHit, misses, checkouts, bestCheckout
  /// Killer: kills, shieldsGained, attacksDealt, attacksReceived, selfHits
  /// Halve It: totalScore, totalGames, biggestHalving, roundsHit, totalRounds
  /// Cricket: totalClosedTargets, totalDarts, totalPointsScored
  /// Clock: totalDarts, totalHits, bestDartCount, fastestFinish
  Map<String, int> counters;

  ModeStats({
    this.played = 0,
    this.won = 0,
    this.bestScore = 0,
    Map<String, int>? counters,
  }) : counters = counters ?? {};

  /// Increment a counter by [amount] (default 1)
  void inc(String key, [int amount = 1]) {
    counters[key] = (counters[key] ?? 0) + amount;
  }

  /// Set a counter to the max of current and new value
  void setMax(String key, int value) {
    final current = counters[key] ?? 0;
    if (value > current) counters[key] = value;
  }

  /// Get a counter value, defaulting to 0
  int get(String key) => counters[key] ?? 0;

  Map<String, dynamic> toJson() => {
        'played': played,
        'won': won,
        'bestScore': bestScore,
        'counters': counters,
      };

  factory ModeStats.fromJson(Map<String, dynamic> json) => ModeStats(
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        bestScore: json['bestScore'] as int? ?? 0,
        counters: (json['counters'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toInt()),
            ) ??
            {},
      );
}

class H2HRecord {
  int wins;
  int losses;
  int draws;

  H2HRecord({this.wins = 0, this.losses = 0, this.draws = 0});

  int get total => wins + losses + draws;

  Map<String, dynamic> toJson() => {
        'wins': wins,
        'losses': losses,
        'draws': draws,
      };

  factory H2HRecord.fromJson(Map<String, dynamic> json) => H2HRecord(
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
      );
}

class RatingSnapshot {
  final DateTime date;
  final double rating;
  final int? placement; // rank among all saved players at this point in time

  RatingSnapshot({required this.date, required this.rating, this.placement});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'rating': rating,
        if (placement != null) 'placement': placement,
      };

  factory RatingSnapshot.fromJson(Map<String, dynamic> json) => RatingSnapshot(
        date: DateTime.parse(json['date'] as String),
        rating: (json['rating'] as num).toDouble(),
        placement: json['placement'] as int?,
      );
}

class SavedPlayer {
  final String id;
  String name;
  final DateTime createdAt;

  int gamesPlayed;
  int gamesWon;
  double totalTurnScore;
  int totalTurns;
  int highestTurnScore;
  double rating;
  String? avatarPath;
  int gamesJoinedMidway;
  int gamesLeftMidway;

  Map<String, ModeStats> modeStats;
  Map<String, H2HRecord> headToHead;
  List<RatingSnapshot> ratingHistory;

  SavedPlayer({
    required this.id,
    required this.name,
    required this.createdAt,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalTurnScore = 0,
    this.totalTurns = 0,
    this.highestTurnScore = 0,
    this.rating = 1200.0,
    this.avatarPath,
    this.gamesJoinedMidway = 0,
    this.gamesLeftMidway = 0,
    Map<String, ModeStats>? modeStats,
    Map<String, H2HRecord>? headToHead,
    List<RatingSnapshot>? ratingHistory,
  })  : modeStats = modeStats ?? {},
        headToHead = headToHead ?? {},
        ratingHistory = ratingHistory ?? [];

  double get averageTurnScore =>
      totalTurns > 0 ? totalTurnScore / totalTurns : 0;

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'totalTurnScore': totalTurnScore,
        'totalTurns': totalTurns,
        'highestTurnScore': highestTurnScore,
        'rating': rating,
        'avatarPath': avatarPath,
        'gamesJoinedMidway': gamesJoinedMidway,
        'gamesLeftMidway': gamesLeftMidway,
        'modeStats': modeStats
            .map((key, value) => MapEntry(key, value.toJson())),
        'headToHead': headToHead
            .map((key, value) => MapEntry(key, value.toJson())),
        'ratingHistory': ratingHistory.map((s) => s.toJson()).toList(),
      };

  factory SavedPlayer.fromJson(Map<String, dynamic> json) => SavedPlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        gamesPlayed: json['gamesPlayed'] as int? ?? 0,
        gamesWon: json['gamesWon'] as int? ?? 0,
        totalTurnScore: (json['totalTurnScore'] as num?)?.toDouble() ?? 0,
        totalTurns: json['totalTurns'] as int? ?? 0,
        highestTurnScore: json['highestTurnScore'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 1200.0,
        avatarPath: json['avatarPath'] as String?,
        gamesJoinedMidway: json['gamesJoinedMidway'] as int? ?? 0,
        gamesLeftMidway: json['gamesLeftMidway'] as int? ?? 0,
        modeStats: (json['modeStats'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, ModeStats.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
        headToHead: (json['headToHead'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, H2HRecord.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
        ratingHistory: (json['ratingHistory'] as List<dynamic>?)
                ?.map((e) => RatingSnapshot.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
