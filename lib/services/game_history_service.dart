import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_history.dart';

class GameHistoryService {
  static const _key = 'game_history_v1';
  static const _corruptKey = 'game_history_v1_corrupt';
  static const _maxEntries = 200;
  static const _maxThrowHistory = 100;

  /// True if the last [load] hit a decode error and preserved the raw data
  /// under [_corruptKey] instead of returning it.
  static bool lastLoadFailed = false;

  static Future<List<GameHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      lastLoadFailed = false;
      return [];
    }
    try {
      final entries = GameHistoryEntry.decodeList(raw);
      lastLoadFailed = false;
      return entries;
    } catch (_) {
      // Preserve the unparseable data instead of silently discarding 200
      // games — a later record() must not overwrite it (audit 2026-07-06,
      // F14). Keep the newest corrupt copy for manual recovery/debugging.
      lastLoadFailed = true;
      await prefs.setString(_corruptKey, raw);
      return [];
    }
  }

  static Future<void> record(GameHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    // If load() failed, `existing` is empty but the unreadable data has been
    // copied to _corruptKey (see load), so writing a fresh store here records
    // the new game without destroying the old data (audit 2026-07-06, F14).
    existing.insert(0, entry); // newest first
    final trimmed = existing.take(_maxEntries).toList();
    // Drop throwHistory beyond the newest _maxThrowHistory to bound storage.
    for (var i = _maxThrowHistory; i < trimmed.length; i++) {
      final e = trimmed[i];
      if (e.throwHistory == null) continue;
      trimmed[i] = GameHistoryEntry(
        id: e.id, gameMode: e.gameMode, date: e.date, players: e.players,
        gameConfig: e.gameConfig, durationSeconds: e.durationSeconds,
        throwHistory: null,
      );
    }
    await prefs.setString(_key, GameHistoryEntry.encodeList(trimmed));
  }
}
