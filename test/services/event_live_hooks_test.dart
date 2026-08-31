import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/elo_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/services/season_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

/// Sets EventService.active directly — these tests are about what the live
/// game path does WHILE an event is open, not about opening one.
void openEvent() => EventService.active = EventRecord(
      id: 'evt_test',
      name: 'Test night',
      start: DateTime(2026, 8, 25, 19),
      savedRatings: const {},
    );

SavedPlayer sp(String id, {int games = 0}) => SavedPlayer(
    id: id, name: id, createdAt: DateTime(2020), gamesPlayed: games);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
  });
  tearDown(EventService.resetForTest);

  group('EloService K during an event', () {
    test('experienced players move at the new-player K (32, not 16)', () {
      openEvent();
      final a = sp('a', games: 100), b = sp('b', games: 100);
      EloService.updateRatings(
          gameMode: 'x01',
          playerIds: ['a', 'b'],
          placements: [1, 2],
          savedPlayers: [a, b]);
      expect(a.rating, closeTo(1216, 0.001));
      expect(b.rating, closeTo(1184, 0.001));
    });

    test('outside an event the experienced K still applies', () {
      final a = sp('a', games: 100), b = sp('b', games: 100);
      EloService.updateRatings(
          gameMode: 'x01',
          playerIds: ['a', 'b'],
          placements: [1, 2],
          savedPlayers: [a, b]);
      expect(a.rating, closeTo(1208, 0.001));
    });
  });

  group('StatsRecorder during an event', () {
    test('no rating snapshot is appended, entry carries the eventId',
        () async {
      openEvent();
      final a = sp('a'), b = sp('b');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        playerNames: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.ratingHistory, isEmpty);
      expect(a.modeStats['x01']?.played, 1); // stats still recorded
      // GameHistoryService.record is fire-and-forget; let it land.
      await Future<void>.delayed(Duration.zero);
      final history = await GameHistoryService.load();
      expect(history.single.eventId, 'evt_test');
    });

    test('outside an event a snapshot is appended and eventId is null',
        () async {
      final a = sp('a'), b = sp('b');
      StatsRecorder.recordGame(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        playerNames: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.ratingHistory, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect((await GameHistoryService.load()).single.eventId, isNull);
    });
  });

  group('SeasonService.closeDueSeason during an event', () {
    test('a due boundary does not close while an event is open', () async {
      await PlayerStorage.savePlayers([sp('a')..rating = 1300]);
      await AppSettings.setSeasonNumber(2);
      await AppSettings.setSeasonStart(DateTime(2026, 7, 1));
      openEvent();

      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)),
          isFalse);
      expect(await SeasonService.loadSeasons(), isEmpty);
      expect((await PlayerStorage.loadPlayers()).single.rating, 1300);

      EventService.resetForTest();
      expect(await SeasonService.closeDueSeason(now: DateTime(2026, 10, 2)),
          isTrue);
      expect((await SeasonService.loadSeasons()).single.number, 2);
    });
  });
}
