import '../models/saved_player.dart';

class RankPoint {
  const RankPoint({required this.date, required this.rating, required this.rank});

  final DateTime date;
  final double rating;
  final int rank;
}

/// Leaderboard rank of [player] at each of their rating snapshots, derived
/// from every player's existing history — no stored placement needed, so the
/// whole timeline gets ranks retroactively. An opponent's rating at time T is
/// their latest snapshot with date <= T; opponents with no snapshot yet are
/// not on the board at T. Ties share the better rank (count strictly greater).
List<RankPoint> deriveRankHistory(
    SavedPlayer player, List<SavedPlayer> allPlayers) {
  final others = allPlayers.where((p) => p.id != player.id).toList();
  return [
    for (final s in player.ratingHistory)
      RankPoint(
        date: s.date,
        rating: s.rating,
        rank: 1 +
            others.where((o) {
              RatingSnapshot? latest;
              for (final os in o.ratingHistory) {
                if (!os.date.isAfter(s.date)) latest = os;
              }
              return latest != null && latest.rating > s.rating;
            }).length,
      ),
  ];
}
