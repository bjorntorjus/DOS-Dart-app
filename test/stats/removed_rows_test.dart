import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/profile_stats.dart';
import 'package:dart_scoring/stats/season_replay.dart';
import 'package:dart_scoring/stats/season_stats.dart';

GameHistoryEntry game(DateTime date, List<(String, int, bool)> ps) => GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl, removed) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {}, removed: removed)
      ],
    );

void main() {
  // Bo was removed (placement 0, Family-B style); Ada beat Cy.
  final history = [
    game(DateTime(2026, 8, 20), [('a', 1, false), ('b', 0, true), ('c', 2, false)]),
  ];

  test('seasonStatsFrom: removed row gets no game, active rows rank normally', () {
    final rows = seasonStatsFrom(
        history: history, start: DateTime(2026, 7, 1), end: DateTime(2026, 9, 30),
        finalRatings: const {}, names: const {});
    expect(rows.where((r) => r.playerId == 'b'), isEmpty);
    expect(rows.singleWhere((r) => r.playerId == 'a').wins, 1);
    expect(rows.singleWhere((r) => r.playerId == 'c').wins, 0);
  });

  test('replayRatings excludes removed seats (0 does not win)', () {
    final a = SavedPlayer(id: 'a', name: 'a', createdAt: DateTime(2026));
    final b = SavedPlayer(id: 'b', name: 'b', createdAt: DateTime(2026));
    final c = SavedPlayer(id: 'c', name: 'c', createdAt: DateTime(2026));
    replayRatings(history: history, players: [a, b, c]);
    expect(b.rating, 1200);
    expect(a.rating, closeTo(1216, 0.001));
    expect(c.rating, closeTo(1184, 0.001));
  });

  test('profile form skips a game the player was removed from', () {
    expect(recentForm(history, 'b'), isEmpty);
    expect(recentForm(history, 'a').single.outcome, FormOutcome.win);
    expect(recentForm(history, 'c').single.outcome, FormOutcome.loss);
  });
}
