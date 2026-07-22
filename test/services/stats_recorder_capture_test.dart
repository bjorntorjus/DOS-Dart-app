import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recordGame persists throwHistory + earnedFeats + config', () async {
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: [null],            // no saved player → skips rating/stats loops
      playerNames: ['Guest'],
      placements: [1],
      savedPlayers: const [],
      gameConfig: '501 · Dobbel ut',
      durationSeconds: 600,
      throwHistory: [
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      ],
      earnedFeatsByIndex: {
        0: const [EarnedFeat(label: '180!', tier: AchievementTier.gold,
            kind: FeatKind.feat, round: 1)],
      },
    );
    // record() is fire-and-forget; allow the microtask/IO to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final history = await GameHistoryService.load();
    expect(history, isNotEmpty);
    expect(history.first.gameConfig, '501 · Dobbel ut');
    expect(history.first.durationSeconds, 600);
    expect(history.first.throwHistory!.single.points, 60);
    expect(history.first.players.first.earnedFeats!.single.label, '180!');
  });
}
