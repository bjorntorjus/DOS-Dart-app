import 'dart:convert';

class GameHistoryEntry {
  final String id;
  final String gameMode;
  final DateTime date;
  final List<GameHistoryPlayer> players;

  GameHistoryEntry({
    required this.id,
    required this.gameMode,
    required this.date,
    required this.players,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameMode': gameMode,
        'date': date.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GameHistoryEntry(
        id: json['id'] as String,
        gameMode: json['gameMode'] as String,
        date: DateTime.parse(json['date'] as String),
        players: (json['players'] as List)
            .map((p) => GameHistoryPlayer.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  static String encodeList(List<GameHistoryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<GameHistoryEntry> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => GameHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class GameHistoryPlayer {
  final String name;
  final String? savedPlayerId;
  final int placement;
  final Map<String, int> stats;

  GameHistoryPlayer({
    required this.name,
    this.savedPlayerId,
    required this.placement,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (savedPlayerId != null) 'savedPlayerId': savedPlayerId,
        'placement': placement,
        'stats': stats,
      };

  factory GameHistoryPlayer.fromJson(Map<String, dynamic> json) =>
      GameHistoryPlayer(
        name: json['name'] as String,
        savedPlayerId: json['savedPlayerId'] as String?,
        placement: json['placement'] as int,
        stats: (json['stats'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );
}
