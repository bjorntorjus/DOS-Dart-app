import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import 'game_history_service.dart';
import 'player_storage.dart';

const String kBackupFormat = 'dart-scorer-backup';
const int kBackupVersion = 1;

/// Keys captured as parsed structures elsewhere in the payload. Excluded from
/// `settings` so each fact appears exactly once.
const _capturedKeys = {'saved_players', 'game_history_v1'};

/// Exports everything the app stores as one JSON document.
///
/// Reading only — nothing here mutates storage. The point is a copy that
/// leaves the device: [GameHistoryService] keeps only the newest 200 games and
/// strips throws beyond the newest 100, so data is being discarded on ordinary
/// evenings whether or not a migration ever runs.
class BackupService {
  /// Assembles the payload. Pure data — no files, no share sheet — so the
  /// shape can be tested without a platform channel.
  static Future<Map<String, dynamic>> buildBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();

    // A generic sweep rather than the 23 known AppSettings keys: a backup that
    // needs updating every time a setting is added is a backup that will
    // silently miss one. The *_corrupt salvage keys are deliberately kept —
    // if storage is broken, that is exactly the data worth rescuing.
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_capturedKeys.contains(key)) continue;
      settings[key] = prefs.get(key);
    }

    return {
      'format': kBackupFormat,
      'version': kBackupVersion,
      'app': kAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'players': players.map((p) => p.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'settings': settings,
    };
  }

  /// Pretty-printed so the file is readable by a human deciding whether to
  /// trust it.
  static String encode(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'dart-scorer-backup-'
        '${now.year}-${two(now.month)}-${two(now.day)}.json';
  }
}
