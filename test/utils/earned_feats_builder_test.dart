import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/utils/earned_feats_builder.dart';

void main() {
  test('combines in-game events (feat) and unlocks (unlock)', () {
    const a = Achievement(
      id: 'x', name: 'MAXIMUM', description: 'd', tier: AchievementTier.gold,
      category: AchievementCategory.scoring, glyph: AchievementGlyph.icon(null));
    final feats = buildEarnedFeats(
      eventsByIndex: {0: [AchievementEvent.score180]},
      unlocksByIndex: {0: [a]},
    );
    final labels = feats[0]!.map((f) => f.label).toList();
    expect(labels, containsAll(['180!', 'MAXIMUM']));
    expect(feats[0]!.where((f) => f.kind == FeatKind.feat).length, 1);
    expect(feats[0]!.where((f) => f.kind == FeatKind.unlock).length, 1);
  });
}
