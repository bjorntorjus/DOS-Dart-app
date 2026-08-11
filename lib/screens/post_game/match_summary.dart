import '../../models/dart_throw.dart';

/// The six game-level numbers under the post-game standings — about the
/// MATCH, not about a player (design fasit 2026-08-10).
///
/// Every field except [duration] is nullable, and null is the render
/// instruction: the widget dims that cell and shows an em dash. Two different
/// situations produce nulls, and both are normal rather than error states:
///
///  - **Whole zone** — `throwHistory` is suppressed after a mid-game roster
///    change (the chart's lines index by seat and would mislabel), so five of
///    six cells go null and [degraded] is true. Duration survives because it
///    comes from the clock, not the throws.
///  - **One cell** — 1UP and Killer have no progression series yet, so only
///    [biggestLead] is null while everything else renders.
class MatchSummary {
  const MatchSummary({
    required this.duration,
    required this.degraded,
    this.rounds,
    this.darts,
    this.bestTurn,
    this.bestTurnBy,
    this.hitDistribution,
    this.biggestLead,
  });

  final String duration;
  final String? rounds;
  final String? darts;
  final String? bestTurn;

  /// Sub-line under BEST TURN: `NAME · Rn`.
  final String? bestTurnBy;
  final String? hitDistribution;
  final String? biggestLead;

  /// True when the throw history was unavailable, so the zone renders at full
  /// size with five dimmed cells and the section label gains a note.
  final bool degraded;
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final d = Duration(seconds: seconds);
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
  return '${d.inMinutes}:$s';
}

/// Derives the MATCH SUMMARY from what the result screen already holds.
///
/// [seriesFor] returns a player's plotted progression values, or null when the
/// mode has no series — it is the same source the chart draws, so BIGGEST LEAD
/// can never disagree with the picture above it.
MatchSummary matchSummaryFrom({
  required int? durationSeconds,
  List<DartThrow>? throws,
  List<String> playerNames = const [],
  List<num>? Function(int seat)? seriesFor,
}) {
  final duration = _formatDuration(durationSeconds);
  if (throws == null || throws.isEmpty) {
    return MatchSummary(duration: duration, degraded: true);
  }

  final rounds = throws.map((t) => t.roundNumber).toSet().length;

  // Best turn: group by turnId (unique per turn even when the score does not
  // change), sum the points, take the biggest.
  final byTurn = <int, List<DartThrow>>{};
  for (final t in throws) {
    (byTurn[t.turnId] ??= []).add(t);
  }
  int bestSum = 0;
  List<DartThrow>? bestGroup;
  for (final group in byTurn.values) {
    final sum = group.fold<int>(0, (a, t) => a + t.points);
    if (bestGroup == null || sum > bestSum) {
      bestSum = sum;
      bestGroup = group;
    }
  }
  String? bestBy;
  if (bestGroup != null) {
    final seat = bestGroup.first.playerIndex;
    final name = seat < playerNames.length
        ? playerNames[seat].toUpperCase()
        : 'P${seat + 1}';
    bestBy = '$name · R${bestGroup.first.roundNumber + 1}';
  }

  // Bull is checked FIRST: a double bull is a bull, not also a double.
  var triples = 0, doubles = 0, bulls = 0, misses = 0;
  for (final t in throws) {
    if (t.multiplier == 0) {
      misses++;
    } else if (t.segment == 25) {
      bulls++;
    } else if (t.multiplier == 3) {
      triples++;
    } else if (t.multiplier == 2) {
      doubles++;
    }
  }

  String? lead;
  if (seriesFor != null && playerNames.length > 1) {
    final series = <List<num>>[];
    for (var seat = 0; seat < playerNames.length; seat++) {
      final s = seriesFor(seat);
      if (s != null && s.isNotEmpty) series.add(s);
    }
    if (series.length > 1) {
      // Only rounds every seat has reached — a joiner's series is shorter, and
      // reading past its end would report the leader's whole total as a lead.
      final shared = series.map((s) => s.length).reduce((a, b) => a < b ? a : b);
      num widest = 0;
      for (var i = 0; i < shared; i++) {
        final at = [for (final s in series) s[i]];
        final gap = at.reduce((a, b) => a > b ? a : b) -
            at.reduce((a, b) => a < b ? a : b);
        if (gap > widest) widest = gap;
      }
      if (widest > 0) {
        lead = widest is int ? '$widest' : widest.toStringAsFixed(0);
      }
    }
  }

  return MatchSummary(
    duration: duration,
    degraded: false,
    rounds: '$rounds',
    darts: '${throws.length}',
    bestTurn: '$bestSum',
    bestTurnBy: bestBy,
    hitDistribution: 'T $triples · D $doubles · B $bulls · ✗ $misses',
    biggestLead: lead,
  );
}
