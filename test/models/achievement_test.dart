import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';

void main() {
  test('glyph holds an icon or an asset, not both', () {
    const g = AchievementGlyph.icon(Icons.star);
    expect(g.isAsset, isFalse);
    expect(g.icon, Icons.star);
    const a = AchievementGlyph.asset('assets/badges/x.png');
    expect(a.isAsset, isTrue);
    expect(a.assetPath, 'assets/badges/x.png');
  });

  test('milestone achievement carries a predicate, event is null', () {
    final ach = Achievement(
      id: 'test_volume',
      name: 'REGULAR',
      description: 'Play 25 games',
      tier: AchievementTier.silver,
      category: AchievementCategory.milestone,
      glyph: const AchievementGlyph.icon(Icons.videogame_asset),
      milestoneTest: (ctx) => ctx.player.gamesPlayed >= 25,
    );
    expect(ach.event, isNull);
    expect(ach.milestoneTest, isNotNull);
    expect(ach.mode, isNull); // cross-cutting
  });
}
