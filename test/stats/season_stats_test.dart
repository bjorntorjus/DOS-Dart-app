import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(
  String mode,
  DateTime date,
  List<(String id, int placement)> players, {
  List<DartThrow>? throws,
}) =>
    GameHistoryEntry(
      id: '${mode}_${date.microsecondsSinceEpoch}',
      gameMode: mode,
      date: date,
      players: [
        for (final (id, placement) in players)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: placement, stats: const {})
      ],
      throwHistory: throws,
    );

DartThrow dart(int seat, int mult) => DartThrow(
      playerIndex: seat,
      segment: mult == 0 ? 0 : 20,
      multiplier: mult,
      points: 20 * mult,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
    );

void main() {
  final start = DateTime(2026, 4, 22);
  final end = DateTime(2026, 6, 30);
  final names = {'a': 'Ada', 'b': 'Bo'};
  final ratings = {'a': 1250.0, 'b': 1150.0};

  List<SeasonPlayerRow> run(List<GameHistoryEntry> h) => seasonStatsFrom(
      history: h, start: start, end: end, finalRatings: ratings, names: names);

  test('only games inside the range count', () {
    final rows = run([
      game('x01', DateTime(2026, 4, 21), [('a', 1), ('b', 2)]),
      game('x01', DateTime(2026, 5, 10), [('a', 1), ('b', 2)]),
      game('x01', DateTime(2026, 7, 2), [('a', 1), ('b', 2)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 1);
  });

  test('the range is inclusive on both days', () {
    final rows = run([
      game('x01', DateTime(2026, 4, 22, 9), [('a', 1), ('b', 2)]),
      game('x01', DateTime(2026, 6, 30, 23), [('a', 1), ('b', 2)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 2);
  });

  test('unrated modes are skipped, both cricket keys are kept', () {
    final rows = run([
      game('killer', DateTime(2026, 5, 1), [('a', 1), ('b', 2)]),
      game('wildcard', DateTime(2026, 5, 2), [('a', 1), ('b', 2)]),
      game('cricket', DateTime(2026, 5, 3), [('a', 1), ('b', 2)]),
      game('cricket_cutthroat', DateTime(2026, 5, 4), [('a', 1), ('b', 2)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 2);
  });

  test('a shared best placement is a draw, not a win for either', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 5), [('a', 1), ('b', 1)]),
    ]);
    expect(rows.firstWhere((r) => r.playerId == 'a').games, 1);
    expect(rows.firstWhere((r) => r.playerId == 'a').wins, 0);
    expect(rows.firstWhere((r) => r.playerId == 'b').wins, 0);
  });

  test('darts count from stored throws, a hit is multiplier > 0', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 6), [('a', 1), ('b', 2)],
          throws: [dart(0, 3), dart(0, 0), dart(1, 1)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.dartsThrown, 2);
    expect(a.dartsHit, 1);
    expect(a.gamesWithThrows, 1);
    expect(a.hitPercent, 50.0);
  });

  test('a season with no stored throws reports an unknown hit rate', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 7), [('a', 1), ('b', 2)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.gamesWithThrows, 0);
    expect(a.hitPercent, isNull,
        reason: 'season 1 has no throws before 18 June — unknown, not 0 %');
  });

  test('guests without a saved id contribute nothing', () {
    final rows = run([
      GameHistoryEntry(
        id: 'g',
        gameMode: 'x01',
        date: DateTime(2026, 5, 8),
        players: [
          GameHistoryPlayer(name: 'Guest', placement: 1, stats: const {}),
          GameHistoryPlayer(
              name: 'Ada', savedPlayerId: 'a', placement: 2, stats: const {}),
        ],
      ),
    ]);
    expect(rows.map((r) => r.playerId), ['a']);
    expect(rows.single.wins, 0);
  });

  test('rows carry the final rating and display name', () {
    final rows = run([
      game('x01', DateTime(2026, 5, 9), [('a', 1), ('b', 2)]),
    ]);
    final a = rows.firstWhere((r) => r.playerId == 'a');
    expect(a.rating, 1250.0);
    expect(a.name, 'Ada');
  });

  test('a player with no rating on file falls back to 1200', () {
    final rows = seasonStatsFrom(
      history: [
        game('x01', DateTime(2026, 5, 9), [('a', 1), ('zz', 2)]),
      ],
      start: start,
      end: end,
      finalRatings: ratings,
      names: names,
    );
    final zz = rows.firstWhere((r) => r.playerId == 'zz');
    expect(zz.rating, 1200);
    expect(zz.name, 'zz', reason: 'an unknown id falls back to itself');
  });
}
