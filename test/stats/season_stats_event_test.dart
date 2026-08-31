import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/season_replay.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(DateTime date, List<(String, int)> ps,
        {String? eventId}) =>
    GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}$eventId',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
      eventId: eventId,
    );

void main() {
  final history = [
    game(DateTime(2026, 8, 20), [('a', 1), ('b', 2)]),
    game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: 'evt_1'),
    game(DateTime(2026, 8, 25, 21), [('b', 1), ('a', 2)], eventId: 'evt_1'),
    game(DateTime(2026, 8, 25, 22), [('a', 1), ('b', 2)], eventId: 'evt_other'),
  ];
  final names = {'a': 'Ada', 'b': 'Bo'};

  test('season mode skips every event game', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 9, 30),
      finalRatings: const {},
      names: names,
    );
    final a = rows.singleWhere((r) => r.playerId == 'a');
    final b = rows.singleWhere((r) => r.playerId == 'b');
    expect(a.games, 1);
    expect(a.wins, 1);
    expect(b.games, 1);
    expect(b.wins, 0);
  });

  test('event mode counts only games with that eventId', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 8, 25),
      end: DateTime(2026, 8, 26),
      finalRatings: const {'b': 1232},
      names: names,
      eventId: 'evt_1',
    );
    final a = rows.singleWhere((r) => r.playerId == 'a');
    final b = rows.singleWhere((r) => r.playerId == 'b');
    expect(b.games, 2);
    expect(b.wins, 2);
    expect(b.rating, 1232);
    expect(a.games, 2);
    expect(a.wins, 0);
  });

  test('event mode still honours the date bounds', () {
    final rows = seasonStatsFrom(
      history: history,
      start: DateTime(2026, 8, 26),
      end: DateTime(2026, 8, 27),
      finalRatings: const {},
      names: names,
      eventId: 'evt_1',
    );
    expect(rows, isEmpty);
  });

  test('replayRatings ignores event games', () {
    final a = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    final b = SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026));
    replayRatings(history: history, players: [a, b]);
    // Only the 20 Aug season game counts: a beat b once at default K.
    expect(a.rating, closeTo(1216, 0.001));
    expect(b.rating, closeTo(1184, 0.001));
  });
}
