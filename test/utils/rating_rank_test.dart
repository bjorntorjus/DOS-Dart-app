import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/utils/rating_rank.dart';

SavedPlayer _p(String id, List<(DateTime, double)> hist) {
  final p = SavedPlayer(id: id, name: id, createdAt: DateTime(2026, 1, 1));
  for (final (d, r) in hist) {
    p.ratingHistory.add(RatingSnapshot(date: d, rating: r));
  }
  return p;
}

void main() {
  final t1 = DateTime(2026, 6, 1),
      t2 = DateTime(2026, 6, 2),
      t3 = DateTime(2026, 6, 3);

  test('rank rises when passing an opponent and falls when passed', () {
    final a = _p('a', [(t1, 1000), (t2, 1060), (t3, 1040)]);
    final b = _p('b', [(t1, 1050), (t2, 1050), (t3, 1050)]);
    final ranks = deriveRankHistory(a, [a, b]).map((r) => r.rank).toList();
    expect(ranks, [2, 1, 2]);
  });

  test('opponents without any snapshot yet are excluded at that point', () {
    final a = _p('a', [(t1, 1000)]);
    final b = _p('b', [(t3, 1100)]); // b starts later
    expect(deriveRankHistory(a, [a, b]).first.rank, 1);
  });

  test('equal rating shares the better rank', () {
    final a = _p('a', [(t1, 1000)]);
    final b = _p('b', [(t1, 1000)]);
    expect(deriveRankHistory(a, [a, b]).first.rank, 1);
  });
}
