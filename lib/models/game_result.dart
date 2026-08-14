import 'dart_throw.dart';
import 'game_history.dart';

class PlayerResult {
  final String name;
  final String? avatarPath;
  final int placement;
  final Map<String, dynamic> stats;
  final double? ratingBefore;
  final double? ratingAfter;

  PlayerResult({
    required this.name,
    this.avatarPath,
    required this.placement,
    this.stats = const {},
    this.ratingBefore,
    this.ratingAfter,
  });

  double? get ratingChange =>
      ratingBefore != null && ratingAfter != null
          ? ratingAfter! - ratingBefore!
          : null;
}

class GameResult {
  final String gameMode;
  final List<PlayerResult> results;
  final bool statsSkipped;

  /// Whether the result screen may offer "↶ Back" (undo). False after a
  /// sudden-death tiebreak: rewinding a live tiebreak is meaningless and used
  /// to leave half-rewound state behind (audit 2026-07-06, F4).
  final bool canUndo;

  /// Per-dart history for the optional "SCORE PER ROUND" progression chart
  /// on PostGameScreen (index-aligned with each dart's `playerIndex`). Null
  /// for every mode that doesn't opt in — zero impact elsewhere.
  final List<DartThrow>? throwHistory;

  /// The `progressionForMode` key used to build the chart's [ModeProgression]
  /// from [throwHistory]. Null unless [throwHistory] is also provided.
  final String? progressionMode;

  /// Mode-specific extra data for optional embedded widgets on
  /// [PostGameScreen] (e.g. Golf's `GolfScoreGrid` scorecard section). Null
  /// for every mode that doesn't opt in — zero impact elsewhere.
  final Map<String, dynamic>? modeExtras;

  /// EPHEMERAL [GameHistoryEntry] for the "▶ DETAILS" drill-down
  /// (`GameDetailScreen`) on [PostGameScreen]. Stats recording is deferred
  /// until Finish (post-game Undo safety), so no persisted history entry
  /// exists yet while the post-game screen shows — this is built in memory
  /// by `StatsRecorder.buildEntry` from the same locals the mode's
  /// `_updateStats`/`recordGame` call assembles, just with pre-Finish rating
  /// values (usually null — Elo computes at Finish). Null for every mode
  /// that doesn't opt in, and ignored entirely when [statsSkipped] is true.
  final GameHistoryEntry? detailEntry;

  /// Wall-clock seconds from the screen's `_gameStart` to game end, for the
  /// post-game MATCH SUMMARY's DURATION cell. It cannot be derived from
  /// [throwHistory] — and DURATION is the one summary value that still
  /// renders when throwHistory is suppressed by a roster change.
  final int? durationSeconds;

  GameResult({
    required this.gameMode,
    required this.results,
    this.statsSkipped = false,
    this.canUndo = true,
    this.throwHistory,
    this.progressionMode,
    this.modeExtras,
    this.detailEntry,
    this.durationSeconds,
  });
}
