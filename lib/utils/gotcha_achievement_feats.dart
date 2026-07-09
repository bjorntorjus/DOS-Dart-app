import '../models/achievement_event.dart';

/// Derives the four chain-gotcha [AchievementEvent]s from a Gotcha game's
/// event-sourced kill log. Pure — safe to call once at game end and
/// undo-safe, since [killLog] itself only ever holds kills that survived
/// undos.
///
/// Rules (product decision, Bjørn 2026-07-09 — fires in BOTH halving and
/// hardcore mode: "a gotcha is a gotcha" either way):
///  - [AchievementEvent.gotchaDoubleTap]: the same (attacker, victim) pair
///    lands 2+ times in a single round → event for the attacker.
///  - [AchievementEvent.gotchaPinata]: the same victim is hit 2+ times in a
///    single round, by any attacker(s) → event for the victim.
///  - [AchievementEvent.gotchaVendetta]: the same (attacker, victim) pair
///    lands in two consecutive rounds → event for the attacker.
///  - [AchievementEvent.gotchaCrashDummy]: the same victim is hit in two
///    consecutive rounds, by any attacker(s) → event for the victim.
///
/// Each event is listed at most once per player (dedupe — the achievement
/// service one-times unlocks anyway, but the in-game feats list shouldn't
/// spam the same line). Double-tap/pinata and vendetta/crash-dummy can both
/// fire from the very same kills — that's intentional: attacker and victim
/// are rewarded independently, so it is never suppressed.
Map<int, List<AchievementEvent>> gotchaEventsFromKillLog(
    List<({int round, int attacker, int victim})> killLog) {
  final events = <int, Set<AchievementEvent>>{};
  void add(int player, AchievementEvent event) {
    (events[player] ??= <AchievementEvent>{}).add(event);
  }

  // Group kills by round for the same-round patterns (double tap, pinata),
  // and index pairs/victims per round for the consecutive-round patterns
  // (vendetta, crash dummy).
  final killsByRound = <int, List<({int round, int attacker, int victim})>>{};
  final pairsByRound = <int, Set<(int, int)>>{};
  final victimsByRound = <int, Set<int>>{};
  for (final kill in killLog) {
    (killsByRound[kill.round] ??= []).add(kill);
    (pairsByRound[kill.round] ??= {}).add((kill.attacker, kill.victim));
    (victimsByRound[kill.round] ??= {}).add(kill.victim);
  }

  for (final kills in killsByRound.values) {
    final pairCounts = <(int, int), int>{};
    final victimCounts = <int, int>{};
    for (final kill in kills) {
      final pairKey = (kill.attacker, kill.victim);
      pairCounts[pairKey] = (pairCounts[pairKey] ?? 0) + 1;
      victimCounts[kill.victim] = (victimCounts[kill.victim] ?? 0) + 1;
    }
    for (final entry in pairCounts.entries) {
      if (entry.value >= 2) {
        add(entry.key.$1, AchievementEvent.gotchaDoubleTap);
      }
    }
    for (final entry in victimCounts.entries) {
      if (entry.value >= 2) add(entry.key, AchievementEvent.gotchaPinata);
    }
  }

  for (final round in pairsByRound.keys) {
    final nextPairs = pairsByRound[round + 1];
    if (nextPairs == null) continue;
    for (final pair in pairsByRound[round]!) {
      if (nextPairs.contains(pair)) {
        add(pair.$1, AchievementEvent.gotchaVendetta);
      }
    }
  }
  for (final round in victimsByRound.keys) {
    final nextVictims = victimsByRound[round + 1];
    if (nextVictims == null) continue;
    for (final victim in victimsByRound[round]!) {
      if (nextVictims.contains(victim)) {
        add(victim, AchievementEvent.gotchaCrashDummy);
      }
    }
  }

  return events.map((player, set) => MapEntry(player, set.toList()));
}
