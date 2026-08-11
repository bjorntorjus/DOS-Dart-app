import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import 'app_settings.dart';
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

  /// The share sheet is a platform channel with no binding in a unit test —
  /// same reason SoundService and VideoService carry a disableForTest.
  @visibleForTesting
  static bool disableShareForTest = false;

  /// Writes the backup into the app's documents directory and returns its
  /// path. A second export on the same day overwrites the first rather than
  /// accumulating copies.
  static Future<String> writeBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${fileName(DateTime.now())}');
    await file.writeAsString(encode(await buildBackup()));
    return file.path;
  }

  /// Writes the file, hands it to the system share sheet, then records that an
  /// export happened.
  ///
  /// The stamp lands AFTER the share returns. SharePlus cannot report whether
  /// the user actually saved anything, so this records "an export was
  /// performed" — the honest claim, and the strongest one available. The
  /// migration gate inherits that limitation, which is why it is friction
  /// rather than a guarantee.
  static Future<void> exportAndShare() async {
    final path = await writeBackupFile();
    if (!disableShareForTest) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        subject: 'Dart Scorer - data backup',
      ));
    }
    await AppSettings.setLastBackupAt(DateTime.now());
  }
}
