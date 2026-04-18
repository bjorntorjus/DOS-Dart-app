import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_player.dart';

class PlayerStorage {
  static const _key = 'saved_players';

  static Future<List<SavedPlayer>> loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
    return jsonList
        .map((j) => SavedPlayer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> savePlayers(List<SavedPlayer> players) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(players.map((p) => p.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  static Future<SavedPlayer> addPlayer(String name) async {
    final players = await loadPlayers();
    final player = SavedPlayer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
    );
    players.add(player);
    await savePlayers(players);
    return player;
  }

  static Future<void> updatePlayer(SavedPlayer updated) async {
    final players = await loadPlayers();
    final index = players.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      players[index] = updated;
      await savePlayers(players);
    }
  }

  static Future<void> deletePlayer(String id) async {
    final players = await loadPlayers();
    players.removeWhere((p) => p.id == id);
    await savePlayers(players);
  }
}
