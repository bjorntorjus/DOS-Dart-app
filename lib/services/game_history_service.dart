import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_history.dart';

class GameHistoryService {
  static const _key = 'game_history_v1';
  static const _maxEntries = 200;

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
    await prefs.setString(_key, GameHistoryEntry.encodeList(trimmed));
  }
}
