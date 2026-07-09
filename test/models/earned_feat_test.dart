import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/earned_feat.dart';

void main() {
  test('EarnedFeat round-trips through JSON', () {
    const f = EarnedFeat(
        label: '180!', tier: AchievementTier.gold,
        note: 'Maks i runde 1', kind: FeatKind.feat, round: 1);
    final back = EarnedFeat.fromJson(f.toJson());
    expect(back.label, '180!');
    expect(back.tier, AchievementTier.gold);
    expect(back.note, 'Maks i runde 1');
    expect(back.kind, FeatKind.feat);
    expect(back.round, 1);
  });

  test('feat from in-game event maps to a label + tier', () {
    final f = EarnedFeat.fromEvent(AchievementEvent.score180);
    expect(f.label, '180!');
    expect(f.kind, FeatKind.feat);
  });

  test('Gotcha events map to their labels + tiers', () {
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaDoubleTap).label, 'DOUBLE TAP');
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaDoubleTap).tier, AchievementTier.gold);
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaPinata).label, 'PIÑATA');
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaPinata).tier, AchievementTier.silver);
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaVendetta).label, 'PERSONAL VENDETTA');
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaVendetta).tier, AchievementTier.silver);
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaCrashDummy).label, 'CRASH TEST DUMMY');
    expect(EarnedFeat.fromEvent(AchievementEvent.gotchaCrashDummy).tier, AchievementTier.silver);
  });

  test('feat from unlocked achievement is a star unlock', () {
    const a = Achievement(
      id: 'x01_maximum', name: 'MAXIMUM', description: 'Hit a 180',
      tier: AchievementTier.gold, category: AchievementCategory.scoring,
      glyph: AchievementGlyph.asset('x'),
    );
    final f = EarnedFeat.fromUnlock(a);
    expect(f.label, 'MAXIMUM');
    expect(f.tier, AchievementTier.gold);
    expect(f.kind, FeatKind.unlock);
  });
}
