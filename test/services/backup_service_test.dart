import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';

void main() {
  // writeBackupFile resolves the documents directory through path_provider,
  // which is a platform channel. Swapping PathProviderPlatform.instance for a
  // fake pointing at a real temp directory is its documented test seam — the
  // same approach sound_service_queue_test.dart uses.
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('backup_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

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

  group('export', () {
    test('writes a file whose contents decode back to the payload', () async {
      BackupService.disableShareForTest = true;
      addTearDown(() => BackupService.disableShareForTest = false);
      await PlayerStorage.savePlayers(
          [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

      final path = await BackupService.writeBackupFile();

      expect(path, endsWith('.json'));
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(decoded['format'], kBackupFormat);
      expect((decoded['players'] as List).first['name'], 'Kari');
    });

    test('exporting stamps the timestamp the migration gate reads', () async {
      BackupService.disableShareForTest = true;
      addTearDown(() => BackupService.disableShareForTest = false);

      expect(await AppSettings.getLastBackupAt(), isNull);
      await BackupService.exportAndShare();
      expect(await AppSettings.getLastBackupAt(), isNotNull);
    });
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}
