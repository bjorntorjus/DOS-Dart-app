import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/season_service.dart';

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

Future<void> seed({int juneGames = 12, int julyGames = 12}) async {
  await PlayerStorage.savePlayers([
    SavedPlayer(
        id: 'a',
        name: 'Ada',
        createdAt: DateTime(2026),
        rating: 1310,
        gamesPlayed: 40,
        gamesWon: 20)
      ..unlockedAchievementIds.add('x_natural_talent'),
    SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1090),
  ]);
  for (var i = 0; i < juneGames; i++) {
    await GameHistoryService.record(
        game('x01', DateTime(2026, 5, 1 + i), [('a', 1), ('b', 2)]));
  }
  for (var i = 0; i < julyGames; i++) {
    await GameHistoryService.record(
        game('x01', DateTime(2026, 7, 1 + i), [('b', 1), ('a', 2)]));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migration refuses to run until a backup exists', () async {
    await seed();
    expect(await SeasonService.needsMigration(), isTrue);
    await expectLater(SeasonService.migrate(), throwsA(isA<StateError>()));
    expect(await SeasonService.loadSeasons(), isEmpty);
  });

  test('migration builds an all-time row plus season 1', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final seasons = await SeasonService.loadSeasons();

    expect(seasons.map((s) => s.number), [0, 1]);
    expect(seasons.first.rows.firstWhere((r) => r.playerId == 'a').rating, 1310,
        reason: 'the all-time row preserves the pre-migration rating');
    expect(seasons.last.start, DateTime(2026, 5, 1),
        reason: 'season 1 starts at the oldest surviving game');
    expect(seasons.last.end, DateTime(2026, 6, 30));
  });

  test('season 2 is left open and is the live rating', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();

    expect(await AppSettings.getSeasonNumber(), 2);
    expect(await AppSettings.getSeasonStart(), DateTime(2026, 7, 1));
    // Bo won every July game, so Bo leads the open season.
    final players = await PlayerStorage.loadPlayers();
    final bo = players.firstWhere((p) => p.id == 'b');
    final ada = players.firstWhere((p) => p.id == 'a');
    expect(bo.rating, greaterThan(ada.rating));
  });

  test('a reset writes rating and nothing else', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final ada =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'a');

    expect(ada.gamesPlayed, 40, reason: 'lifetime counters are untouched');
    expect(ada.gamesWon, 20);
    expect(ada.unlockedAchievementIds, contains('x_natural_talent'),
        reason: 'unlocks are never revoked by a reset');
  });

  test('migrating twice changes nothing', () async {
    await seed();
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();
    final after = await SeasonService.loadSeasons();
    final rating = (await PlayerStorage.loadPlayers())
        .firstWhere((p) => p.id == 'a')
        .rating;

    await SeasonService.migrate();

    expect((await SeasonService.loadSeasons()).length, after.length);
    expect(
        (await PlayerStorage.loadPlayers())
            .firstWhere((p) => p.id == 'a')
            .rating,
        rating);
    expect(await SeasonService.needsMigration(), isFalse);
  });

  test('an empty history migrates without throwing', () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026))]);
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();

    expect((await PlayerStorage.loadPlayers()).single.rating, 1200);
  });

  group('closing on a boundary', () {
    Future<void> migrated() async {
      await seed();
      await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));
      await SeasonService.migrate();
    }

    test('a season inside its own quarter does not close', () async {
      await migrated();
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 9, 30, 23)),
          isFalse);
      expect(await AppSettings.getSeasonNumber(), 2);
    });

    test('crossing into the next quarter closes it, once', () async {
      await migrated();

      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 1)),
          isTrue);
      expect(await AppSettings.getSeasonNumber(), 3);
      expect(
          (await SeasonService.loadSeasons()).map((s) => s.number), [0, 1, 2]);
      expect(
          (await PlayerStorage.loadPlayers()).every((p) => p.rating == 1200),
          isTrue);

      // Opening the app again must not close a second time.
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)),
          isFalse);
      expect((await SeasonService.loadSeasons()).length, 3);
    });

    test('the closed season carries the games played inside it', () async {
      await migrated();
      await SeasonService.closeDueSeason(now: DateTime(2026, 10, 1));

      final s2 =
          (await SeasonService.loadSeasons()).firstWhere((s) => s.number == 2);
      expect(s2.rows.firstWhere((r) => r.playerId == 'b').games, 12);
      expect(s2.rows.firstWhere((r) => r.playerId == 'b').wins, 12);
    });
  });
}
