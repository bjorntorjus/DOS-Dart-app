import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

/// Post-game v2 Task 5: `StatsRecorder.buildEntry` was extracted from
/// `recordGame`'s entry-assembly so screens can build an EPHEMERAL
/// `GameHistoryEntry` (never persisted) for the "▶ DETAILS" drill-down before
/// stats are recorded at Finish. This locks in that `recordGame` still calls
/// `buildEntry` internally — same inputs must produce the same entry fields,
/// whether built directly via `buildEntry` or persisted via `recordGame`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<DartThrow> throwHistory() => [
        DartThrow(
          playerIndex: 0,
          segment: 20,
          multiplier: 3,
          points: 60,
          scoreBefore: 501,
          turnNumber: 0,
          scoreAtStartOfTurn: 501,
          turnId: 1,
          roundNumber: 1,
        ),
      ];

  Map<int, List<EarnedFeat>> feats() => {
        0: const [
          EarnedFeat(
              label: '180!',
              tier: AchievementTier.gold,
              kind: FeatKind.feat,
              round: 1),
        ],
      };

  test(
      'buildEntry and recordGame produce identical entry fields for the '
      'same inputs (extraction is a no-op for recordGame callers)', () async {
    final built = StatsRecorder.buildEntry(
      gameMode: 'x01',
      playerIds: const ['p1', 'p2'],
      playerNames: const ['Alice', 'Bob'],
      placements: const [1, 2],
      modeCounters: {
        'p1': {'darts': 9},
        'p2': {'darts': 12},
      },
      ratingsBefore: {'p1': 1000, 'p2': 1010},
      ratingsAfter: {'p1': 1012, 'p2': 998},
      gameConfig: '501 · Double-Out',
      durationSeconds: 600,
      throwHistory: throwHistory(),
      earnedFeatsByIndex: feats(),
    );

    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const ['p1', 'p2'],
      playerNames: const ['Alice', 'Bob'],
      placements: const [1, 2],
      // No saved players match these ids — the per-mode-stat/H2H/rating
      // history mutation loop is skipped (idx < 0), leaving only the entry
      // assembly under test (this mirrors stats_recorder_capture_test.dart's
      // `playerIds: [null]` seam, just with non-null ids so the entry
      // captures savedPlayerId + ratings too).
      savedPlayers: const [],
      modeCounters: {
        'p1': {'darts': 9},
        'p2': {'darts': 12},
      },
      ratingsBefore: {'p1': 1000, 'p2': 1010},
      ratingsAfter: {'p1': 1012, 'p2': 998},
      gameConfig: '501 · Double-Out',
      durationSeconds: 600,
      throwHistory: throwHistory(),
      earnedFeatsByIndex: feats(),
    );
    // record() is fire-and-forget; allow the microtask/IO to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final persisted = (await GameHistoryService.load()).single;

    expect(persisted.gameMode, built.gameMode);
    expect(persisted.gameConfig, built.gameConfig);
    expect(persisted.durationSeconds, built.durationSeconds);
    expect(persisted.throwHistory!.length, built.throwHistory!.length);
    expect(persisted.throwHistory!.single.points,
        built.throwHistory!.single.points);
    expect(persisted.players.length, built.players.length);
    for (var i = 0; i < persisted.players.length; i++) {
      final p = persisted.players[i];
      final b = built.players[i];
      expect(p.name, b.name);
      expect(p.savedPlayerId, b.savedPlayerId);
      expect(p.placement, b.placement);
      expect(p.stats, b.stats);
      expect(p.ratingBefore, b.ratingBefore);
      expect(p.ratingAfter, b.ratingAfter);
      expect(p.earnedFeats?.map((f) => f.label).toList(),
          b.earnedFeats?.map((f) => f.label).toList());
    }
  });

  test('buildEntry is pure — it never persists to GameHistoryService',
      () async {
    StatsRecorder.buildEntry(
      gameMode: 'x01',
      playerIds: const ['p1'],
      playerNames: const ['Alice'],
      placements: const [1],
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final history = await GameHistoryService.load();
    expect(history, isEmpty);
  });

  test('buildEntry omits ratings when neither before/after is supplied',
      () {
    final entry = StatsRecorder.buildEntry(
      gameMode: 'wildcard',
      playerIds: const ['p1'],
      playerNames: const ['Alice'],
      placements: const [1],
    );
    expect(entry.players.single.ratingBefore, isNull);
    expect(entry.players.single.ratingAfter, isNull);
  });
}
