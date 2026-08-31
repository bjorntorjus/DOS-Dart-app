import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/season_service.dart';

GameHistoryEntry game(DateTime date, List<(String, int)> ps) =>
    GameHistoryEntry(
      id: 'g${date.microsecondsSinceEpoch}',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AchievementService.instance.registerCatalog(achievementCatalog);
  });

  /// A migrated install with Ada winning June and Bo winning July.
  Future<void> seed() async {
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026)),
    ]);
    for (var i = 0; i < 12; i++) {
      await GameHistoryService.record(
          game(DateTime(2026, 5, 1 + i), [('a', 1), ('b', 2)]));
    }
    for (var i = 0; i < 12; i++) {
      await GameHistoryService.record(
          game(DateTime(2026, 7, 1 + i), [('b', 1), ('a', 2)]));
    }
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));
  }

  test('the migration awards the seasons it just closed', () async {
    await seed();

    await SeasonService.migrate();

    final ada =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'a');
    expect(ada.unlockedAchievementIds, contains('x_season_champion'),
        reason: 'Ada won season 1, which the migration closed');
    expect(ada.unlockedAchievementIds, contains('x_season_rookie'),
        reason: 'season 1 was her first, and she qualified');
  });

  test('the loser of a season gets the loser badge, not the champion one',
      () async {
    await seed();

    await SeasonService.migrate();

    final bo =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'b');
    expect(bo.unlockedAchievementIds, isNot(contains('x_season_champion')));
    expect(bo.unlockedAchievementIds, contains('x_season_almost_famous'),
        reason: 'Bo came second in season 1');
  });

  test('closing a quarter awards it too', () async {
    await seed();
    await SeasonService.migrate();

    // Season 2 (Q3) is open and Bo leads it. Closing Q3 should crown Bo.
    await SeasonService.closeDueSeason(now: DateTime(2026, 10, 1));

    final bo =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'b');
    expect(bo.unlockedAchievementIds, contains('x_season_champion'));
  });

  test('an unqualified player is haunted, not crowned', () async {
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)),
      SavedPlayer(id: 'c', name: 'Cameo', createdAt: DateTime(2026)),
    ]);
    for (var i = 0; i < 12; i++) {
      await GameHistoryService.record(
          game(DateTime(2026, 5, 1 + i), [('a', 1), ('c', 2)]));
    }
    // Cameo plays 3 more with a different opponent to stay under 10? No —
    // Cameo played all 12. Give Cameo only a handful instead.
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026)),
      SavedPlayer(id: 'c', name: 'Cameo', createdAt: DateTime(2026)),
      SavedPlayer(id: 'd', name: 'Dana', createdAt: DateTime(2026)),
    ]);
    for (var i = 0; i < 3; i++) {
      await GameHistoryService.record(
          game(DateTime(2026, 6, 1 + i), [('a', 1), ('d', 2)]));
    }
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));

    await SeasonService.migrate();

    final dana =
        (await PlayerStorage.loadPlayers()).firstWhere((p) => p.id == 'd');
    expect(dana.unlockedAchievementIds, contains('x_season_ghost'),
        reason: '3 games is a season spent haunting');
    expect(dana.unlockedAchievementIds, isNot(contains('x_season_champion')));
  });

  test('awarding is idempotent — a second close hands out nothing new',
      () async {
    await seed();
    await SeasonService.migrate();

    final before = (await PlayerStorage.loadPlayers())
        .firstWhere((p) => p.id == 'a')
        .unlockedAchievementIds
        .length;

    await SeasonService.migrate(); // no-op

    final after = (await PlayerStorage.loadPlayers())
        .firstWhere((p) => p.id == 'a')
        .unlockedAchievementIds
        .length;
    expect(after, before);
  });
}
