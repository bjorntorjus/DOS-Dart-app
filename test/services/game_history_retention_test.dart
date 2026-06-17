import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/services/game_history_service.dart';

GameHistoryEntry _entry(int i) => GameHistoryEntry(
      id: '$i', gameMode: 'x01', date: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      players: [GameHistoryPlayer(name: 'A', placement: 1, stats: const {})],
      throwHistory: [DartThrow(playerIndex: 0, segment: 1, multiplier: 1, points: 1,
          scoreBefore: 1, turnNumber: 0, scoreAtStartOfTurn: 1)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only the newest 100 entries keep throwHistory', () async {
    for (var i = 0; i < 105; i++) {
      await GameHistoryService.record(_entry(i));
    }
    final all = await GameHistoryService.load(); // newest first
    expect(all.length, 105);
    expect(all[0].throwHistory, isNotNull);   // newest
    expect(all[99].throwHistory, isNotNull);  // 100th newest
    expect(all[100].throwHistory, isNull);    // beyond cap, trimmed
    expect(all[100].players.first.placement, 1); // rest of entry intact
  });
}
