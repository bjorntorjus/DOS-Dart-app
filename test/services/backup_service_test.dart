import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an empty install still produces a well-formed backup', () async {
    final b = await BackupService.buildBackup();

    expect(b['format'], kBackupFormat);
    expect(b['version'], kBackupVersion);
    expect(b['players'], isEmpty);
    expect(b['history'], isEmpty);
    expect(b['exportedAt'], isA<String>());
    expect(b['app'], isA<String>());
  });

  test('players and history are stored parsed, not as embedded strings',
      () async {
    await PlayerStorage.savePlayers([
      SavedPlayer(
          id: 'p1', name: 'Kari', createdAt: DateTime(2026), rating: 1310),
    ]);
    await GameHistoryService.record(GameHistoryEntry(
      id: 'g1',
      gameMode: 'x01',
      date: DateTime(2026, 7, 4),
      players: [
        GameHistoryPlayer(
            name: 'Kari', savedPlayerId: 'p1', placement: 1, stats: const {}),
      ],
    ));

    final b = await BackupService.buildBackup();

    expect(b['players'], isA<List>());
    expect((b['players'] as List).first['name'], 'Kari');
    expect((b['players'] as List).first['rating'], 1310);
    expect(b['history'], isA<List>());
    expect((b['history'] as List).first['gameMode'], 'x01');
  });

  test('settings capture every other key, including ones nobody enumerated',
      () async {
    SharedPreferences.setMockInitialValues({
      'meme_enabled': true,
      'meme_frequency': 7,
      'elo_k_new': 32.0,
      'tts_voice': 'en-GB',
      'a_setting_added_next_year': 'still here',
    });

    final b = await BackupService.buildBackup();
    final settings = b['settings'] as Map<String, dynamic>;

    expect(settings['meme_enabled'], true);
    expect(settings['meme_frequency'], 7);
    expect(settings['elo_k_new'], 32.0);
    expect(settings['tts_voice'], 'en-GB');
    expect(settings['a_setting_added_next_year'], 'still here',
        reason: 'a generic sweep must not need updating per new setting');
  });

  test('settings do not duplicate the players and history blobs', () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

    final b = await BackupService.buildBackup();
    final settings = b['settings'] as Map<String, dynamic>;

    expect(settings.containsKey('saved_players'), isFalse);
    expect(settings.containsKey('game_history_v1'), isFalse);
  });

  test('corrupt-salvage keys ARE kept — broken data is worth rescuing',
      () async {
    SharedPreferences.setMockInitialValues({
      'saved_players_corrupt': '{"broken":',
      'game_history_v1_corrupt': '[not json',
    });

    final settings =
        (await BackupService.buildBackup())['settings'] as Map<String, dynamic>;

    expect(settings['saved_players_corrupt'], '{"broken":');
    expect(settings['game_history_v1_corrupt'], '[not json');
  });

  test('the payload encodes to valid JSON and decodes back unchanged',
      () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

    final b = await BackupService.buildBackup();
    final round = jsonDecode(BackupService.encode(b)) as Map<String, dynamic>;

    expect(round['format'], kBackupFormat);
    expect((round['players'] as List).first['id'], 'p1');
  });

  test('the file name carries the date', () {
    expect(BackupService.fileName(DateTime(2026, 8, 11)),
        'dart-scorer-backup-2026-08-11.json');
    expect(BackupService.fileName(DateTime(2026, 12, 5)),
        'dart-scorer-backup-2026-12-05.json');
  });
}
