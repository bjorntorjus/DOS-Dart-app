import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/models/game_history.dart';

void main() {
  test('entry with new fields round-trips', () {
    final entry = GameHistoryEntry(
      id: '1', gameMode: 'x01', date: DateTime(2026, 6, 16),
      gameConfig: '501 · Dobbel ut', durationSeconds: 1080,
      throwHistory: [
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      ],
      players: [
        GameHistoryPlayer(
          name: 'Jonas', placement: 1, stats: {'totalDarts': 15},
          earnedFeats: const [EarnedFeat(
              label: '180!', tier: AchievementTier.gold,
              kind: FeatKind.feat, round: 1)],
        ),
      ],
    );
    final back = GameHistoryEntry.fromJson(entry.toJson());
    expect(back.gameConfig, '501 · Dobbel ut');
    expect(back.durationSeconds, 1080);
    expect(back.throwHistory!.length, 1);
    expect(back.throwHistory!.first.points, 60);
    expect(back.players.first.earnedFeats!.first.label, '180!');
  });

  test('old entry JSON without new fields still decodes (nulls)', () {
    final old = {
      'id': '9', 'gameMode': 'cricket', 'date': '2026-01-01T00:00:00.000',
      'players': [
        {'name': 'A', 'placement': 1, 'stats': {'points': 40}},
      ],
    };
    final back = GameHistoryEntry.fromJson(old);
    expect(back.throwHistory, isNull);
    expect(back.gameConfig, isNull);
    expect(back.durationSeconds, isNull);
    expect(back.players.first.earnedFeats, isNull);
  });
}
