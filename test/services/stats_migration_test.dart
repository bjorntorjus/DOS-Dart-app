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

    test('Killer games never feed the best-turn recompute', () {
      // Killer throws carry no turnId (defaults 0), so a whole Killer game
      // groups into one giant "turn". Best turn is X01/Splitscore-scoped
      // (decision 2026-07-06) — the Killer game must be ignored entirely.
      final player = SavedPlayer(
        id: 'p1',
        name: 'p1',
        createdAt: DateTime(2026, 1, 1),
        gamesPlayed: 2,
        highestTurnScore: 190,
        modeStats: {'x01': ModeStats(played: 1)},
      );
      final history = [
        GameHistoryEntry(
          id: 'x1',
          gameMode: 'x01',
          date: DateTime(2026, 1, 2),
          players: [GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {})],
          throwHistory: [
            DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
                scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
                turnId: 1, roundNumber: 1),
          ],
        ),
        GameHistoryEntry(
          id: 'k1',
          gameMode: 'killer',
          date: DateTime(2026, 1, 3),
          players: [GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {})],
          throwHistory: [
            // 8 darts, all turnId 0 — sums to 200 if (wrongly) counted.
            for (var d = 0; d < 8; d++)
              DartThrow(playerIndex: 0, segment: 5, multiplier: 5, points: 25,
                  scoreBefore: 3, turnNumber: d % 3, scoreAtStartOfTurn: 3),
          ],
        ),
      ];

      StatsMigration.fixPlayers([player], history);

      expect(player.highestTurnScore, 60); // from the X01 game only
    });

    test('Splitscore turns count toward the best-turn recompute', () {
      final player = SavedPlayer(
        id: 'p1',
        name: 'p1',
        createdAt: DateTime(2026, 1, 1),
        gamesPlayed: 2,
        highestTurnScore: 190,
        modeStats: {'x01': ModeStats(played: 1), 'halveIt': ModeStats(played: 1)},
      );
      final history = [
        GameHistoryEntry(
          id: 'x1',
          gameMode: 'x01',
          date: DateTime(2026, 1, 2),
          players: [GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {})],
          throwHistory: [
            DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
                scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
                turnId: 1, roundNumber: 1),
          ],
        ),
        GameHistoryEntry(
          id: 's1',
          gameMode: 'halveIt',
          date: DateTime(2026, 1, 3),
          players: [GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {})],
          throwHistory: [
            for (var d = 0; d < 3; d++)
              DartThrow(playerIndex: 0, segment: 20, multiplier: d == 0 ? 1 : 2, points: d == 0 ? 20 : 55,
                  scoreBefore: 0, turnNumber: d, scoreAtStartOfTurn: 0,
                  turnId: 7, roundNumber: 3),
          ],
        ),
      ];

      StatsMigration.fixPlayers([player], history);

      expect(player.highestTurnScore, 130); // 20+55+55 from the Splitscore turn
    });

    test('legacy turnId-less X01 game falls back to its clamped snapshot', () {
      // Old history entries predate turnId: every throw decodes as turnId 0,
      // so the whole game would group into one merged "turn". The recompute
      // must detect the impossible >180 total and use the game's stored
      // snapshot (clamped) instead.
      final player = _player(
        'p1',
        ModeStats(played: 1, counters: {
          'highestTurn': 190,
          'totalTurns': 2,
          'totalTurnScore': 190,
          'turnsOver100': 1,
        }),
        highestTurnScore: 190,
        gamesPlayed: 1,
      );
      final history = [
        GameHistoryEntry(
          id: 'legacy',
          gameMode: 'x01',
          date: DateTime(2026, 1, 2),
          players: [
            GameHistoryPlayer(name: 'p1', savedPlayerId: 'p1', placement: 1, stats: const {
              'highestTurn': 190,
              'totalTurns': 2,
              'totalTurnScore': 190,
              'turnsOver100': 1,
            }),
          ],
          throwHistory: [
            // 4 darts, all turnId 0 (legacy), totaling 190.
            for (final p in [60, 60, 60, 10])
              DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: p,
                  scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501),
          ],
        ),
      ];

      final changed = StatsMigration.fixPlayers([player], history);

      expect(changed, isTrue);
      final x01 = player.modeStats['x01']!;
      expect(x01.get('highestTurn'), 180); // clamped snapshot, not 190
      expect(x01.get('totalTurns'), 2); // snapshot sums kept
      expect(x01.get('totalTurnScore'), 190);
      expect(x01.get('turnsOver100'), 1);
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
