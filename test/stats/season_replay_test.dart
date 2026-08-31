import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/season_replay.dart';

GameHistoryEntry game(String mode, DateTime date, List<(String, int)> ps) =>
    GameHistoryEntry(
      id: '$mode${date.microsecondsSinceEpoch}',
      gameMode: mode,
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
    );

List<SavedPlayer> freshPlayers() => [
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 999),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1500),
    ];

void main() {
  group('quarter arithmetic', () {
    test('quarters start in January, April, July and October', () {
      expect(quarterStart(DateTime(2026, 8, 11)), DateTime(2026, 7, 1));
      expect(quarterStart(DateTime(2026, 1, 1)), DateTime(2026, 1, 1));
      expect(quarterStart(DateTime(2026, 12, 31)), DateTime(2026, 10, 1));
      expect(quarterStart(DateTime(2026, 4, 22)), DateTime(2026, 4, 1));
    });

    test('the next quarter rolls the year at the end of December', () {
      expect(nextQuarterStart(DateTime(2026, 8, 11)), DateTime(2026, 10, 1));
      expect(nextQuarterStart(DateTime(2026, 11, 2)), DateTime(2027, 1, 1));
    });
  });

  group('replay', () {
    test('every player starts from 1200, whatever they held before', () {
      final players = freshPlayers();
      replayRatings(history: const [], players: players);
      expect(players.every((p) => p.rating == 1200), isTrue);
    });

    test('a rated game moves the winner up and the loser down', () {
      final players = freshPlayers();
      replayRatings(
        history: [game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)])],
        players: players,
      );
      expect(players[0].rating, greaterThan(1200));
      expect(players[1].rating, lessThan(1200));
    });

    test('unrated games leave everyone at 1200', () {
      final players = freshPlayers();
      replayRatings(
        history: [
          game('killer', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
          game('wildcard', DateTime(2026, 5, 2), [('a', 1), ('b', 2)]),
        ],
        players: players,
      );
      expect(players.every((p) => p.rating == 1200), isTrue);
    });

    test('date order decides the outcome, not storage order', () {
      // History is stored newest-first, and Elo is order-dependent.
      final chronological = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('x01', DateTime(2026, 5, 2), [('b', 1), ('a', 2)]),
        game('x01', DateTime(2026, 5, 3), [('a', 1), ('b', 2)]),
      ];
      final forward = freshPlayers();
      replayRatings(history: chronological, players: forward);

      final reversed = freshPlayers();
      replayRatings(
          history: chronological.reversed.toList(), players: reversed);

      expect(reversed[0].rating, closeTo(forward[0].rating, 0.000001));
    });

    test('replaying twice gives the same answer', () {
      final history = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('cricket_cutthroat', DateTime(2026, 5, 2), [('b', 1), ('a', 2)]),
      ];
      final first = freshPlayers();
      replayRatings(history: history, players: first);
      final second = freshPlayers();
      replayRatings(history: history, players: second);
      expect(second[0].rating, first[0].rating);
    });

    test('from and to slice the history', () {
      final history = [
        game('x01', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
        game('x01', DateTime(2026, 7, 4), [('a', 1), ('b', 2)]),
      ];
      final onlyJuly = freshPlayers();
      replayRatings(
          history: history, players: onlyJuly, from: DateTime(2026, 7, 1));

      final both = freshPlayers();
      replayRatings(history: history, players: both);

      expect(onlyJuly[0].rating, lessThan(both[0].rating),
          reason: 'one win moves less than two');
    });

    test('the to bound is inclusive of its whole day', () {
      final history = [
        game('x01', DateTime(2026, 6, 30, 23, 59), [('a', 1), ('b', 2)]),
      ];
      final players = freshPlayers();
      replayRatings(
          history: history, players: players, to: DateTime(2026, 6, 30));
      expect(players[0].rating, greaterThan(1200),
          reason: 'a game late on the final day still belongs to the season');
    });
  });
}
