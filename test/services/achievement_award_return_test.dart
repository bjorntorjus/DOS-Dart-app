import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('awardGameEnd returns the achievements unlocked, keyed by index', () {
    const a = Achievement(
      id: 'x01_maximum', name: 'MAXIMUM', description: 'Hit a 180',
      tier: AchievementTier.gold, category: AchievementCategory.scoring,
      glyph: AchievementGlyph.icon(null), event: AchievementEvent.score180,
    );
    final svc = AchievementService.forTest([a]);
    final sp = SavedPlayer(id: 'p1', name: 'Jonas', createdAt: DateTime(2026));
    final unlocked = svc.awardGameEnd(
      mode: GameMode.x01,
      playerIds: ['p1'],
      savedPlayers: [sp],
      placements: [1],
      ratingsBefore: const {'p1': 1000},
      ratingsAfter: const {'p1': 1010},
      eventsByIndex: {0: [AchievementEvent.score180]},
    );
    expect(unlocked[0]!.map((a) => a.id), contains('x01_maximum'));
  });
}
