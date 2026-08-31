import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';
import 'package:dart_scoring/services/elo_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

SavedPlayer sp(String id, {double rating = 1200}) =>
    SavedPlayer(id: id, name: id, createdAt: DateTime(2020), rating: rating);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameHistoryPlayer.removed', () {
    test('defaults false, round-trips, absent key decodes false', () {
      final p = GameHistoryPlayer(
          name: 'Bo', savedPlayerId: 'b', placement: 0, stats: const {}, removed: true);
      final back = GameHistoryPlayer.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.removed, isTrue);
      final plain = GameHistoryPlayer(name: 'A', placement: 1, stats: const {});
      expect(plain.toJson().containsKey('removed'), isFalse);
      expect(GameHistoryPlayer.fromJson(plain.toJson()).removed, isFalse);
    });

    test('activePlayers drops removed rows', () {
      final e = GameHistoryEntry(id: '1', gameMode: 'x01', date: DateTime(2026), players: [
        GameHistoryPlayer(name: 'A', placement: 1, stats: const {}),
        GameHistoryPlayer(name: 'B', placement: 0, stats: const {}, removed: true),
      ]);
      expect(e.activePlayers.map((p) => p.name), ['A']);
    });
  });

  group('EloService.updateRatings excludedSeats', () {
    test('excluded seat is untouched and the field scales as if it were absent', () {
      // Removed seat 1 carries placement 0 (Family B) — must not "win".
      final a = sp('a'), b = sp('b'), c = sp('c');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', 'b', 'c'],
        placements: [1, 0, 2],
        savedPlayers: [a, b, c],
        excludedSeats: {1},
      );
      expect(b.rating, 1200);
      // Same as a plain two-player game a beats c: ±16 at K=32.
      expect(a.rating, closeTo(1216, 0.001));
      expect(c.rating, closeTo(1184, 0.001));
    });

    test('fewer than two active saved players → no change', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        gameMode: 'x01', playerIds: ['a', 'b'], placements: [1, 0],
        savedPlayers: [a, b], excludedSeats: {1});
      expect(a.rating, 1200);
      expect(b.rating, 1200);
    });
  });

  group('StatsRecorder.recordGame excludedSeats', () {
    test('removed seat gets no stats, no H2H, no snapshot; others count; entry flags it',
        () async {
      final a = sp('a'), b = sp('b'), c = sp('c');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b', 'c'],
        playerNames: ['a', 'b', 'c'],
        placements: [1, 0, 2],
        savedPlayers: [a, b, c],
        modeCounters: {'b': {'darts': 9}, 'a': {'darts': 12}},
        excludedSeats: {1},
      );
      expect(b.modeStats['x01'], isNull);
      expect(b.headToHead, isEmpty);
      expect(b.ratingHistory, isEmpty);
      expect(b.currentWinStreak, 0);
      expect(b.currentLossStreak, 0);

      expect(a.modeStats['x01']!.played, 1);
      expect(a.modeStats['x01']!.won, 1); // seat 1's 0 did not steal the win
      expect(a.headToHead.keys, ['c']);   // no pair with the removed seat
      expect(c.headToHead.keys, ['a']);
      expect(a.ratingHistory, hasLength(1));

      await Future<void>.delayed(Duration.zero);
      final entry = (await GameHistoryService.load()).single;
      expect(entry.players[1].removed, isTrue);
      expect(entry.players[0].removed, isFalse);
      expect(entry.activePlayers.map((p) => p.name), ['a', 'c']);
    });

    test('buildEntry flags excluded seats', () {
      final e = StatsRecorder.buildEntry(
          gameMode: 'x01', playerIds: ['a', null], playerNames: ['a', 'g'],
          placements: [1, 2], excludedSeats: {0});
      expect(e.players[0].removed, isTrue);
      expect(e.players[1].removed, isFalse);
    });
  });

  group('AchievementService.awardGameEnd excludedSeats', () {
    test('removed seat earns nothing; the active winner is the winner', () {
      final svc = AchievementService.forTest(achievementCatalog);
      final a = sp('a'), b = sp('b');
      final got = svc.awardGameEnd(
        mode: GameMode.x01,
        playerIds: ['a', 'b'],
        savedPlayers: [a, b],
        placements: [1, 0],
        ratingsBefore: const {'a': 1200, 'b': 1200},
        ratingsAfter: const {'a': 1216, 'b': 1200},
        excludedSeats: {1},
      );
      expect(got.containsKey(1), isFalse);
      expect(b.unlockedAchievementIds, isEmpty);
    });
  });
}
