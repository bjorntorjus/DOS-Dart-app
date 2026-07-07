import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

SavedPlayer _p() => SavedPlayer(
      id: 'p', name: 'P', createdAt: DateTime(2026),
      ratingHistory: [
        RatingSnapshot(date: DateTime(2026, 1, 1), rating: 1200, placement: 3),
        RatingSnapshot(date: DateTime(2026, 1, 2), rating: 1361, placement: 1),
        RatingSnapshot(date: DateTime(2026, 1, 3), rating: 1342, placement: 2),
      ],
      modeStats: {
        'x01': ModeStats(played: 50, won: 34, counters: {
          'highestTurn': 180, 'bestCheckout': 121, 'totalTurnScore': 2920,
          'totalTurns': 50, 'turnsOver100': 12,
        }),
        'aroundTheClock': ModeStats(played: 8, won: 4, counters: {
          'totalHits': 92, 'totalDarts': 100,
        }),
      },
      headToHead: {
        'amund': H2HRecord(wins: 14, losses: 9),
        'stian': H2HRecord(wins: 8, losses: 11), // deficit 3 → nemesis
        'bo': H2HRecord(wins: 6, losses: 3),
      },
    );

void main() {
  test('careerRecords picks max: counters and ATC hit-rate, skips unplayed', () {
    final recs = careerRecords(_p());
    final byLabel = {for (final r in recs) r.label: r};
    expect(byLabel['highest turn']!.value, '180');
    expect(byLabel['best checkout']!.value, '121');
    expect(byLabel['hit rate']!.value, '92%'); // 92/100
    expect(recs.any((r) => r.mode == 'shanghai'), isFalse); // not played
  });

  test('peakRating, bestRank, nemesis', () {
    final p = _p();
    expect(peakRating(p), 1361);
    expect(bestRank(p), 1);
    expect(nemesisId(p), 'stian'); // largest loss surplus
  });
}
