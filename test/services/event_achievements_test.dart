import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/services/achievement_service.dart';

SeasonPlayerRow row(String id, double rating, {int games = 1}) =>
    SeasonPlayerRow(
        playerId: id,
        name: id,
        rating: rating,
        games: games,
        wins: 0,
        dartsThrown: 0,
        dartsHit: 0,
        gamesWithThrows: 0);

EventRecord event(List<SeasonPlayerRow> rows,
        {Map<String, double> saved = const {}}) =>
    EventRecord(
        id: 'evt',
        name: 'Jobbfest 2026',
        start: DateTime(2026, 8, 25, 19),
        end: DateTime(2026, 8, 25, 23),
        savedRatings: saved,
        rows: rows);

Set<String> idsFor(EventStanding s) =>
    AchievementService.forTest(achievementCatalog)
        .evaluateEventClose(
            SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)), s)
        .map((a) => a.id)
        .toSet();

EventStanding standing({
  required EventRecord event,
  required SeasonPlayerRow row,
  required int rank,
  int eventsWon = 0,
  bool isFirstEvent = false,
  double? seasonRatingAtStart,
}) =>
    EventStanding(
        event: event,
        row: row,
        rank: rank,
        eventsWon: eventsWon,
        isFirstEvent: isFirstEvent,
        seasonRatingAtStart: seasonRatingAtStart);

void main() {
  final three = event([row('a', 1260), row('b', 1200), row('c', 1140)]);

  test('LIFE OF THE PARTY for the winner, DESIGNATED DRIVER for second', () {
    final winner = idsFor(
        standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1));
    expect(winner, contains('x_event_champion'));
    expect(winner, isNot(contains('x_event_serial')));
    final second = idsFor(standing(event: three, row: three.rows[1], rank: 2));
    expect(second, contains('x_event_runner_up'));
    expect(second, isNot(contains('x_event_champion')));
  });

  test('SERIAL PARTIER needs a second win', () {
    expect(
        idsFor(
            standing(event: three, row: three.rows[0], rank: 1, eventsWon: 2)),
        contains('x_event_serial'));
  });

  test('PARTY CRASHER: won while below 1200 in the season', () {
    expect(
        idsFor(standing(
            event: three,
            row: three.rows[0],
            rank: 1,
            eventsWon: 1,
            seasonRatingAtStart: 1150)),
        contains('x_event_crasher'));
    expect(
        idsFor(standing(
            event: three,
            row: three.rows[0],
            rank: 1,
            eventsWon: 1,
            seasonRatingAtStart: 1250)),
        isNot(contains('x_event_crasher')));
    // Created mid-event → no season rating → not an underdog story.
    expect(
        idsFor(
            standing(event: three, row: three.rows[0], rank: 1, eventsWon: 1)),
        isNot(contains('x_event_crasher')));
  });

  test('CLOSING TIME at 8 games, not 7', () {
    expect(
        idsFor(standing(event: three, row: row('a', 1200, games: 8), rank: 2)),
        contains('x_event_closing_time'));
    expect(
        idsFor(standing(event: three, row: row('a', 1200, games: 7), rank: 2)),
        isNot(contains('x_event_closing_time')));
  });

  test('WALLFLOWER: last of three, but not last of two', () {
    expect(idsFor(standing(event: three, row: three.rows[2], rank: 3)),
        contains('x_event_wallflower'));
    final two = event([row('a', 1216), row('b', 1184)]);
    expect(idsFor(standing(event: two, row: two.rows[1], rank: 2)),
        isNot(contains('x_event_wallflower')));
  });

  test('PLUS ONE on the first event only', () {
    expect(
        idsFor(standing(
            event: three, row: three.rows[1], rank: 2, isFirstEvent: true)),
        contains('x_event_plus_one'));
    expect(idsFor(standing(event: three, row: three.rows[1], rank: 2)),
        isNot(contains('x_event_plus_one')));
  });

  test('event badges stay inert without an event standing', () {
    final ctx = AchievementContext(
        player: SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)));
    for (final a
        in achievementCatalog.where((a) => a.id.startsWith('x_event_'))) {
      expect(a.milestoneTest!(ctx), isFalse, reason: a.id);
    }
  });
}
