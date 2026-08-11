import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/season.dart';

SeasonPlayerRow row(String name, double rating, int games,
        {int wins = 0, int thrown = 0, int hit = 0, int withThrows = 0}) =>
    SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: thrown,
      dartsHit: hit,
      gamesWithThrows: withThrows,
    );

void main() {
  test('qualification is 10 games in the season', () {
    expect(row('A', 1200, 9).qualified, isFalse);
    expect(row('A', 1200, 10).qualified, isTrue);
  });

  test('win percent is null with no games, never a fake zero', () {
    expect(row('A', 1200, 0).winPercent, isNull);
    expect(row('A', 1200, 4, wins: 1).winPercent, 25.0);
  });

  test('hit percent is null when no game in the season stored its throws', () {
    expect(row('A', 1200, 20, thrown: 0, hit: 0, withThrows: 0).hitPercent,
        isNull,
        reason: 'retroactive seasons must say "unknown", not "0 %"');
    expect(
        row('A', 1200, 20, thrown: 200, hit: 150, withThrows: 20).hitPercent,
        75.0);
  });

  test('ranked holds only qualified rows, best rating first', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Low', 1150, 20), row('High', 1290, 20), row('Guest', 1400, 3)],
    );

    expect(s.ranked.map((r) => r.name), ['High', 'Low']);
    expect(s.unqualified.map((r) => r.name), ['Guest'],
        reason: 'a 3-game player must not outrank regulars on a noisy number');
    expect(s.winnerName, 'High');
  });

  test('equal ratings order by name so a rebuild is stable', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Zoe', 1200, 12), row('Adam', 1200, 12)],
    );
    for (var i = 0; i < 10; i++) {
      expect(s.ranked.map((r) => r.name), ['Adam', 'Zoe']);
    }
  });

  test('a season nobody qualified in has no winner', () {
    final s = SeasonRecord(
      number: 1,
      start: DateTime(2026, 4, 22),
      end: DateTime(2026, 6, 30),
      rows: [row('Guest', 1400, 2)],
    );
    expect(s.ranked, isEmpty);
    expect(s.winnerName, isNull);
  });

  test('a season round-trips through JSON', () {
    final s = SeasonRecord(
      number: 2,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 9, 30),
      rows: [
        row('A', 1276.5, 35, wins: 18, thrown: 400, hit: 310, withThrows: 35)
      ],
    );

    final back = SeasonRecord.fromJson(s.toJson());

    expect(back.number, 2);
    expect(back.start, DateTime(2026, 7, 1));
    expect(back.rows.single.rating, 1276.5);
    expect(back.rows.single.hitPercent, closeTo(77.5, 0.01));
  });
}
