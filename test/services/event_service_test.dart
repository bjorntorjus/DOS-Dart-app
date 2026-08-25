import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';

GameHistoryEntry game(DateTime date, List<(String, int)> ps,
        {String? eventId}) =>
    GameHistoryEntry(
      id: '${date.microsecondsSinceEpoch}$eventId',
      gameMode: 'x01',
      date: date,
      players: [
        for (final (id, pl) in ps)
          GameHistoryPlayer(
              name: id, savedPlayerId: id, placement: pl, stats: const {})
      ],
      eventId: eventId,
    );

Future<void> seed() async {
  await PlayerStorage.savePlayers([
    SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1310),
    SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1090)
      ..archived = true,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    AchievementService.instance.registerCatalog(achievementCatalog);
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('event_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test(
      'start snapshots every rating (archived too), resets to 1200, writes a backup',
      () async {
    await seed();
    final e = await EventService.start('Jobbfest 2026',
        now: DateTime(2026, 8, 25, 19));

    expect(e.isOpen, isTrue);
    expect(e.name, 'Jobbfest 2026');
    expect(e.savedRatings, {'a': 1310, 'b': 1090});
    expect(EventService.active?.id, e.id);

    final players = await PlayerStorage.loadPlayers();
    expect(players.every((p) => p.rating == 1200), isTrue);
    expect(tempDir.listSync().whereType<File>(), isNotEmpty);
    expect((await EventService.loadEvents()).single.isOpen, isTrue);
  });

  test('load() at boot rehydrates the open event', () async {
    await seed();
    await EventService.start('Jobbfest 2026');
    EventService.resetForTest();
    expect(EventService.active, isNull);
    await EventService.load();
    expect(EventService.active?.name, 'Jobbfest 2026');
  });

  test('start refuses while one is open; end refuses without one', () async {
    await seed();
    await expectLater(EventService.end(), throwsA(isA<StateError>()));
    await EventService.start('Jobbfest 2026');
    await expectLater(
        EventService.start('Another'), throwsA(isA<StateError>()));
  });

  test('start rejects a blank name', () async {
    await seed();
    await expectLater(
        EventService.start('   '), throwsA(isA<ArgumentError>()));
    expect(EventService.active, isNull);
  });

  test(
      'end builds the table from event games only, awards badges and restores season ratings',
      () async {
    await seed();
    await GameHistoryService.record(
        game(DateTime(2026, 8, 20), [('a', 1), ('b', 2)]));
    final e = await EventService.start('Jobbfest 2026',
        now: DateTime(2026, 8, 25, 19));

    // Simulate the evening: Bo wins twice, ratings moved by the game screens.
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: e.id));
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 21), [('b', 1), ('a', 2)], eventId: e.id));
    final mid = await PlayerStorage.loadPlayers();
    mid.singleWhere((p) => p.id == 'b').rating = 1260;
    mid.singleWhere((p) => p.id == 'a').rating = 1140;
    // A player created mid-event: no snapshot entry.
    mid.add(SavedPlayer(
        id: 'c', name: 'Cy', createdAt: DateTime(2026), rating: 1180));
    await PlayerStorage.savePlayers(mid);

    final closed = await EventService.end(now: DateTime(2026, 8, 25, 23, 30));

    expect(closed.isOpen, isFalse);
    expect(closed.end, DateTime(2026, 8, 25, 23, 30));
    expect(closed.winnerName, 'Bo');
    final bo = closed.rows.singleWhere((r) => r.playerId == 'b');
    expect(bo.games, 2);
    expect(bo.wins, 2);
    expect(bo.rating, 1260);
    // The 20 Aug season game is not in the event table.
    expect(closed.rows.singleWhere((r) => r.playerId == 'a').games, 2);

    final players = await PlayerStorage.loadPlayers();
    final after = {for (final p in players) p.id: p.rating};
    expect(after, {'a': 1310, 'b': 1090, 'c': 1200});
    expect(EventService.active, isNull);
    final stored = await EventService.loadEvents();
    expect(stored.single.isOpen, isFalse);
    expect(stored.single.id, e.id);

    // Badges: Bo won (below 1200 in the season → crasher too), Ada second.
    final ids = {for (final p in players) p.id: p.unlockedAchievementIds};
    expect(ids['b'],
        containsAll(['x_event_champion', 'x_event_plus_one', 'x_event_crasher']));
    expect(ids['a'], containsAll(['x_event_runner_up', 'x_event_plus_one']));
    expect(ids['a'], isNot(contains('x_event_champion')));
    expect(ids['c'], isEmpty);
  });

  test('livePreview ranks the open event from history so far', () async {
    await seed();
    final e = await EventService.start('Jobbfest 2026',
        now: DateTime(2026, 8, 25, 19));
    await GameHistoryService.record(
        game(DateTime(2026, 8, 25, 20), [('b', 1), ('a', 2)], eventId: e.id));
    final players = await PlayerStorage.loadPlayers();
    players.singleWhere((p) => p.id == 'b').rating = 1232;
    await PlayerStorage.savePlayers(players);

    final live = await EventService.livePreview(now: DateTime(2026, 8, 25, 21));
    expect(live, isNotNull);
    expect(live!.isOpen, isTrue);
    expect(live.ranked.first.playerId, 'b');
    expect(live.ranked.first.rating, 1232);
    expect(live.ranked.length, 2);
  });

  test('livePreview is null when no event is open', () async {
    expect(await EventService.livePreview(), isNull);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
