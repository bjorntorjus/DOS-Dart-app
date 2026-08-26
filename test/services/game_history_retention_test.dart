import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/services/game_history_service.dart';

GameHistoryEntry _entry(int i, {String? eventId, bool removed = false}) =>
    GameHistoryEntry(
      id: '$i', gameMode: 'x01', date: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      players: [
        GameHistoryPlayer(
            name: 'A', placement: 1, stats: const {}, removed: removed),
      ],
      gameConfig: '501 · Double-Out',
      durationSeconds: 600,
      throwHistory: [DartThrow(playerIndex: 0, segment: 1, multiplier: 1, points: 1,
          scoreBefore: 1, turnNumber: 0, scoreAtStartOfTurn: 1)],
      eventId: eventId,
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

  test('trimming throwHistory keeps every other field, eventId included',
      () async {
    // Regression: the space-saving rebuild in record() copied 6 of the 8
    // fields, silently unlinking an older game from its event night (and
    // handing it back to the season tables, which skip event games).
    for (var i = 0; i < 105; i++) {
      await GameHistoryService.record(
          _entry(i, eventId: 'night-$i', removed: i.isEven));
    }
    final all = await GameHistoryService.load(); // newest first

    final trimmed = all[100];
    expect(trimmed.throwHistory, isNull, reason: 'sanity: this one is trimmed');
    expect(trimmed.eventId, 'night-4',
        reason: 'the event link must survive the rebuild');
    expect(trimmed.id, '4');
    expect(trimmed.gameMode, 'x01');
    expect(trimmed.gameConfig, '501 · Double-Out');
    expect(trimmed.durationSeconds, 600);
    expect(trimmed.date, DateTime(2026, 1, 1).add(const Duration(minutes: 4)));
    expect(trimmed.players.first.removed, isTrue,
        reason: 'the roster-change flag rides along on players');

    // And the untrimmed newest entry is unaffected.
    expect(all.first.eventId, 'night-104');
    expect(all.first.throwHistory, isNotNull);
  });
}
