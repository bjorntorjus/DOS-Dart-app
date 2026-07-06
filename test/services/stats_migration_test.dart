import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/stats_migration.dart';

SavedPlayer _player(String id, ModeStats x01,
        {int highestTurnScore = 0, required int gamesPlayed}) =>
    SavedPlayer(
      id: id,
      name: id,
      createdAt: DateTime(2026, 1, 1),
      gamesPlayed: gamesPlayed,
      highestTurnScore: highestTurnScore,
      modeStats: {'x01': x01},
    );

// The reported "190": turn 1 busts (T20 reverts to 50), turn 2 restarts from
// 50 and scores 130. Grouping by scoreAtStartOfTurn merged these to 190.
List<DartThrow> _bustMergeThrows() => [
      DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
          scoreBefore: 50, turnNumber: 0, scoreAtStartOfTurn: 50,
          turnId: 1, roundNumber: 1, isBust: true),
      DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
          scoreBefore: 50, turnNumber: 0, scoreAtStartOfTurn: 50,
          turnId: 2, roundNumber: 2),
      DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
          scoreBefore: 50, turnNumber: 1, scoreAtStartOfTurn: 50,
          turnId: 2, roundNumber: 2),
      DartThrow(playerIndex: 0, segment: 10, multiplier: 1, points: 10,
          scoreBefore: 50, turnNumber: 2, scoreAtStartOfTurn: 50,
          turnId: 2, roundNumber: 2),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatsMigration.runIfNeeded', () {
    test('clamps persisted stats once, then no-ops on the second run', () async {
      final player = _player(
        'p1',
        ModeStats(played: 50, counters: {'highestTurn': 190}),
        highestTurnScore: 190,
        gamesPlayed: 50,
      );
      SharedPreferences.setMockInitialValues({});
      await PlayerStorage.savePlayers([player]);

      await StatsMigration.runIfNeeded();
      var reloaded = await PlayerStorage.loadPlayers();
      expect(reloaded.single.modeStats['x01']!.get('highestTurn'), 180);
      expect(reloaded.single.highestTurnScore, 180);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StatsMigration.flagKey), isTrue);

      // Second run must not touch already-migrated data.
      await StatsMigration.runIfNeeded();
      reloaded = await PlayerStorage.loadPlayers();
      expect(reloaded.single.modeStats['x01']!.get('highestTurn'), 180);
    });
  });

  group('StatsMigration.fixPlayers', () {
    test('recomputes x01 turn stats from throwHistory when fully covered', () {
      final player = _player(
        'p1',
        ModeStats(played: 1, won: 1, counters: {
          'highestTurn': 190, // bogus merged value
          'totalTurns': 1, // merge undercounted
          'totalTurnScore': 190,
          'turnsOver100': 1,
        }),
        highestTurnScore: 190,
        gamesPlayed: 1,
      );
      final history = [
        GameHistoryEntry(
          id: 'g1',
          gameMode: 'x01',
          date: DateTime(2026, 1, 2),
          players: [GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {})],
          throwHistory: _bustMergeThrows(),
        ),
      ];

      final changed = StatsMigration.fixPlayers([player], history);

      expect(changed, isTrue);
      final x01 = player.modeStats['x01']!;
      expect(x01.get('highestTurn'), 130); // busted turn excluded, no merge
      expect(x01.get('totalTurns'), 1);
      expect(x01.get('totalTurnScore'), 130);
      expect(x01.get('turnsOver100'), 1);
      expect(player.highestTurnScore, 130);
    });

    test('clamps impossible highestTurn to 180 when history is incomplete', () {
      final player = _player(
        'p1',
        ModeStats(played: 50, won: 10, counters: {
          'highestTurn': 190,
          'totalTurns': 400,
          'totalTurnScore': 24000,
        }),
        highestTurnScore: 190,
        gamesPlayed: 50,
      );

      final changed = StatsMigration.fixPlayers([player], const []);

      expect(changed, isTrue);
      final x01 = player.modeStats['x01']!;
      expect(x01.get('highestTurn'), 180); // clamped, not recomputed
      expect(x01.get('totalTurns'), 400); // sums left untouched (no coverage)
      expect(x01.get('totalTurnScore'), 24000);
      expect(player.highestTurnScore, 180);
    });

    test('leaves already-valid stats unchanged', () {
      final player = _player(
        'p1',
        ModeStats(played: 50, counters: {'highestTurn': 140}),
        highestTurnScore: 140,
        gamesPlayed: 50,
      );

      final changed = StatsMigration.fixPlayers([player], const []);

      expect(changed, isFalse);
      expect(player.modeStats['x01']!.get('highestTurn'), 140);
      expect(player.highestTurnScore, 140);
    });
  });
}
