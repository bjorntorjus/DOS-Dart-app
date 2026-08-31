import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/season.dart';
import 'package:dart_scoring/services/achievement_service.dart';

SeasonPlayerRow row(String name, double rating, int games) => SeasonPlayerRow(
      playerId: name.toLowerCase(),
      name: name,
      rating: rating,
      games: games,
      wins: 0,
      dartsThrown: 0,
      dartsHit: 0,
      gamesWithThrows: 0,
    );

SeasonRecord season(int n, List<SeasonPlayerRow> rows) => SeasonRecord(
    number: n,
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 9, 30),
    rows: rows);

SavedPlayer player() =>
    SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));

Set<String> idsFor(SeasonStanding s) => AchievementService.forTest(
        achievementCatalog)
    .evaluateSeasonClose(player(), s)
    .map((a) => a.id)
    .toSet();

SeasonStanding standing({
  required SeasonRecord season,
  required SeasonPlayerRow row,
  int? rank,
  int? previousRank,
  int seasonsWon = 0,
  int podiums = 0,
  bool isFirstSeason = false,
  bool qualifiedOnFinalDay = false,
}) =>
    SeasonStanding(
      season: season,
      row: row,
      rank: rank,
      previousRank: previousRank,
      seasonsWon: seasonsWon,
      podiums: podiums,
      isFirstSeason: isFirstSeason,
      qualifiedOnFinalDay: qualifiedOnFinalDay,
    );

void main() {
  final winner = row('Ada', 1300, 20);
  final second = row('Bo', 1180, 20);

  test('winning a season unlocks the champion badge', () {
    final ids = idsFor(standing(
      season: season(2, [winner, second]),
      row: winner,
      rank: 1,
      seasonsWon: 1,
      podiums: 1,
    ));
    expect(ids, contains('x_season_champion'));
    expect(ids, isNot(contains('x_season_almost_famous')));
  });

  test('DYNASTY needs two in a row, not just two ever', () {
    // Winning this season and the previous one IS the definition — seasonsWon
    // is a lifetime count and cannot tell "in a row" from "twice, apart".
    SeasonStanding s(int? prev, {int won = 2}) => standing(
        season: season(2, [winner, second]),
        row: winner,
        rank: 1,
        previousRank: prev,
        seasonsWon: won,
        podiums: won);
    expect(idsFor(s(1)), contains('x_season_dynasty'));
    expect(idsFor(s(4)), isNot(contains('x_season_dynasty')),
        reason: 'won twice, but not back to back');
    expect(idsFor(s(null, won: 1)), isNot(contains('x_season_dynasty')),
        reason: 'a first season cannot be a dynasty');
  });

  test('UNTOUCHABLE needs a 100-point lead', () {
    SeasonStanding s(double runnerUp) => standing(
        season: season(2, [winner, row('Bo', runnerUp, 20)]),
        row: winner,
        rank: 1,
        seasonsWon: 1,
        podiums: 1);
    expect(idsFor(s(1180)), contains('x_season_untouchable'));
    expect(idsFor(s(1250)), isNot(contains('x_season_untouchable')));
  });

  test('THE CLIMB needs three places and a previous season', () {
    SeasonStanding s(int? prev) => standing(
        season: season(2, [winner, second]), row: winner, rank: 1,
        previousRank: prev);
    expect(idsFor(s(4)), contains('x_season_climb'));
    expect(idsFor(s(3)), isNot(contains('x_season_climb')));
    expect(idsFor(s(null)), isNot(contains('x_season_climb')),
        reason: 'a first season has nothing to climb from');
  });

  test('NINE AND OUT is exactly nine, and GHOST covers the rest', () {
    Set<String> at(int games) {
      final r = row('Ada', 1200, games);
      return idsFor(standing(season: season(2, [r]), row: r));
    }

    expect(at(8), isNot(contains('x_season_nine_and_out')));
    expect(at(9), contains('x_season_nine_and_out'));
    expect(at(9), contains('x_season_ghost'));
    expect(at(10), isNot(contains('x_season_nine_and_out')));
    expect(at(10), isNot(contains('x_season_ghost')));
    expect(at(0), isNot(contains('x_season_ghost')),
        reason: 'someone who never played did not haunt the season');
  });

  test('IRON ARM at 40 games, ROOKIE SEASON on a qualified first', () {
    final busy = row('Ada', 1200, 40);
    expect(idsFor(standing(season: season(2, [busy]), row: busy, rank: 1)),
        contains('x_season_iron_arm'));

    final rookie = row('Ada', 1200, 12);
    expect(
        idsFor(standing(
            season: season(1, [rookie]),
            row: rookie,
            rank: 1,
            isFirstSeason: true)),
        contains('x_season_rookie'));
  });

  test('PARTICIPATION TROPHY is last among the qualified, not last overall',
      () {
    final last = row('Ada', 1100, 20);
    final ids = idsFor(standing(
        season: season(2, [winner, second, last]), row: last, rank: 3));
    expect(ids, contains('x_season_participation'));

    // A lone qualified player is not "last" in any meaningful sense.
    final alone = row('Ada', 1200, 20);
    expect(
        idsFor(standing(season: season(2, [alone]), row: alone, rank: 1)),
        isNot(contains('x_season_participation')));
  });

  test('season badges cannot fire at game end', () {
    // ctx.season is null there, so every season test must return false.
    for (final a in achievementCatalog.where((a) => a.id.startsWith('x_season_'))) {
      expect(a.milestoneTest!(AchievementContext(player: player())), isFalse,
          reason: a.id);
    }
  });

  test('the rating badges were recalibrated to the season range', () {
    Achievement byId(String id) =>
        achievementCatalog.firstWhere((a) => a.id == id);
    bool fires(String id, double rating) => byId(id).milestoneTest!(
        AchievementContext(
            player: SavedPlayer(
                id: 'a', name: 'A', createdAt: DateTime(2026), rating: rating)));

    expect(fires('x_master', 1400), isTrue);
    expect(fires('x_master', 1399), isFalse);
    expect(fires('x_grandmaster', 1450), isTrue);
    expect(fires('x_grandmaster', 1449), isFalse);
    expect(fires('x_the_floor', 1100), isTrue);
    expect(fires('x_the_floor', 1101), isFalse);
  });

  test('every season badge has a unique name and no mode suffix', () {
    final seasonBadges =
        achievementCatalog.where((a) => a.id.startsWith('x_season_')).toList();
    expect(seasonBadges.length, 12);
    expect(seasonBadges.map((a) => a.name).toSet().length, 12);
    final allNames = achievementCatalog.map((a) => a.name).toList();
    expect(allNames.toSet().length, allNames.length,
        reason: 'names are globally unique — no "(mode)" dupes');
  });

  test('an already-held badge is not handed out twice', () {
    final p = player()..unlockedAchievementIds.add('x_season_champion');
    final held = AchievementService.forTest(achievementCatalog)
        .evaluateSeasonClose(
            p,
            standing(
                season: season(2, [winner, second]), row: winner, rank: 1,
                seasonsWon: 1, podiums: 1))
        .map((a) => a.id);
    expect(held, isNot(contains('x_season_champion')));
  });
}
