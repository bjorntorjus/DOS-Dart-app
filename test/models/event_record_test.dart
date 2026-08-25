import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/season.dart';

SeasonPlayerRow row(String id, double rating, {int games = 1, int wins = 0}) =>
    SeasonPlayerRow(
      playerId: id,
      name: id,
      rating: rating,
      games: games,
      wins: wins,
      dartsThrown: 0,
      dartsHit: 0,
      gamesWithThrows: 0,
    );

void main() {
  test('open event: isOpen, no rows, no winner', () {
    final e = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: {'a': 1310, 'b': 1090},
    );
    expect(e.isOpen, isTrue);
    expect(e.rows, isEmpty);
    expect(e.winnerName, isNull);
  });

  test('ranked ignores the season qualifying threshold — one game is enough',
      () {
    final e = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      end: DateTime(2026, 8, 25, 23),
      savedRatings: const {},
      rows: [
        row('a', 1216, games: 1),
        row('b', 1184, games: 1),
        row('c', 1216, games: 2)
      ],
    );
    // Rating desc, ties on name.
    expect(e.ranked.map((r) => r.playerId), ['a', 'c', 'b']);
    expect(e.winnerName, 'a');
    expect(e.isOpen, isFalse);
  });

  test('JSON round-trip keeps savedRatings, rows and a null end', () {
    final open = EventRecord(
      id: 'evt_1',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: {'a': 1310.5},
    );
    final back = EventRecord.fromJson(
        jsonDecode(jsonEncode(open.toJson())) as Map<String, dynamic>);
    expect(back.id, 'evt_1');
    expect(back.name, 'Jobbfest 2026');
    expect(back.end, isNull);
    expect(back.savedRatings, {'a': 1310.5});

    final closed =
        open.copyWith(end: DateTime(2026, 8, 25, 23), rows: [row('a', 1250)]);
    final back2 = EventRecord.fromJson(
        jsonDecode(jsonEncode(closed.toJson())) as Map<String, dynamic>);
    expect(back2.end, DateTime(2026, 8, 25, 23));
    expect(back2.rows.single.rating, 1250);
    // copyWith never touches identity or the snapshot.
    expect(back2.id, 'evt_1');
    expect(back2.savedRatings, {'a': 1310.5});
  });
}
