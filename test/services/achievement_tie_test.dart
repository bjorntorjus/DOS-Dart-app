import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('tied placements [1,1] do not count as a win for either player', () {
    final svc = AchievementService.forTest(achievementCatalog);
    final a = SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2020))
      ..gamesPlayed = 1;
    final b = SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2020))
      ..gamesPlayed = 1;

    svc.awardGameEnd(
      mode: GameMode.halveIt,
      playerIds: ['a', 'b'],
      savedPlayers: [a, b],
      placements: [1, 1],
      ratingsBefore: {'a': 1000, 'b': 1000},
      ratingsAfter: {'a': 1000, 'b': 1000},
    );

    // NATURAL TALENT = win the very first game -> must NOT unlock on a tie.
    expect(a.unlockedAchievementIds, isNot(contains('x_natural_talent')));
    expect(b.unlockedAchievementIds, isNot(contains('x_natural_talent')));
  });

  test('unique best placement still counts as a win', () {
    final svc = AchievementService.forTest(achievementCatalog);
    final a = SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2020))
      ..gamesPlayed = 1;
    final b = SavedPlayer(id: 'b', name: 'B', createdAt: DateTime(2020))
      ..gamesPlayed = 1;

    svc.awardGameEnd(
      mode: GameMode.halveIt,
      playerIds: ['a', 'b'],
      savedPlayers: [a, b],
      placements: [1, 2],
      ratingsBefore: {'a': 1000, 'b': 1000},
      ratingsAfter: {'a': 1000, 'b': 1000},
    );

    expect(a.unlockedAchievementIds, contains('x_natural_talent'));
    expect(b.unlockedAchievementIds, isNot(contains('x_natural_talent')));
  });
}
