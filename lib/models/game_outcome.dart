import 'game_mode.dart';

/// Per-game result handed to milestone evaluation at game-end. Career stats
/// live on SavedPlayer; this carries only this-game data + per-game flags.
class GameOutcome {
  final GameMode mode;
  final bool won;
  final int placement; // 1-based
  final int playerCount;
  final double ratingBefore;
  final double ratingAfter;
  final List<double> opponentRatingsBefore;

  /// Per-game flags/counters computed at record time (e.g. 'bustCount',
  /// 'maxDeficitBehind', 'wireToWire', 'instantShanghai'). Per-mode phases fill this.
  final Map<String, int> gameCounters;

  const GameOutcome({
    required this.mode,
    required this.won,
    required this.placement,
    required this.playerCount,
    required this.ratingBefore,
    required this.ratingAfter,
    this.opponentRatingsBefore = const [],
    this.gameCounters = const {},
  });

  int counter(String key) => gameCounters[key] ?? 0;
}
