import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/saved_player.dart';

void main() {
  bool fires(int slowTurns) {
    final p = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    p.modeStats['x01'] =
        ModeStats(played: 20, counters: {'slowTurns': slowTurns});
    final a = achievementCatalog.firstWhere((a) => a.id == 'x_filibuster');
    return a.milestoneTest!(AchievementContext(player: p));
  }

  test('FILIBUSTER fires at ten slow turns, not nine', () {
    expect(fires(9), isFalse);
    expect(fires(10), isTrue);
  });

  test('it counts across modes, not per mode', () {
    final p = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    p.modeStats['x01'] = ModeStats(played: 9, counters: {'slowTurns': 6});
    p.modeStats['cricket'] = ModeStats(played: 9, counters: {'slowTurns': 5});
    final a = achievementCatalog.firstWhere((a) => a.id == 'x_filibuster');

    expect(a.milestoneTest!(AchievementContext(player: p)), isTrue,
        reason: '6 + 5 crosses the bar even though neither mode does');
  });

  test('its name is unique in the catalogue', () {
    final names = achievementCatalog.map((a) => a.name).toList();
    expect(names.where((n) => n == 'FILIBUSTER').length, 1);
    expect(names.toSet().length, names.length);
  });
}
