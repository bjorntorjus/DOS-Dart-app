import '../models/achievement.dart';
import '../models/achievement_event.dart';
import '../models/earned_feat.dart';

/// Merge the ✦ in-game events a cockpit fires with the ★ unlocks awardGameEnd
/// returns into the per-player feat lists shown on KAMPDETALJER.
Map<int, List<EarnedFeat>> buildEarnedFeats({
  required Map<int, List<AchievementEvent>> eventsByIndex,
  required Map<int, List<Achievement>> unlocksByIndex,
}) {
  final out = <int, List<EarnedFeat>>{};
  for (final entry in eventsByIndex.entries) {
    out[entry.key] = entry.value.map((e) => EarnedFeat.fromEvent(e)).toList();
  }
  for (final entry in unlocksByIndex.entries) {
    (out[entry.key] ??= []).addAll(entry.value.map(EarnedFeat.fromUnlock));
  }
  return out;
}
