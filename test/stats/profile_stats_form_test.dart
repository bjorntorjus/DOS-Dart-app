import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

GameHistoryEntry _g(String id, DateTime d, List<(String pid, int place, double db, double da)> ps) =>
    GameHistoryEntry(
      id: id, gameMode: 'x01', date: d,
      players: [
        for (final (pid, place, db, da) in ps)
          GameHistoryPlayer(
              name: pid, savedPlayerId: pid, placement: place,
              stats: const {}, ratingBefore: db, ratingAfter: da),
      ],
    );

void main() {
  test('recentForm returns newest-first W/L/draw with ΔELO', () {
    final history = [
      _g('1', DateTime(2026, 1, 1), [('me', 1, 1000, 1010), ('x', 2, 1000, 990)]),
      _g('2', DateTime(2026, 1, 2), [('me', 2, 1010, 1003), ('x', 1, 990, 998)]),
      _g('3', DateTime(2026, 1, 3), [('me', 1, 1003, 1003), ('x', 1, 998, 998)]), // shared 1st = draw
    ];
    final form = recentForm(history, 'me', limit: 8);
    expect(form.map((f) => f.outcome).toList(),
        [FormOutcome.draw, FormOutcome.loss, FormOutcome.win]); // newest first
    expect(form.first.ratingDelta, 0); // 1003→1003
    expect(form.last.ratingDelta, 10); // 1000→1010
  });

  test('recentForm skips games the player did not play and honours limit', () {
    final history = [
      for (var i = 0; i < 12; i++)
        _g('$i', DateTime(2026, 1, 1).add(Duration(days: i)),
            [('me', 1, 1000, 1005), ('x', 2, 1000, 995)]),
      _g('z', DateTime(2026, 2, 1), [('other', 1, 1000, 1005)]), // me absent
    ];
    final form = recentForm(history, 'me', limit: 8);
    expect(form.length, 8);
    expect(form.every((f) => f.outcome == FormOutcome.win), isTrue);
  });
}
