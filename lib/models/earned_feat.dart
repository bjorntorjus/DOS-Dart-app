import 'achievement.dart';
import 'achievement_event.dart';

enum FeatKind { unlock, feat } // unlock = newly-earned achievement (★), feat = in-game moment (✦)

class EarnedFeat {
  final String label;
  final AchievementTier tier;
  final String? note;
  final FeatKind kind;
  final int? round;

  const EarnedFeat({
    required this.label,
    required this.tier,
    this.note,
    required this.kind,
    this.round,
  });

  /// ✦ in-game feat from the event a cockpit already fires at game-end.
  factory EarnedFeat.fromEvent(AchievementEvent e, {int? round}) {
    final (label, tier) = _eventLabel(e);
    return EarnedFeat(label: label, tier: tier, kind: FeatKind.feat, round: round);
  }

  /// ★ unlock from a newly-earned achievement.
  factory EarnedFeat.fromUnlock(Achievement a) => EarnedFeat(
        label: a.name,
        tier: a.tier,
        note: a.description,
        kind: FeatKind.unlock,
      );

  static (String, AchievementTier) _eventLabel(AchievementEvent e) {
    switch (e) {
      case AchievementEvent.score180:
        return ('180!', AchievementTier.gold);
      case AchievementEvent.bigCheckout:
        return ('100+ CHECKOUT', AchievementTier.silver);
      case AchievementEvent.bullFinish:
        return ('BULL FINISH', AchievementTier.silver);
      case AchievementEvent.threeTreblesTurn:
        return ('3× TRIPLE', AchievementTier.silver);
      case AchievementEvent.threeBullsTurn:
        return ('3× BULL', AchievementTier.gold);
      case AchievementEvent.nineMarkTurn:
        return ('9 MARKS', AchievementTier.gold);
      case AchievementEvent.instantShanghai:
        return ('INSTANT SHANGHAI', AchievementTier.gold);
      case AchievementEvent.becameKiller:
        return ('BECAME KILLER', AchievementTier.bronze);
      case AchievementEvent.multiKill:
        return ('MULTI-KILL', AchievementTier.silver);
      case AchievementEvent.clutchSave:
        return ('CLUTCH SAVE', AchievementTier.silver);
      case AchievementEvent.gotchaDoubleTap:
        return ('Double tap', AchievementTier.gold);
      case AchievementEvent.gotchaPinata:
        return ('Piñata', AchievementTier.silver);
      case AchievementEvent.gotchaVendetta:
        return ('Personal vendetta', AchievementTier.silver);
      case AchievementEvent.gotchaCrashDummy:
        return ('Crash test dummy', AchievementTier.silver);
      case AchievementEvent.nice69:
        return ('NICE (69)', AchievementTier.bronze);
      case AchievementEvent.sixSeven:
        return ('6-7', AchievementTier.bronze);
      case AchievementEvent.threeMisses:
        return ('3 MISSES', AchievementTier.bronze);
    }
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'tier': tier.name,
        if (note != null) 'note': note,
        'kind': kind.name,
        if (round != null) 'round': round,
      };

  factory EarnedFeat.fromJson(Map<String, dynamic> j) => EarnedFeat(
        label: j['label'] as String,
        tier: AchievementTier.values.byName(j['tier'] as String),
        note: j['note'] as String?,
        kind: FeatKind.values.byName(j['kind'] as String),
        round: j['round'] as int?,
      );
}
