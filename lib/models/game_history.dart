import 'dart:convert';

import 'dart_throw.dart';
import 'earned_feat.dart';

class GameHistoryEntry {
  final String id;
  final String gameMode;
  final DateTime date;
  final List<GameHistoryPlayer> players;
  final String? gameConfig;
  final int? durationSeconds;
  final List<DartThrow>? throwHistory;

  GameHistoryEntry({
    required this.id,
    required this.gameMode,
    required this.date,
    required this.players,
    this.gameConfig,
    this.durationSeconds,
    this.throwHistory,
  });

  /// Max round in the recorded throws, or null when no throw history.
  int? get rounds => throwHistory == null || throwHistory!.isEmpty
      ? null
      : throwHistory!.map((t) => t.roundNumber).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameMode': gameMode,
        'date': date.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
        if (gameConfig != null) 'gameConfig': gameConfig,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (throwHistory != null)
          'throws': throwHistory!.map((t) => t.toJson()).toList(),
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GameHistoryEntry(
        id: json['id'] as String,
        gameMode: json['gameMode'] as String,
        date: DateTime.parse(json['date'] as String),
        players: (json['players'] as List)
            .map((p) => GameHistoryPlayer.fromJson(p as Map<String, dynamic>))
            .toList(),
        gameConfig: json['gameConfig'] as String?,
        durationSeconds: json['durationSeconds'] as int?,
        throwHistory: (json['throws'] as List?)
            ?.map((t) => DartThrow.fromJson(t as Map<String, dynamic>))
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
  final double? ratingBefore;
  final double? ratingAfter;
  final List<EarnedFeat>? earnedFeats;

  GameHistoryPlayer({
    required this.name,
    this.savedPlayerId,
    required this.placement,
    required this.stats,
    this.ratingBefore,
    this.ratingAfter,
    this.earnedFeats,
  });

  double? get ratingDelta => (ratingBefore != null && ratingAfter != null)
      ? ratingAfter! - ratingBefore!
      : null;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (savedPlayerId != null) 'savedPlayerId': savedPlayerId,
        'placement': placement,
        'stats': stats,
        if (ratingBefore != null) 'ratingBefore': ratingBefore,
        if (ratingAfter != null) 'ratingAfter': ratingAfter,
        if (earnedFeats != null)
          'feats': earnedFeats!.map((f) => f.toJson()).toList(),
      };

  factory GameHistoryPlayer.fromJson(Map<String, dynamic> json) =>
      GameHistoryPlayer(
        name: json['name'] as String,
        savedPlayerId: json['savedPlayerId'] as String?,
        placement: json['placement'] as int,
        stats: (json['stats'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
        ratingBefore: (json['ratingBefore'] as num?)?.toDouble(),
        ratingAfter: (json['ratingAfter'] as num?)?.toDouble(),
        earnedFeats: (json['feats'] as List?)
            ?.map((f) => EarnedFeat.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}
