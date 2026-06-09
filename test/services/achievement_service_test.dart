import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/game_outcome.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

Achievement _milestone(String id, MilestoneTest t) => Achievement(
      id: id,
      name: id.toUpperCase(),
      description: '',
      tier: AchievementTier.bronze,
      category: AchievementCategory.milestone,
      glyph: const AchievementGlyph.icon(Icons.star),
      milestoneTest: t,
    );

Achievement _event(String id, AchievementEvent e) => Achievement(
      id: id,
      name: id.toUpperCase(),
      description: '',
      tier: AchievementTier.gold,
      category: AchievementCategory.scoring,
      glyph: const AchievementGlyph.icon(Icons.star),
      event: e,
    );

GameOutcome _outcome({bool won = true, Map<String, int> c = const {}}) =>
    GameOutcome(
      mode: GameMode.x01,
      won: won,
      placement: won ? 1 : 2,
      playerCount: 2,
      ratingBefore: 1200,
      ratingAfter: 1210,
      gameCounters: c,
    );

void main() {
  late SavedPlayer player;
  setUp(() => player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020)));

  test('milestone unlocks once and is idempotent', () {
    final svc = AchievementService.forTest([
      _milestone('played1', (ctx) => ctx.player.gamesPlayed >= 1),
    ]);
    player.gamesPlayed = 1;
    expect(svc.evaluateMilestones(player, _outcome()).map((a) => a.id), ['played1']);
    expect(svc.evaluateMilestones(player, _outcome()), isEmpty);
    expect(player.unlockedAchievementIds, contains('played1'));
  });

  test('event unlocks matching event badges and emits on the stream', () async {
    final svc = AchievementService.forTest([_event('max', AchievementEvent.score180)]);
    final emitted = <String>[];
    svc.unlocks.listen((u) => emitted.add(u.achievement.id));
    final newly = svc.checkEvent(AchievementEvent.score180, player);
    expect(newly.map((a) => a.id), ['max']);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, ['max']);
  });

  test('retro grants career badges silently, skips per-game predicates', () async {
    final svc = AchievementService.forTest([
      _milestone('career', (ctx) => ctx.player.gamesWon >= 1),
      _milestone('pergame', (ctx) {
        final o = ctx.outcome;
        if (o == null) return false; // per-game: not retro-grantable
        return o.won;
      }),
    ]);
    player.gamesWon = 1;
    final emitted = <String>[];
    svc.unlocks.listen((u) => emitted.add(u.achievement.id));
    svc.retroGrantSilently(player);
    expect(player.unlockedAchievementIds, contains('career'));
    expect(player.unlockedAchievementIds, isNot(contains('pergame')));
    expect(player.achievementsRetroGranted, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty); // silent — no banner
    svc.retroGrantSilently(player); // no-op guard
  });
}
