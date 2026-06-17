import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_history.dart';

class GameHistoryService {
  static const _key = 'game_history_v1';
  static const _maxEntries = 200;
  static const _maxThrowHistory = 100;

  static Future<List<GameHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return GameHistoryEntry.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  static Future<void> record(GameHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
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
