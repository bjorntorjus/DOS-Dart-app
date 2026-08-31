/// A season is ranked on rating, but only among players who played enough for
/// the number to mean anything. Two games leaves a 60 %-winner at ~1207 and a
/// 20 %-winner at ~1195 — indistinguishable, yet mid-table if ranked.
const int kSeasonQualifyingGames = 10;

/// One player's figures for one season.
///
/// Every derived percentage is nullable, and null means *unknown* rather than
/// zero. That distinction is load-bearing for the retroactive seasons: throws
/// were not stored with a game before 18 June 2026, so a season can genuinely
/// have no idea what someone's hit rate was — which is not the same as saying
/// they missed everything.
class SeasonPlayerRow {
  const SeasonPlayerRow({
    required this.playerId,
    required this.name,
    required this.rating,
    required this.games,
    required this.wins,
    required this.dartsThrown,
    required this.dartsHit,
    required this.gamesWithThrows,
  });

  final String playerId;
  final String name;
  final double rating;
  final int games;
  final int wins;
  final int dartsThrown;
  final int dartsHit;

  /// How many of [games] had their throws stored. Zero means [hitPercent] is
  /// unknowable for this season, not that nothing was hit.
  final int gamesWithThrows;

  bool get qualified => games >= kSeasonQualifyingGames;

  double? get winPercent => games == 0 ? null : 100 * wins / games;

  double? get hitPercent =>
      gamesWithThrows == 0 || dartsThrown == 0 ? null : 100 * dartsHit / dartsThrown;

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'rating': rating,
        'games': games,
        'wins': wins,
        'dartsThrown': dartsThrown,
        'dartsHit': dartsHit,
        'gamesWithThrows': gamesWithThrows,
      };

  factory SeasonPlayerRow.fromJson(Map<String, dynamic> json) =>
      SeasonPlayerRow(
        playerId: json['playerId'] as String,
        name: json['name'] as String,
        rating: (json['rating'] as num).toDouble(),
        games: json['games'] as int,
        wins: json['wins'] as int,
        dartsThrown: json['dartsThrown'] as int? ?? 0,
        dartsHit: json['dartsHit'] as int? ?? 0,
        gamesWithThrows: json['gamesWithThrows'] as int? ?? 0,
      );
}

/// A closed season's final table.
///
/// Number 0 is reserved for the `all-time` record written just before the
/// seasons migration — the ratings as they stood after every game ever played,
/// preserved because they cannot be reconstructed once the reset lands.
class SeasonRecord {
  const SeasonRecord({
    required this.number,
    required this.start,
    required this.end,
    required this.rows,
  });

  final int number;
  final DateTime start;
  final DateTime end;
  final List<SeasonPlayerRow> rows;

  bool get isAllTime => number == 0;

  /// Qualified players, best rating first. Ties break on name so a rebuild
  /// produces the same order every time — `List.sort` gives no such promise
  /// on its own.
  List<SeasonPlayerRow> get ranked {
    final out = rows.where((r) => r.qualified).toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.name.compareTo(b.name);
      });
    return out;
  }

  /// Everyone who did not play enough, most games first. Shown below the
  /// table with their progress, never given a rank.
  List<SeasonPlayerRow> get unqualified {
    final out = rows.where((r) => !r.qualified).toList()
      ..sort((a, b) {
        final byGames = b.games.compareTo(a.games);
        return byGames != 0 ? byGames : a.name.compareTo(b.name);
      });
    return out;
  }

  String? get winnerName => ranked.isEmpty ? null : ranked.first.name;

  Map<String, dynamic> toJson() => {
        'number': number,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        number: json['number'] as int,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        rows: (json['rows'] as List)
            .map((r) => SeasonPlayerRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

/// What a season close hands the achievement evaluator: one player's row plus
/// the context that only makes sense across seasons.
class SeasonStanding {
  const SeasonStanding({
    required this.season,
    required this.row,
    required this.rank,
    required this.previousRank,
    required this.seasonsWon,
    required this.podiums,
    required this.isFirstSeason,
    required this.qualifiedOnFinalDay,
  });

  final SeasonRecord season;
  final SeasonPlayerRow row;

  /// 1-based place among the qualified, or null when this player was not.
  final int? rank;

  /// The player's rank in the previous season, or null when they have none.
  final int? previousRank;

  /// Seasons this player has won, including this one.
  final int seasonsWon;

  /// Seasons this player finished in the top three, including this one.
  final int podiums;

  final bool isFirstSeason;

  /// True when the qualifying (tenth) game landed on the season's last day.
  final bool qualifiedOnFinalDay;

  /// Points between this player and the next one down, or null when they are
  /// not ranked first or there is nobody below them.
  double? get leadOverSecond {
    final r = season.ranked;
    if (rank != 1 || r.length < 2) return null;
    return r.first.rating - r[1].rating;
  }
}
