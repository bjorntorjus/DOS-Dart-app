import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('revokeFalseUnlocks strips affected ids exactly once', () {
    final p = SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2020))
      ..unlockedAchievementIds.addAll(
          {'cri_the_nine', 'x01_maximum', 'x01_first_win_unrelated'})
      ..achievementUnlockedAt['cri_the_nine'] = DateTime(2026, 6, 9);

    final changed = AchievementService.instance.revokeFalseUnlocks(p);
    expect(changed, isTrue);
    expect(p.unlockedAchievementIds, isNot(contains('cri_the_nine')));
    expect(p.unlockedAchievementIds, isNot(contains('x01_maximum')));
    expect(p.unlockedAchievementIds, contains('x01_first_win_unrelated'));
    expect(p.achievementUnlockedAt.containsKey('cri_the_nine'), isFalse);
    expect(p.falseUnlocksRevoked, isTrue);

    expect(AchievementService.instance.revokeFalseUnlocks(p), isFalse,
        reason: 'second call is a no-op');
  });

  test('falseUnlocksRevoked round-trips through JSON and defaults to false',
      () {
    final p = SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2020));
    expect(p.falseUnlocksRevoked, isFalse);

    p.falseUnlocksRevoked = true;
    final restored = SavedPlayer.fromJson(p.toJson());
    expect(restored.falseUnlocksRevoked, isTrue);

    final legacy = p.toJson()..remove('falseUnlocksRevoked');
    expect(SavedPlayer.fromJson(legacy).falseUnlocksRevoked, isFalse);
  });
}
