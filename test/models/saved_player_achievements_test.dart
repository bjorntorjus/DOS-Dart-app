import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';

void main() {
  test('achievement fields round-trip through JSON', () {
    final p = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add('x01_maximum')
      ..achievementUnlockedAt['x01_maximum'] = DateTime(2026, 6, 9)
      ..achievementsRetroGranted = true
      ..currentWinStreak = 3
      ..bestWinStreak = 7
      ..currentLossStreak = 0;
    final back = SavedPlayer.fromJson(p.toJson());
    expect(back.unlockedAchievementIds, contains('x01_maximum'));
    expect(back.achievementUnlockedAt['x01_maximum'], DateTime(2026, 6, 9));
    expect(back.achievementsRetroGranted, isTrue);
    expect(back.currentWinStreak, 3);
    expect(back.bestWinStreak, 7);
  });

  test('defaults are empty/zero for a fresh player', () {
    final p = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020));
    expect(p.unlockedAchievementIds, isEmpty);
    expect(p.achievementsRetroGranted, isFalse);
    expect(p.currentWinStreak, 0);
  });
}
